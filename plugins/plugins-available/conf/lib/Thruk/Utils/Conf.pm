package Thruk::Utils::Conf;

use strict;
use warnings;
use POSIX qw(tzset);
use Carp;
use File::Slurp;
use Digest::MD5 qw(md5_hex);
use Storable qw/store retrieve/;
use Data::Dumper;
use Scalar::Util qw/weaken/;

=head1 NAME

Thruk::Utils::Conf.pm - Helper Functios for the Config Tool

=head1 DESCRIPTION

Helper Functios for the Config Tool

=head1 METHODS

=cut

######################################

=head2 set_object_model

put objects model into stash

=cut
sub set_object_model {
    my ( $c, $no_recursion ) = @_;

    my $cached_data = $c->cache->get->{'global'} || {};
    Thruk::Action::AddDefaults::set_processinfo($c, undef, 2, $cached_data, 1);
    $c->stash->{has_obj_conf} = scalar keys %{get_backends_with_obj_config($c)};

    # if this is no obj config yet, try updating process info which updates
    # configuration information from http backends
    if(!$c->stash->{has_obj_conf}) {
        Thruk::Action::AddDefaults::set_processinfo($c, undef, undef, undef, 1);
        $c->stash->{has_obj_conf} = scalar keys %{get_backends_with_obj_config($c)};
    }

    return unless $c->stash->{has_obj_conf};

    my $refresh = $c->{'request'}->{'parameters'}->{'refreshdata'} || 0;

    $c->stats->profile(begin => "_update_objects_config()");
    my $model                    = $c->model('Objects');
    my $peer_conftool            = $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'});
    Thruk::Utils::Conf::get_default_peer_config($peer_conftool->{'configtool'});
    $c->stash->{'peer_conftool'} = $peer_conftool->{'configtool'};

    # already parsed?
    my $jobid = $model->currently_parsing($c->stash->{'param_backend'});
    if(    Thruk::Utils::Conf::get_model_retention($c)
       and Thruk::Utils::Conf::init_cached_config($c, $peer_conftool->{'configtool'}, $model)
    ) {
        # objects initialized
    }
    # currently parsing
    elsif($jobid && Thruk::Utils::External::is_running($c, $jobid, 1)) {
        $c->response->redirect("job.cgi?job=".$jobid);
        return 0;
    }
    else {
        # need to parse complete objects
        if(scalar keys %{$c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'configtool'}} > 0) {
            Thruk::Utils::External::perl($c, { expr    => 'Thruk::Utils::Conf::read_objects($c)',
                                               message => 'please stand by while reading the configuration files...',
                                               forward => $c->request->uri()
                                              }
                                        );
            $model->currently_parsing($c->stash->{'param_backend'}, $c->stash->{'job_id'});
            $c->stash->{'obj_model_changed'} = 0 unless $c->{'request'}->{'parameters'}->{'refreshdata'};
            if($c->config->{'no_external_job_forks'} == 1 and !$no_recursion) {
                # should be parsed now
                return set_object_model($c, 1);
            }
            return;
        }
        return 0;
    }

    $c->{'obj_db'}->{'stats'}      = $c->{'stats'};
    if(lc($peer_conftool->{'type'}) eq 'http') {
        $c->{'obj_db'}->{'remotepeer'} = $peer_conftool;
        weaken($c->{'obj_db'}->{'remotepeer'}); # avoid circular refs
    }
    $c->{'obj_db'}->remote_file_sync($c);

    if($c->{'obj_db'}->{'cached'}) {
        $c->stats->profile(begin => "checking objects");
        $c->{'obj_db'}->check_files_changed($refresh);
        $c->stats->profile(end => "checking objects");
    }

    my $errnum = scalar @{$c->{'obj_db'}->{'errors'}};
    if($errnum > 0) {
        my $error = $c->{'obj_db'}->{'errors'}->[0];
        if($errnum > 1) {
            $error = 'Got multiple errors!';
        }
        if($c->{'obj_db'}->{'needs_update'}) {
            $error = 'Config has been changed externally. Need to <a href="'.Thruk::Utils::Filter::uri_with($c, { 'refreshdata' => 1 }).'">refresh</a> objects.';
        }
        Thruk::Utils::set_message( $c,
                                  'fail_message',
                                  $error,
                                  ($errnum == 1 && !$c->{'obj_db'}->{'needs_update'}) ? undef : $c->{'obj_db'}->{'errors'},
                                );
    } elsif($refresh) {
        Thruk::Utils::set_message( $c, 'success_message', 'refresh successful');
    }

    $c->stats->profile(end => "_update_objects_config()");
    return 1;
}

######################################

=head2 read_objects

read objects and store them as storable

=cut
sub read_objects {
    my $c             = shift;
    $c->stats->profile(begin => "read_objects()");
    my $model         = $c->model('Objects');
    my $peer_conftool = $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'});
    my $obj_db        = $model->init($c->stash->{'param_backend'}, $peer_conftool->{'configtool'}, undef, $c->{'stats'}, $peer_conftool);
    store_model_retention($c);
    $c->stash->{model_type} = 'Objects';
    $c->stash->{model_init} = [ $c->stash->{'param_backend'}, $peer_conftool->{'configtool'}, $obj_db, $c->{'stats'} ];
    $c->stats->profile(end => "read_objects()");
    return;
}


######################################

=head2 update_conf

    update_conf($file, $data [, $md5] [, $defaults] [, $update_c]);

update inline config

    $file       file to change
    $data       new data
    $md5        md5 sum from the file when we read it. (use -1 to disable check)
    $defaults   defaults for this file
    $update_c   update c so thruk does not need to be restarted

=cut
sub update_conf {
    my($file, $data, $md5, $defaults, $update_c) = @_;

    my($old_content, $old_data, $old_md5) = read_conf($file, $defaults);
    if($md5 ne '-1' and $md5 ne $old_md5) {
        return("cannot update, file has been changed since reading it.");
    }

    # remove unchanged values
    for my $key (keys %{$data}) {
        if(   $old_data->{$key}->[0] eq 'STRING'
           or $old_data->{$key}->[0] eq 'INT'
           or $old_data->{$key}->[0] eq 'BOOL'
           or $old_data->{$key}->[0] eq 'LIST'
           ) {
            if($old_data->{$key}->[1] eq $data->{$key}) {
                delete $data->{$key}
            }
        }
        elsif(   $old_data->{$key}->[0] eq 'ARRAY'
              or $old_data->{$key}->[0] eq 'MULTI_LIST') {
            if(join(',',@{$old_data->{$key}->[1]}) eq join(',',@{$data->{$key}})) {
                delete $data->{$key}
            }
        } else {
            confess("unknown type: ".$old_data->{$key}->[0]);
        }
    }

    # update thruks config directly, so we don't need to restart
    if($update_c) {
        for my $key (keys %{$data}) {
            $update_c->config->{$key} = $data->{$key};
            if($key eq 'use_timezone') {
                if($data->{$key} ne '') {
                    $ENV{'TZ'} = $data->{$key}
                } else {
                    delete $ENV{'TZ'};
                }
                POSIX::tzset();
            }
        }
    }

    my $new_content = merge_conf($old_content, $data);

    if($new_content eq $old_content) {
        return("no changes made.");
    }

    open(my $fh, ">", $file) or return("cannot update, failed to write to $file: $!");
    print $fh $new_content;
    Thruk::Utils::IO::close($fh, $file);

    return;
}


######################################

=head2 read_conf

read config file

=cut

sub read_conf {
    my $file = shift;
    my $data = shift;

    my $arrays_defined = {};

    return('', $data, '') unless -e $file;

    my $content  = read_file($file);
    my $md5      = md5_hex($content);
    for my $line (split/\n/mx, $content) {
        next if $line eq '';
        next if substr($line, 0, 1) eq '#';
        if($line =~ m/\s*(\w+)\s*=\s*(.*)\s*(\#.*|)$/mx) {
            my $key   = $1;
            my $value = $2;
            if(defined $data->{$key}) {
                if(   $data->{$key}->[0] eq 'ARRAY'
                   or $data->{$key}->[0] eq 'MULTI_LIST') {
                    $data->{$key}->[1] = [] unless defined $arrays_defined->{$key};
                    $arrays_defined->{$key} = 1;
                    push @{$data->{$key}->[1]}, split(/\s*,\s*/mx,$value);
                } else {
                    $value             =~ s/^"(.*)"$/$1/gmx;
                    $data->{$key}->[1] = $value;
                }
            }
        }
    }

    # sort and uniq options
    for my $key (keys %{$data}) {
        if($data->{$key}->[0] eq 'MULTI_LIST') {
            my %seen = ();
            my @uniq = sort( grep { !$seen{$_}++ } @{$data->{$key}->[1]} );
            $data->{$key}->[1] = [ sort @uniq ];
        }
    }

    return($content, $data, $md5);
}


######################################

=head2 merge_conf

merge config file with data

=cut

sub merge_conf {
    my $text = shift;
    my $data = shift;

    my $keys_placed = {};
    my $new = "";
    for my $line (split/(\n)/mx, $text, -1) {
        if(    $line eq ''
            or $line eq "\n"
            or substr($line, 0, 1) eq '#'
           ) {
            $new .= $line;
        }
        elsif($line =~ m/\s*(\w+)\s*=\s*(.*)\s*(\#.*|)$/mx) {
            my $key   = $1;
            my $value = $2;
            $value    =~ s/^"(.*)"$/$1/gmx;
            if(defined $keys_placed->{$key}) {
                chomp($new);
                next;
            }
            if(defined $data->{$key}) {
                if(   ref($data->{$key}) eq 'ARRAY'
                   or ref($data->{$key}) eq 'MULTI_LIST') {
                    $value = join(',', @{$data->{$key}});
                } else {
                    $value = $data->{$key};
                }
                $new .= $key."=".$value;
                delete $data->{$key};
                $keys_placed->{$key} = 1;
            } else {
                $new .= $line;
            }
        }
        else {
            $new .= $line;
        }
    }

    # no append all keys which doesn't have been changed already
    for my $key (keys %{$data}) {
        my $value;
        if(   ref($data->{$key}) eq 'ARRAY'
           or ref($data->{$key}) eq 'MULTI_LIST') {
            $value = join(',', @{$data->{$key}});
        } else {
            $value = $data->{$key};
        }
        $new .= $key."=".$value."\n";
    }

    return($new);
}


######################################

=head2 get_component_as_string

return component config as string

=cut

sub get_component_as_string {
    my($backends) = @_;
    my $string = "<Component Thruk::Backend>\n";
    for my $b (@{$backends}) {
        $string .= "    <peer>\n";
        $string .= "        name    = ".$b->{'name'}."\n";
        $string .= "        id      = ".$b->{'id'}."\n"      if $b->{'id'};
        $string .= "        type    = ".$b->{'type'}."\n";
        $string .= "        hidden  = ".$b->{'hidden'}."\n"  if $b->{'hidden'};
        $string .= "        groups  = ".$b->{'groups'}."\n"  if $b->{'groups'};
        $string .= "        section = ".$b->{'section'}."\n" if $b->{'section'};
        $string .= "        <options>\n" if(defined $b->{'options'} and scalar keys %{$b->{'options'}} > 0);
        $string .= "            peer          = ".$b->{'options'}->{'peer'}."\n"          if $b->{'options'}->{'peer'};
        $string .= "            resource_file = ".$b->{'options'}->{'resource_file'}."\n" if $b->{'options'}->{'resource_file'};
        $string .= "            auth          = ".$b->{'options'}->{'auth'}."\n"          if $b->{'options'}->{'auth'};
        $string .= "            proxy         = ".$b->{'options'}->{'proxy'}."\n"         if $b->{'options'}->{'proxy'};
        $string .= "            remote_name   = ".$b->{'options'}->{'remote_name'}."\n"   if $b->{'options'}->{'remote_name'};
        $string .= "        </options>\n" if(defined $b->{'options'} and scalar keys %{$b->{'options'}} > 0);
        if(defined $b->{'configtool'} and scalar keys %{$b->{'configtool'}} > 0 and $b->{'type'} ne 'http') {
            $string .= "        <configtool>\n";
            $string .= "            core_type      = ".$b->{'configtool'}->{'core_type'}."\n"      if $b->{'configtool'}->{'core_type'};
            $string .= "            core_conf      = ".$b->{'configtool'}->{'core_conf'}."\n"      if $b->{'configtool'}->{'core_conf'};
            $string .= "            obj_check_cmd  = ".$b->{'configtool'}->{'obj_check_cmd'}."\n"  if $b->{'configtool'}->{'obj_check_cmd'};
            $string .= "            obj_reload_cmd = ".$b->{'configtool'}->{'obj_reload_cmd'}."\n" if $b->{'configtool'}->{'obj_reload_cmd'};
            if(defined $b->{'configtool'}->{'obj_readonly'}) {
                for my $readonly (ref $b->{'configtool'}->{'obj_readonly'} eq 'ARRAY' ? @{$b->{'configtool'}->{'obj_readonly'}} : ($b->{'configtool'}->{'obj_readonly'})) {
                    $string .= "            obj_readonly   = ".$readonly."\n";
                }
            }
            $string .= "        </configtool>\n";
        }
        $string .= "    </peer>\n";
    }
    $string .= "</Component>\n";
    return $string;
}


######################################

=head2 replace_block

replace block in config file

=cut

sub replace_block {
    my($file, $string, $start, $end) = @_;

    my $content = "";
    if(-f $file) {
        $content = read_file($file);
    }

    ## no critic
    unless($content =~ s/$start.*?$end/$string/sxi) {
        $content .= "\n\n".$string;
    }
    ## use critic

    open(my $fh, ">", $file) or return("cannot update, failed to write to $file: $!");
    print $fh $content;
    Thruk::Utils::IO::close($fh, $file);

    return 1;
}


##########################################################

=head2 get_data_from_param

get data hash from post parameter

=cut

sub get_data_from_param {
    my $param    = shift;
    my $defaults = shift;
    my $data     = {};

    for my $key (keys %{$param}) {
        next unless $key =~ m/^data\./mx;
        my $value = $param->{$key};
        $key =~ s/^data\.//mx;
        next unless defined $defaults->{$key};
        if(   $defaults->{$key}->[0] eq 'ARRAY'
           or $defaults->{$key}->[0] eq 'MULTI_LIST') {
            if(ref $value eq 'ARRAY') {
                $data->{$key} = $value;
            } else {
                $data->{$key} = [ split(/\s*,\s*/mx, $value) ];
            }
        } else {
            $data->{$key} = $value;
        }
    }
    return $data;
}


##########################################################

=head2 get_cgi_user_list

get list of cgi users from cgi.cfg, htpasswd and contacts table

=cut

sub get_cgi_user_list {
    my ( $c ) = @_;

    # get users from core contacts
    my $contacts = $c->{'db'}->get_contacts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contact' ) ],
                                             remove_duplicates => 1);
    my $all_contacts = {};
    for my $contact (@{$contacts}) {
        $all_contacts->{$contact->{'name'}} = $contact->{'name'}." - ".$contact->{'alias'};
    }

    # add users from htpasswd
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}) {
        my $htpasswd = read_htpasswd($c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'});
        for my $user (keys %{$htpasswd}) {
            $all_contacts->{$user} = $user unless defined $all_contacts->{$user};
        }
    }

    # add users from cgi.cfg
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'}) {
        my $file                  = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
        my $defaults              = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my $extra_user = [];
        for my $key (keys %{$data}) {
            next unless $key =~ m/^authorized_for_/mx;
            push @{$extra_user}, @{$data->{$key}->[1]};
        }
        for my $user (@{$extra_user}) {
            $all_contacts->{$user} = $user unless defined $all_contacts->{$user};
        }
    }

    # add special users
    $all_contacts->{'*'} = '*';

    return $all_contacts;
}


##########################################################

=head2 get_cgi_group_list

get list of cgi groups from cgi.cfg and contactgroups table

=cut

sub get_cgi_group_list {
    my ( $c ) = @_;

    # get users from core contacts
    my $groups = $c->{'db'}->get_contactgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contactgroups' ) ],
                                                remove_duplicates => 1);
    my $all_groups = {};
    for my $group (@{$groups}) {
        $all_groups->{$group->{'name'}} = $group->{'name'}." - ".$group->{'alias'};
    }

    # add users from cgi.cfg
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'}) {
        my $file                  = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
        my $defaults              = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
        my($content, $data, $md5) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my $extra_group = [];
        for my $key (keys %{$data}) {
            next unless $key =~ m/^authorized_contactgroup_for_/mx;
            push @{$extra_group}, @{$data->{$key}->[1]};
        }
        for my $group (@{$extra_group}) {
            $all_groups->{$group} = $group unless defined $all_groups->{$group};
        }
    }

    # add special users
    $all_groups->{'*'} = '*';

    return $all_groups;
}


##########################################################

=head2 read_htpasswd

read htpasswd file

=cut
sub read_htpasswd {
    my ( $file ) = @_;
    my $htpasswd = {};
    return $htpasswd unless -f $file;
    my $content  = read_file($file);
    for my $line (split/\n/mx, $content) {
        my($user,$hash) = split/:/mx, $line;
        next unless defined $hash;
        $htpasswd->{$user} = $hash;
    }
    return($htpasswd);
}

##########################################################

=head2 store_model_retention

store object model in storable

=cut
sub store_model_retention {
    my($c) = @_;
    $c->stats->profile(begin => "store_model_retention()");

    my $model = $c->model('Objects');
    my $file  = $c->config->{'tmp_path'}."/obj_retention.dat";

    # try to save retention data
    eval {
        # delete some useless references
        for my $conf (values %{$model->{'configs'}}) {
            delete $conf->{'stats'};
            delete $conf->{'remotepeer'};
        }
        my $data = {
            'configs'      => $model->{'configs'},
            'release_date' => $c->config->{'released'},
            'version'      => $c->config->{'version'},
        };
        store($data, $file);
        $c->config->{'conf_retention'} = [stat($file)];
        $c->stash->{'obj_model_changed'} = 0;
        $c->log->debug('saved object retention data');
    };
    if($@) {
        $c->log->error($@);
        $c->stats->profile(end => "store_model_retention()");
        return;
    }

    $c->stats->profile(end => "store_model_retention()");
    return 1;
}

##########################################################

=head2 get_model_retention

restore object model from storable

=cut
sub get_model_retention {
    my($c) = @_;
    $c->stats->profile(begin => "get_model_retention()");

    my $model = $c->model('Objects');
    my $file  = $c->config->{'tmp_path'}."/obj_retention.dat";

    if(! -f $file) {
        return 1 if $model->cache_exists($c->stash->{'param_backend'});
        return;
    }

    # don't read retention file when current data is newer
    my @stat = stat($file);
    if( $model->cache_exists($c->stash->{'param_backend'}) and
        defined $c->config->{'conf_retention'}
        and $stat[9] <= $c->config->{'conf_retention'}->[9]
    ) {
       return 1;
    }
    $c->config->{'conf_retention'} = \@stat;

    # try to retrieve retention data
    eval {
        my $data = retrieve($file);
        if(defined $data->{'release_date'}
           and $data->{'release_date'} eq $c->config->{'released'}
           and defined $data->{'version'}
           and $data->{'version'} eq $c->config->{'version'}
        ) {
            my $model_configs = $data->{'configs'};
            for my $backend (keys %{$model_configs}) {
                if(defined $c->stash->{'backend_detail'}->{$backend}) {
                    $model->init($backend, undef, $model_configs->{$backend}, $c->stats);
                    $c->log->debug('restored object retention data for '.$backend);
                }
            }
        } else {
            # old or unknown file
            $c->log->debug('removed old retention file: version '.Dumper($data->{'version'}).' - date '.Dumper($data->{'release_date'}));
            unlink($file);
        }
    };
    if($@) {
        unlink($file);
        $c->log->error($@);
        return;
    }

    $c->log->debug('model retention file '.$file.' loaded.');

    $c->stats->profile(end => "get_model_retention()");
    return 1;
}

##########################################################

=head2 get_root_folder

return root folder for given files

ex.: get_root_folder(['/etc/nagios/conf.d/test.cfg',
                      '/etc/nagios/conf.d/test/blah.cfg'
                     ])

returns '/etc/nagios/conf.d'

=cut
sub get_root_folder {
    my($files) = @_;
    my $splited = {};
    for my $file (@{$files}) {
        $file =~ s|/[^/]+$||gmx;
        my @paths = split(/\//mx, $file);
        $splited->{$file} = \@paths;
    }
    my $root = "";
    return $root if scalar @{$files} == 0;
    my $x = 0;
    while($x < 100) {
        my $cur   = undef;
        my $equal = 1;
        for my $paths (values %{$splited}) {
            if(!defined $paths->[$x]) {
                $equal = 0;
                last;
            }
            elsif(!defined $cur) {
                $cur = $paths->[$x];
            }
            elsif($cur ne $paths->[$x]) {
                $equal = 0;
                last;
            }
        }
        if($equal) {
            $root .= $cur.'/';
        } else {
            last;
        }
        $x++;
    }
    $root =~ s/\/$//mx;
    return $root;
}

##########################################################

=head2 init_cached_config

set current obj_db from cached config

=cut
sub init_cached_config {
    my($c, $peer_conftool, $model) = @_;

    $c->stats->profile(begin => "init_cached_config()");

    $c->{'obj_db'} = $model->init($c->stash->{'param_backend'}, $peer_conftool, undef, $c->{'stats'});
    $c->{'obj_db'}->{'cached'} = 1;

    unless(_compare_configs($peer_conftool, $c->{'obj_db'}->{'config'})) {
        $c->log->debug("config object base files have changed, reloading complete obj db");
        $c->{'obj_db'}->{'initialized'} = 0;
        undef $c->{'obj_db'};
        $c->stash->{'obj_model_changed'} = 0;
        $c->stats->profile(end => "init_cached_config()");
        return 0;
    }

    $c->log->debug("cached config object loaded");
    $c->stats->profile(end => "init_cached_config()");
    return 1;
}

##########################################################

=head2 get_default_peer_config

return empty / default peer objects config

=cut
sub get_default_peer_config {
    my($config) = @_;
    $config = {} unless defined $config;
    $config->{'obj_check_cmd'}  = undef unless defined $config->{'obj_check_cmd'};
    $config->{'obj_reload_cmd'} = undef unless defined $config->{'obj_reload_cmd'};
    $config->{'core_conf'}      = undef unless defined $config->{'core_conf'};
    $config->{'obj_dir'}        = [] unless defined $config->{'obj_dir'};
    $config->{'obj_file'}       = [] unless defined $config->{'obj_file'};
    return $config;
}

##########################################################
sub _compare_configs {
    my($c1, $c2) = @_;

    for my $key (qw/core_conf core_type/) {
        return 0 if !defined $c1->{$key} and  defined $c2->{$key};
        return 0 if  defined $c1->{$key} and !defined $c2->{$key};
        next if !defined $c1->{$key} and !defined $c2->{$key};
        return 0 if $c1->{$key} ne $c2->{$key};
    }

    return 1;
}

##########################################################
sub _link_obj {
    my($obj,$line) = @_;
    my($path, $link);
    if(defined $line) {
        $path = $obj;
        $link = 'file='.$path.'&amp;line='.$line;
    } else {
        $line = $obj->{'line'};
        $path = $obj->{'file'}->{'path'};
        my $id = $obj->get_id();
        if($id eq 'new') {
            $link = 'file='.$path.'&amp;line='.$line;
        } else {
            $link = 'data.id='.$obj->get_id();
        }
    }
    my $shortpath = $path;
    $shortpath =~ s/.*\///gmx;
    if($line == 0) {
        $line = '';
    } else {
        $line = ':'.$line
    }
    return('<a href="conf.cgi?sub=objects&amp;'.$link.'">'.$shortpath.$line.'</a>');
}

##########################################################

=head2 get_backends_with_obj_config

    get_backends_with_obj_config($c);

returns all backends which do have a objects configuration

=cut
sub get_backends_with_obj_config {
    my($c)       = @_;
    my $backends = {};
    my $firstpeer;
    $c->stash->{'param_backend'} = '';

    my @peers = @{$c->{'db'}->get_peers(1)};
    my @fetch;
    for my $peer (@peers) {
        if($peer->{'addr'} && $peer->{'addr'} =~ /^http/mxi && (!defined $peer->{'configtool'} || scalar keys %{$peer->{'configtool'}} == 0)) {
            $peer->{'configtool'} = { remote => 1 };
            push @fetch, $peer->{'key'};
        }
    }
    if(scalar @fetch > 0) {
        # make sure we have uptodate information about config section of http backends
        local $ENV{'THRUK_USE_SHADOW'} = 0;
        eval {
            $c->{'db'}->get_processinfo(backend => \@fetch);
        };
        for my $key (@fetch) {
            if($c->stash->{'failed_backends'}->{$key}) {
                my $peer = $c->{'db'}->get_peer_by_key($key);
                delete $peer->{'configtool'}->{remote};
            }
        }
    }

    # first hide all of them
    for my $peer (@peers) {
        my $min_key_size = 0;
        if(defined $peer->{'configtool'}->{remote} and $peer->{'configtool'}->{remote} == 1) { $min_key_size = 1; }
        if(scalar keys %{$peer->{'configtool'}} > $min_key_size) {
            $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = 6;
        } else {
            $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = 5
        }
    }

    # first non hidden peer with object config enabled
    for my $peer (@peers) {
        next if defined $peer->{'hidden'} and $peer->{'hidden'} == 1;
        if(scalar keys %{$peer->{'configtool'}} > 0) {
            $firstpeer = $peer->{'key'} unless defined $firstpeer;
            $backends->{$peer->{'key'}} = $peer->{'configtool'}
        }
    }

    # first peer with object config enabled
    if(!defined $firstpeer) {
        for my $peer (@peers) {
            if(scalar keys %{$peer->{'configtool'}} > 0) {
                $firstpeer = $peer->{'key'} unless defined $firstpeer;
                $backends->{$peer->{'key'}} = $peer->{'configtool'}
            }
        }
    }

    # from cookie setting?
    if(defined $c->request->cookie('thruk_conf')) {
        for my $val (@{$c->request->cookie('thruk_conf')->{'value'}}) {
            next unless defined $c->stash->{'backend_detail'}->{$val};
            $c->stash->{'param_backend'} = $val;
        }
    }

    # from url parameter
    if(defined $c->{'request'}->{'parameters'}->{'backend'}) {
        my $val = $c->{'request'}->{'parameters'}->{'backend'};
        if(defined $c->stash->{'backend_detail'}->{$val}) {
            $c->stash->{'param_backend'} = $val;
            # save value in the cookie, so later pages will show the same selected backend
            $c->res->cookies->{'thruk_conf'} = {
                value => $val,
                path  => $c->stash->{'cookie_path'},
            };
        }
    }

    if($c->stash->{'param_backend'} eq '' and defined $firstpeer) {
        $c->stash->{'param_backend'} = $firstpeer;
    }
    if($c->stash->{'param_backend'} and defined $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}) {
        $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}->{'disabled'} = 7;
    }
    $c->stash->{'backend_chooser'} = 'switch';
    return $backends;
}

##########################################################

=head2 clean_from_tool_ignores

    clean_from_tool_ignores($list, $ignores);

returns list with all ignores removed

=cut
sub clean_from_tool_ignores {
    my($list, $ignores) = @_;
    return $list unless $ignores;
    my $cleaned = [];
    for my $r (@{$list}) {
        if(!defined $ignores->{$r->{'ident'}}) {
            push @{$cleaned}, $r;
        }
    }
    return($cleaned);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
