package Thruk::Utils::Conf;

use warnings;
use strict;
use Carp qw/confess/;
use Data::Dumper qw/Dumper/;
use Scalar::Util qw/weaken/;
use Storable qw/store retrieve/;
use Time::HiRes qw(stat);

use Thruk::Action::AddDefaults ();
use Thruk::Constants qw/:peer_states/;
use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils::Auth ();
use Thruk::Utils::Conf::Defaults ();
use Thruk::Utils::Crypt ();
use Thruk::Utils::External ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Utils::Conf.pm - Helper Functios for the Config Tool

=head1 DESCRIPTION

Helper Functios for the Config Tool

=head1 METHODS

=cut

######################################

=head2 set_object_model

put objects model into stash

returns 1 on success, 0 if you have to wait and it redirects or -1 on errors

=cut
sub set_object_model {
    my($c, $no_recursion, $peer_key) = @_;
    $c->stash->{'param_backend'} = $peer_key if $peer_key;
    $peer_key = $c->stash->{'param_backend'} if $c->stash->{'param_backend'};
    delete $c->stash->{set_object_model_err};
    my $cached_data = $c->cache->get->{'global'} || {};
    Thruk::Action::AddDefaults::set_processinfo($c, 2) unless $c->stash->{'processinfo_time'}; # Thruk::Constants::ADD_CACHED_DEFAULTS
    $c->stash->{has_obj_conf} = scalar keys %{set_backends_with_obj_config($c, $peer_key)};

    # if this is no obj config yet, try updating process info which updates
    # configuration information from http backends
    if(!$c->stash->{has_obj_conf} || (defined $peer_key && $peer_key ne $c->stash->{'param_backend'})) {
        $c->stash->{'param_backend'} = $peer_key;
        Thruk::Action::AddDefaults::set_processinfo($c, Thruk::Constants::ADD_CACHED_DEFAULTS);
        $c->stash->{has_obj_conf} = scalar keys %{set_backends_with_obj_config($c, $peer_key)};
    }

    if(!$c->stash->{has_obj_conf}) {
        delete $c->{'obj_db'};
        $c->stash->{set_object_model_err} = "backend has no configtool section";
        return -1;
    }

    if(defined $peer_key && $peer_key ne $c->stash->{'param_backend'}) {
        delete $c->{'obj_db'};
        $c->stash->{set_object_model_err} = "backend has no configtool section";
        return -1;
    }

    my $refresh = $c->req->parameters->{'refreshdata'} || 0;
    delete $c->req->parameters->{'refreshdata'};

    $c->stats->profile(begin => "_update_objects_config()");
    my $peer_conftool = $c->db->get_peer_by_key($c->stash->{'param_backend'});
    get_default_peer_config($peer_conftool->{'configtool'});
    append_global_peer_config($c, $peer_conftool->{'configtool'});
    $c->stash->{'peer_conftool'} = $peer_conftool->{'configtool'};

    if($peer_conftool->{'configtool'}->{'disable'}) {
        delete $c->{'obj_db'};
        $c->stash->{set_object_model_err} = "configtool is disabled for this backend";
        return -1;
    }

    # already parsed?
    my $model = $c->app->obj_db_model;
    my $jobid = $model->currently_parsing($c->stash->{'param_backend'});
    if(    Thruk::Utils::Conf::get_model_retention($c, $c->stash->{'param_backend'})
       and Thruk::Utils::Conf::init_cached_config($c, $peer_conftool->{'configtool'}, $model, $peer_conftool)
    ) {
        # objects initialized
    }
    # currently parsing
    elsif($jobid && Thruk::Utils::External::is_running($c, $jobid, 1)) {
        $c->stash->{"model_job"} = $jobid;
        $c->stash->{set_object_model_err} = "configuration is being parsed right now, try again in a few moments";
        $c->redirect_to("job.cgi?job=".$jobid);
        return 0;
    }
    else {
        # need to parse complete objects
        $c->stash->{set_object_model_err} = "configuration is being parsed right now, try again in a few moments";
        if(scalar keys %{$c->db->get_peer_by_key($c->stash->{'param_backend'})->{'configtool'}} > 0) {
            Thruk::Utils::External::perl($c, { expr    => 'Thruk::Utils::Conf::read_objects($c)',
                                               message => 'please stand by while reading the configuration files...',
                                               forward => $c->req->url,
                                              });
            $model->currently_parsing($c->stash->{'param_backend'}, $c->stash->{'job_id'});
            if($c->config->{'no_external_job_forks'} && !$no_recursion) {
                # should be parsed now
                return set_object_model($c, 1);
            }
            $c->stash->{"model_job"} = $c->stash->{'job_id'};
            return 0;
        }
        return 0;
    }

    $c->{'obj_db'}->{'stats'} = $c->{'stats'};
    if(lc($peer_conftool->{'type'}) eq 'http') {
        $c->{'obj_db'}->{'remotepeer'} = $peer_conftool;
        weaken($c->{'obj_db'}->{'remotepeer'}); # avoid circular refs
    }
    $c->{'obj_db'}->remote_file_sync($c);

    if($c->{'obj_db'}->{'cached'}) {
        $c->stats->profile(begin => "check_files_changed($refresh)");
        $c->{'obj_db'}->check_files_changed($refresh);
        $c->stats->profile(end => "check_files_changed($refresh)");
    }

    $c->{'obj_db'}->{'errors'} = Thruk::Base::array_uniq(Thruk::Base::list($c->{'obj_db'}->{'errors'}));
    my $errnum = scalar @{$c->{'obj_db'}->{'errors'}};
    if($errnum > 0) {
        my $error = $c->{'obj_db'}->{'errors'}->[0];
        if($errnum > 1) {
            $error = 'Got multiple errors!';
        }
        if($c->{'obj_db'}->{'needs_update'}) {
            $error = 'Config has been changed externally. Need to <a class="link textCard" href="'.Thruk::Utils::Filter::uri_with($c, { 'refreshdata' => 1 }).'">refresh</a> objects.';
        }
        Thruk::Utils::set_message($c, {
                                  style   => 'fail_message',
                                  msg     => $error,
                                  details => ($errnum == 1 && !$c->{'obj_db'}->{'needs_update'}) ? undef : join("\n", @{$c->{'obj_db'}->{'errors'}}),
                                  escape  => 0,
        });
    } elsif($refresh) {
        Thruk::Utils::set_message( $c, 'success_message', 'refresh successful');
    }
    if($c->{'obj_db'}->{'obj_model_changed'}) {
        $c->stash->{'obj_model_changed'} = 1;
        delete $c->{'obj_db'}->{'obj_model_changed'};
    }

    $c->stats->profile(end => "_update_objects_config()");
    return 1;
}

######################################

=head2 read_objects

read objects and store them as storable

=cut
sub read_objects {
    my($c) = @_;
    $c->stats->profile(begin => "read_objects()");
    my $model         = $c->app->obj_db_model;
    confess('no model') unless $model;
    my $peer_conftool = $c->db->get_peer_by_key($c->stash->{'param_backend'});
    confess('no config tool') unless $peer_conftool;
    my $obj_db        = $model->init($c->stash->{'param_backend'}, $peer_conftool->{'configtool'}, undef, $c->{'stats'}, $peer_conftool);
    confess('no object database') unless $obj_db;
    store_model_retention($c, $c->stash->{'param_backend'});
    $c->stash->{model_type} = 'Objects';
    $c->stash->{model_init} = [ $c->stash->{'param_backend'}, $peer_conftool->{'configtool'}, $obj_db, $c->{'stats'} ];
    $c->stats->profile(end => "read_objects()");
    return;
}


######################################

=head2 update_conf

    update_conf($file, $data [, $hexdigest] [, $defaults] [, $update_c]);

update inline config

    $file       file to change
    $data       new data
    $hexdigest  hexdigest sum from the file when we read it. (use -1 to disable check)
    $defaults   defaults for this file
    $update_c   update c so thruk does not need to be restarted

=cut
sub update_conf {
    my($file, $data, $hexdigest, $defaults, $update_c) = @_;

    my($old_content, $old_data, $old_hexdigest) = read_conf($file, $defaults);
    if($hexdigest ne '-1' and $hexdigest ne $old_hexdigest) {
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
                delete $data->{$key};
            }
        }
        elsif(   $old_data->{$key}->[0] eq 'ARRAY'
              or $old_data->{$key}->[0] eq 'MULTI_LIST') {
            if(join(',',@{$old_data->{$key}->[1]}) eq join(',',@{$data->{$key}})) {
                delete $data->{$key};
            }
        } else {
            confess("unknown type: ".$old_data->{$key}->[0]);
        }
    }

    # update thruks config directly, so we don't need to restart
    if($update_c) {
        for my $key (keys %{$data}) {
            $update_c->config->{$key} = $data->{$key};
            if($key eq 'server_timezone') {
                Thruk::Utils::Timezone::set_timezone($update_c->config, $data->{$key});
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
    my($file, $data) = @_;

    my $arrays_defined = {};

    return('', $data, '') unless -e $file;

    my $content   = Thruk::Utils::IO::read($file);
    my $hexdigest = Thruk::Utils::Crypt::hexdigest($content);
    my $in_block = 0;
    for my $line (split/\n/mx, $content) {
        next if $line eq '';
        next if substr($line, 0, 1) eq '#';
        if($line =~ m/\s*<\//mx) {
            $in_block--;
            next;
        }
        if($line =~ m/\s*</mx) {
            $in_block++;
            next;
        }

        next if $in_block;

        my($key, $value);
        if($line =~ m/\s*(\w+)\s*=\s*"([^"]*)"\s*(\#.*|)$/mx) {
            $key   = $1;
            $value = $2;
        }
        elsif($line =~ m/\s*(\w+)\s*=\s*'([^']*)'\s*(\#.*|)$/mx) {
            $key   = $1;
            $value = $2;
        }
        elsif($line =~ m/\s*(\w+)\s*=\s*(.*?)\s*(\#.*|)$/mx) {
            $key   = $1;
            $value = $2;
        }

        if($key) {
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

    return($content, $data, $hexdigest);
}


######################################

=head2 merge_conf

merge config file with data

=cut

sub merge_conf {
    my($text, $data) = @_;

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
                    if($value =~ m/\#/mx) {
                        $value = '"'.$value.'"';
                    }
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
        $string .= "        logcache_fetchlogs_command = ".$b->{'logcache_fetchlogs_command'}."\n" if $b->{'logcache_fetchlogs_command'};
        $string .= "        authoritive = ".$b->{'authoritive'}."\n" if defined $b->{'authoritive'};
        $string .= "        <options>\n" if(defined $b->{'options'} and scalar keys %{$b->{'options'}} > 0);
        for my $p (@{$b->{options}->{peer}}) {
        $string .= "            peer          = ".$p."\n";
        }
        if($b->{'options'}->{'resource_file'}) {
            for my $r (@{Thruk::Base::list($b->{'options'}->{'resource_file'})}) {
                $string .= "            resource_file = ".$r."\n";
            }
        }
        $string .= "            auth          = ".$b->{'options'}->{'auth'}."\n"          if $b->{'options'}->{'auth'};
        $string .= "            proxy         = ".$b->{'options'}->{'proxy'}."\n"         if $b->{'options'}->{'proxy'};
        $string .= "            remote_name   = ".$b->{'options'}->{'remote_name'}."\n"   if $b->{'options'}->{'remote_name'};
        $string .= "            fallback_peer = ".$b->{'options'}->{'fallback_peer'}."\n" if $b->{'options'}->{'fallback_peer'};
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
        if($b->{'lmd_options'} && scalar keys %{$b->{'lmd_options'}} > 0) {
            $string .= "        <lmd_options>\n";
            for my $key (sort keys %{$b->{'lmd_options'}}) {
                $string .= "            $key      = ".$b->{'lmd_options'}->{$key}."\n";
            }
            $string .= "        </lmd_options>\n";
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
        $content = Thruk::Utils::IO::read($file);
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
    my($c) = @_;

    # get users from core contacts
    my $contacts = $c->db->get_contacts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contact' ) ], columns => [qw/name alias/]);
    my $all_contacts = {};
    for my $contact (@{$contacts}) {
        $all_contacts->{$contact->{'name'}} = { name => $contact->{'name'}, alias => $contact->{'alias'}};
    }

    # add users from htpasswd
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'}) {
        my $htpasswd = read_htpasswd($c->config->{'Thruk::Plugin::ConfigTool'}->{'htpasswd'});
        for my $user (keys %{$htpasswd}) {
            $all_contacts->{$user} = { name => $user } unless defined $all_contacts->{$user};
        }
    }

    # add users from cgi.cfg
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'}) {
        my $file                  = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
        my $defaults              = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
        my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);
        my $extra_user = [];
        for my $key (keys %{$data}) {
            next unless $key =~ m/^authorized_for_/mx;
            push @{$extra_user}, @{$data->{$key}->[1]};
        }
        for my $user (@{$extra_user}) {
            $all_contacts->{$user} = { name => $user } unless defined $all_contacts->{$user};
        }
    }

    # add users from profiles
    my @profiles = glob($c->config->{'var_path'}."/users/*");
    for my $profile (@profiles) {
        $profile =~ s/^.*\///gmx;
        $all_contacts->{$profile} = { name => $profile } unless defined $all_contacts->{$profile};
    }

    # add special users
    $all_contacts->{'*'} = { name => '*' };

    return $all_contacts;
}


##########################################################

=head2 get_cgi_group_list

get list of cgi groups from cgi.cfg and contactgroups table

=cut

sub get_cgi_group_list {
    my ( $c ) = @_;

    # get users from core contacts
    my $groups = $c->db->get_contactgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contactgroups' ) ],
                                                remove_duplicates => 1);
    my $all_groups = {};
    for my $group (@{$groups}) {
        $all_groups->{$group->{'name'}} = $group->{'name'}." - ".$group->{'alias'};
    }

    # add users from cgi.cfg
    if(defined $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'}) {
        my $file                  = $c->config->{'Thruk::Plugin::ConfigTool'}->{'cgi.cfg'};
        my $defaults              = Thruk::Utils::Conf::Defaults->get_cgi_cfg();
        my($content, $data, $hex) = Thruk::Utils::Conf::read_conf($file, $defaults);
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
    my $content  = Thruk::Utils::IO::read($file);
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
    my($c, $backend) = @_;
    confess("no backend") unless $backend;
    $c->stats->profile(begin => "store_model_retention($backend)");

    my $model   = $c->app->obj_db_model;
    my $user_id = Thruk::Utils::Crypt::hexdigest($c->stash->{'remote_user'} || '');

    # store changes/stashed changes to local user, unchanged config can be stored in a generic file
    my $file      = $c->config->{'conf_retention_file'};
    my $user_file = $c->config->{'var_path'}."/obj_retention.".$backend.".".$user_id.".dat";
    if(!$file) {
        $file  = $c->config->{'var_path'}."/obj_retention.".$backend.".dat";
    }
    if($model->{'configs'}->{$backend}->{'needs_commit'} || $c->stash->{'use_user_model_retention_file'}) {
        $file = $user_file;
    } else {
        unlink($user_file);
        $file  = $c->config->{'var_path'}."/obj_retention.".$backend.".dat";
    }

    confess("no such backend") unless defined $model->{'configs'}->{$backend};

    # try to save retention data
    eval {
        # delete some useless references
        delete $model->{'configs'}->{$backend}->{'stats'};
        delete $model->{'configs'}->{$backend}->{'remotepeer'};
        confess("no data") if(!$model->{'configs'}->{$backend} || ref $model->{'configs'}->{$backend} ne 'Monitoring::Config' || scalar keys %{$model->{'configs'}->{$backend}} == 0);
        my $data = {
            'configs'      => {$backend => $model->{'configs'}->{$backend}},
            'release_date' => $c->config->{'released'},
            'version'      => $c->config->{'thrukversion'},
        };
        store($data, $file);
        $c->config->{'conf_retention'}      = [stat($file)];
        $c->config->{'conf_retention_file'} = $file;
        $c->config->{'conf_retention_hex'}  = $c->cluster->is_clustered() ? Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($file)) : '';
        $c->stash->{'obj_model_changed'} = 0;
        _debug('saved object retention data');
    };
    if($@) {
        _error($@);
        $c->stats->profile(end => "store_model_retention($backend)");
        return;
    }

    $c->stats->profile(end => "store_model_retention($backend)");
    return 1;
}

##########################################################

=head2 get_model_retention

restore object model from storable

=cut
sub get_model_retention {
    my($c, $backend) = @_;
    $c->stats->profile(begin => "get_model_retention($backend)");

    my $model   = $c->app->obj_db_model;
    my $user_id = Thruk::Utils::Crypt::hexdigest($c->stash->{'remote_user'} || '');

    # migrate files from tmp_path to var_path
    my $tmp_path = $c->config->{'tmp_path'};
    my $var_path = $c->config->{'var_path'};

    my $file  = $c->config->{'var_path'}."/obj_retention.".$backend.".".$user_id.".dat";
    if(! -f $file) {
        $file  = $c->config->{'var_path'}."/obj_retention.".$backend.".dat";
    }

    if(! -f $file) {
        $c->stats->profile(end => "get_model_retention($backend)");
        return 1 if $model->cache_exists($backend);
        return;
    }

    # don't read retention file when current data is newer
    my @stat = stat($file);
    if( $model->cache_exists($backend)
        and defined $c->config->{'conf_retention'}
        and $stat[9] <= $c->config->{'conf_retention'}->[9]
        and $c->config->{'conf_retention_file'} eq $file
    ) {
        if(!$c->cluster->is_clustered()) {
            $c->stats->profile(end => "get_model_retention($backend)");
            return 1;
        }
        # cannot trust file timestamp in cluster mode since clocks might not be synchronous
        my $hex = Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($file));
        if($c->config->{'conf_retention_hex'} eq $hex) {
            $c->stats->profile(end => "get_model_retention($backend)");
            return 1;
        }
    }
    $c->config->{'conf_retention'}      = \@stat;
    $c->config->{'conf_retention_file'} = $file;
    $c->config->{'conf_retention_hex'}  = $c->cluster->is_clustered() ? Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($file)) : '';

    # try to retrieve retention data
    my $rc = 1;
    eval {
        my $data = retrieve($file);
        if(defined $data->{'release_date'}
           and $data->{'release_date'} eq $c->config->{'released'}
           and defined $data->{'version'}
           and $data->{'version'} eq $c->config->{'thrukversion'}
        ) {
            my $model_configs = $data->{'configs'};
            for my $backend (keys %{$model_configs}) {
                if(defined $c->stash->{'backend_detail'}->{$backend}) {
                    my $peer_conftool = $c->db->get_peer_by_key($backend);
                    $model->init($backend, undef, $model_configs->{$backend}, $c->stats, $peer_conftool);
                    _debug('restored object retention data for '.$backend);
                }
            }
        } else {
            # old or unknown file
            _debug('removed old retention file: version '.Dumper($data->{'version'}).' - date '.Dumper($data->{'release_date'}));
            unlink($file);
            undef $rc;
            return;
        }
    };
    if($@) {
        unlink($file);
        _error($@);
        $c->stats->profile(end => "get_model_retention($backend)");
        return;
    }

    _debug('model retention file '.$file.' loaded.');

    $c->stats->profile(end => "get_model_retention($backend)");
    return($rc);
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
    my($c, $peer_conftool, $model, $peer) = @_;

    $c->stats->profile(begin => "init_cached_config()");

    $c->{'obj_db'} = $model->init($c->stash->{'param_backend'}, $peer_conftool, undef, $c->{'stats'}, $peer);
    $c->{'obj_db'}->{'cached'} = 1;

    unless(_compare_configs($peer_conftool, $c->{'obj_db'}->{'config'})) {
        _debug("config object base files have changed, reloading complete obj db");
        $c->{'obj_db'}->{'initialized'} = 0;
        undef $c->{'obj_db'};
        $c->stash->{'obj_model_changed'} = 0;
        $c->stats->profile(end => "init_cached_config()");
        return 0;
    }

    _debug("cached config object loaded: ".$c->stash->{'param_backend'});
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

=head2 append_global_peer_config

append/merge global config tool settings

=cut
sub append_global_peer_config {
    my($c, $config) = @_;
    $config->{'obj_readonly'} = Thruk::Base::list($config->{'obj_readonly'});
    if($c->config->{'Thruk::Plugin::ConfigTool'}->{'obj_readonly'}) {
        push @{$config->{'obj_readonly'}},
            @{Thruk::Base::list($c->config->{'Thruk::Plugin::ConfigTool'}->{'obj_readonly'})};
        $config->{'obj_readonly'} = Thruk::Base::array_uniq($config->{'obj_readonly'});
    }
    return;
}

##########################################################
sub _compare_configs {
    my($c1, $c2) = @_;

    for my $key (qw/core_conf core_type/) {
        return 0 if !defined $c1->{$key} &&  defined $c2->{$key};
        return 0 if  defined $c1->{$key} && !defined $c2->{$key};
        next if !defined $c1->{$key} && !defined $c2->{$key};
        return 0 if $c1->{$key} ne $c2->{$key};
    }

    return 1;
}

##########################################################

=head2 link_obj

    link_obj($obj, [$line]);

returns html link to given object

=cut
sub link_obj {
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

    get_backends_with_obj_config($c, [$peerfilter]);

returns all backends which do have a objects configuration

=cut
sub get_backends_with_obj_config {
    my($c, $peerfilter) = @_;
    my $backends = {};

    &timing_breakpoint('Thruk::Utils::Conf::get_backends_with_obj_config start');

    my $fetch = _get_peer_keys_without_configtool($c);
    $fetch = [grep(/^$peerfilter$/mx, @{$fetch})] if $peerfilter;
    if(scalar @{$fetch} > 0 && !$ENV{'THRUK_USE_LMD'}) {
        &timing_breakpoint('Thruk::Utils::Conf::get_backends_with_obj_config II');
        eval {
            &timing_breakpoint('Thruk::Utils::Conf::get_backends_with_obj_config get_processinfo a');
            $c->db->get_processinfo(backend => $fetch, force_type => 'http');
            &timing_breakpoint('Thruk::Utils::Conf::get_backends_with_obj_config get_processinfo b');
        };
    }
    &timing_breakpoint('Thruk::Utils::Conf::get_backends_with_obj_config IV');

    # first hide all of them
    my @peers = @{$c->db->get_peers(1)};
    for my $peer (@peers) {
        my $min_key_size = 0;
        if(defined $peer->{'configtool'}->{remote} and $peer->{'configtool'}->{remote} == 1) { $min_key_size = 1; }
        if($peer->{'configtool'}->{'disable'}) {
        }
        elsif(scalar keys %{$peer->{'configtool'}} > $min_key_size) {
            $backends->{$peer->{'key'}} = $peer->{'configtool'};
        }
    }

    &timing_breakpoint('Thruk::Utils::Conf::get_backends_with_obj_config done');
    return $backends;
}

##########################################################

=head2 set_backends_with_obj_config

    set_backends_with_obj_config($c, [$peerfilter]);

returns all backends which do have a objects configuration and sets the first one active

=cut
sub set_backends_with_obj_config {
    my($c, $peerfilter) = @_;

    &timing_breakpoint('Thruk::Utils::Conf::set_backends_with_obj_config start');

    my $backends = get_backends_with_obj_config($c, $peerfilter);
    my $firstpeer;

    my $param_backend = $c->stash->{'param_backend'} || '';
    $c->stash->{'param_backend'} = '';

    # first hide all of them
    my @peers = @{$c->db->get_peers(1)};
    for my $peer (@peers) {
        my $min_key_size = 0;
        if(defined $peer->{'configtool'}->{remote} and $peer->{'configtool'}->{remote} == 1) { $min_key_size = 1; }
        if($peer->{'configtool'}->{'disable'}) {
            $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = DISABLED_CONF;
        }
        elsif(scalar keys %{$peer->{'configtool'}} > $min_key_size) {
            $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = HIDDEN_CONF;
        } else {
            $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} = DISABLED_CONF;
        }
    }

    # first non hidden peer with object config enabled
    for my $peer (@peers) {
        next if defined $peer->{'hidden'} and $peer->{'hidden'} == 1;
        next if $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} == DISABLED_CONF;
        if(scalar keys %{$peer->{'configtool'}} > 0) {
            next if $peer->{'configtool'}->{'disable'};
            $firstpeer = $peer->{'key'} unless defined $firstpeer;
        }
    }

    # first peer with object config enabled
    if(!defined $firstpeer) {
        for my $peer (@peers) {
            next if $c->stash->{'backend_detail'}->{$peer->{'key'}}->{'disabled'} == DISABLED_CONF;
            if(scalar keys %{$peer->{'configtool'}} > 0) {
                next if $peer->{'configtool'}->{'disable'};
                $firstpeer = $peer->{'key'} unless defined $firstpeer;
            }
        }
    }

    # from cookie setting?
    if($c->cookies('thruk_conf') && !$param_backend) {
        my @cookie_val = $c->cookies('thruk_conf');
        for my $val (@cookie_val) {
            next unless defined $c->stash->{'backend_detail'}->{$val};
            $c->stash->{'param_backend'} = $val;
        }
    }

    # from url parameter
    if(defined $c->req->parameters->{'backend'}) {
        my $val = $c->req->parameters->{'backend'};
        if(defined $c->stash->{'backend_detail'}->{$val}) {
            $c->stash->{'param_backend'} = $val;
        }
    }
    $c->stash->{'param_backend'} = $param_backend unless $c->stash->{'param_backend'};
    if($c->stash->{'param_backend'}
        && (
            !defined $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}->{'disabled'}
            || $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}->{'disabled'} == DISABLED_CONF
        )
        ) {
        $c->stash->{'param_backend'} = '';
    }

    if($c->stash->{'param_backend'} eq '' and defined $firstpeer) {
        $c->stash->{'param_backend'} = $firstpeer;
    }
    if($c->stash->{'param_backend'} and defined $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}) {
        $c->stash->{'backend_detail'}->{$c->stash->{'param_backend'}}->{'disabled'} = UP_CONF;
    }

    # save value in the cookie, so later pages will show the same selected backend
    # will be changed from the site panel, so cannot be httponly
    $c->cookie('thruk_conf', $c->stash->{'param_backend'}, { httponly => 0 });

    $c->stash->{'backend_chooser'} = 'switch';

    &timing_breakpoint('Thruk::Utils::Conf::set_backends_with_obj_config done');
    return $backends;
}

##########################################################

=head2 config_check

    config_check($c, $backend);

checks config for given backend

=cut
sub config_check {
    my($c, $backend) = @_;
    die("backend is required") unless $backend;

    $c->stats->profile(begin => "Conf::config_check");

    set_object_model($c, 1, $backend) unless($c->stash->{'param_backend'} && $backend eq $c->stash->{'param_backend'});
    my $obj_check_cmd = $c->stash->{'peer_conftool'}->{'obj_check_cmd'};
    $obj_check_cmd = $obj_check_cmd.' 2>&1' if($obj_check_cmd && $obj_check_cmd !~ m|>|mx);
    my $rc = 0;
    if($c->{'obj_db'}->is_remote()) {
        if($c->{'obj_db'}->remote_config_check($c)) {
            Thruk::Utils::set_message( $c, 'success_message', 'config check successfull' );
            $rc = 1;
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'config check failed!' );
        }
    } else {
        if(_cmd($c, $obj_check_cmd)) {
            Thruk::Utils::set_message( $c, 'success_message', 'config check successfull' );
            $rc = 1;
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'config check failed!' );
        }
    }
    _nice_check_output($c);

    $c->stash->{'needs_commit'}      = $c->{'obj_db'}->{'needs_commit'};
    $c->stash->{'last_changed'}      = $c->{'obj_db'}->{'last_changed'};

    $c->stats->profile(end => "Conf::config_check");
    return($rc, $c->stash->{'original_output'});
}

##########################################################

=head2 config_reload

    config_reload($c, $backend);

reloads given backend

=cut
sub config_reload {
    my($c, $backend) = @_;
    die("backend is required") unless $backend;
    $c->stats->profile(begin => "Conf::config_reload");

    set_object_model($c, 1, $backend) unless($c->stash->{'param_backend'} && $backend eq $c->stash->{'param_backend'});
    $c->stash->{'original_output'} = "";
    my $time = time();
    my $peer = $c->db->get_peer_by_key($backend);
    my $pkey = $peer->peer_key();
    my $wait = 1;
    my $rc   = 1;

    my $cmd = $c->stash->{'peer_conftool'}->{'obj_reload_cmd'};
    $cmd = $cmd.' 2>&1' if($cmd && $cmd !~ m|>|mx);

    my $last_reload = $c->stash->{'pi_detail'}->{$pkey}->{'program_start'};
    if(!$last_reload) {
        my $processinfo = $c->db->get_processinfo(backends => $pkey);
        $last_reload = ($processinfo->{$pkey} && $processinfo->{$pkey}->{'program_start'}) || (time());
    }
    sleep(1) if int($last_reload) == int(time());

    if($cmd) {
        if($c->{'obj_db'}->is_remote() && $c->{'obj_db'}->remote_config_reload($c)) {
            Thruk::Utils::set_message( $c, 'success_message', 'config reloaded successfully' );
            $c->{'obj_db'}->{'last_changed'} = 0;
            $c->{'obj_db'}->{'needs_commit'} = 0;
            Thruk::Utils::Conf::store_model_retention($c, $pkey);
        }
        elsif(!$c->{'obj_db'}->is_remote() && _cmd($c, $cmd)) {
            Thruk::Utils::set_message( $c, 'success_message', 'config reloaded successfully' );
            $c->{'obj_db'}->{'last_changed'} = 0;
            $c->{'obj_db'}->{'needs_commit'} = 0;
            Thruk::Utils::Conf::store_model_retention($c, $pkey);
        } else {
            Thruk::Utils::set_message( $c, 'fail_message', 'config reload failed!' );
            $wait = 0;
            $rc   = 0;
        }

        _nice_check_output($c);
    } else {
        # restart by livestatus
        die("no backend found by name ".$backend) unless $peer;
        my $options = {
            'command' => sprintf("COMMAND [%d] RESTART_PROCESS", $time),
            'backend' => [ $pkey ],
        };
        $c->db->send_command( %{$options} );
        $c->stash->{'output'} = 'config reloaded by external command.';
    }
    $c->stats->profile(comment => "reload command issued: ".time());

    # wait until core responds again
    if($wait) {
        if(!Thruk::Utils::wait_after_reload($c, $pkey, $last_reload)) {
            $c->stash->{'original_output'} .= 'Warning: waiting for core reload failed.';
            $c->stash->{'output'}          .= "\n<font color='red'>".$c->stash->{'original_output'}."</font>";
            $rc = 0;
        }
    }

    $c->stats->profile(end => "Conf::config_reload");
    $c->stash->{'reload_rc'} = $rc;
    return($rc, $c->stash->{'original_output'});
}

##########################################################
sub _get_peer_keys_without_configtool {
    my($c) = @_;
    my @peers = @{$c->db->get_peers(1)};
    my @fetch;
    &timing_breakpoint('_get_peer_keys_without_configtool');
    for my $peer (@peers) {
        next if (defined $peer->{'disabled'} && $peer->{'disabled'} == HIDDEN_LMD_PARENT);
        for my $addr (@{$peer->peer_list()}) {
            my $prev_remote;
            if(defined $peer->{'configtool'} && defined $peer->{'configtool'}->{'remote'}) {
                $prev_remote = delete $peer->{'configtool'}->{'remote'};
            }
            if($addr =~ /^http/mxi && (!defined $peer->{'configtool'} || scalar keys %{$peer->{'configtool'}} == 0)) {
                if(!$c->stash->{'failed_backends'}->{$peer->{'key'}}) {
                    $peer->{'configtool'} = { remote => 1 };
                    push @fetch, $peer->{'key'};
                    last;
                }
            }
            $peer->{'configtool'}->{'remote'} = $prev_remote if defined $prev_remote;
        }
    }
    &timing_breakpoint('_get_peer_keys_without_configtool done');
    return \@fetch;
}

##########################################################

=head2 clean_from_tool_ignores

    clean_from_tool_ignores($list, $ignores);

returns list with all ignores removed

=cut
sub clean_from_tool_ignores {
    my($list, $ignores) = @_;
    return(0, $list) unless $ignores;
    my $hidden  = 0;
    my $cleaned = [];
    for my $r (@{$list}) {
        if(!defined $ignores->{$r->{'ident'}}) {
            push @{$cleaned}, $r;
        } else {
            $hidden++;
        }
    }
    return($hidden, $cleaned);
}

##########################################################

=head2 start_file_edit

    start_file_edit($c, $path);

start editing a file

=cut
sub start_file_edit {
    my($c, $path) = @_;
    my $file = $c->{'obj_db'}->get_file_by_path($path);
    if(defined $file && !$file->{'backup'} && !$file->{'is_new_file'}) {
        $file->set_backup();
        $c->stash->{'obj_model_changed'} = 1;
    }
    $c->stash->{'use_user_model_retention_file'} = 1;
    return $file;
}

##########################################################
sub _nice_check_output {
    my($c) = @_;
    $c->stash->{'original_output'} = $c->stash->{'output'};
    $c->stash->{'output'} =~ s/^Website:.*?\n//gmx;
    $c->stash->{'output'} =~ s/^Copyright.*?\n//gmx;
    $c->stash->{'output'} =~ s/^License.*?\n\n//gmx;
    $c->stash->{'output'} =~ s/(Warning\s*:.*)$/<span class="textHINT font-bold">$1<\/span>/gmx;
    $c->stash->{'output'} =~ s/(Error\s*:.*)$/<span class="textALERT font-bold">$1<\/span>/gmx;
    $c->stash->{'output'} =~ s/(CONFIG\s+ERROR.*)$/<span class="textALERT font-bold">$1<\/span>/gmx;
    $c->stash->{'output'} =~ s/(\(config\s+file\s+'(.*?)',\s+starting\s+(?:on|at)\s+line\s+(\d+)\))/<a class="link dotted" href="conf.cgi?sub=objects&amp;file=$2&amp;line=$3">$1<\/a>/gmx;
    $c->stash->{'output'} =~ s/\s+in\s+file\s+'(.*?)'\s+on\s+line\s+(\d+)/ in file <a class="link dotted" href="conf.cgi?sub=objects&amp;type=file&amp;file=$1&amp;line=$2">'$1' on line $2<\/a>/gmx;
    $c->stash->{'output'} =~ s/\s+in\s+(\w+)\s+'(.*?)'/ in $1 '<a class="link dotted" href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>'/gmx;
    $c->stash->{'output'} =~ s/Warning:\s+(\w+)\s+'(.*?)'\s+/Warning: $1 '<a class="link dotted textHINT" href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>' /gmx;
    $c->stash->{'output'} =~ s/Error:\s+(\w+)\s+'(.*?)'\s+/Error: $1 '<a class="link dotted textALERT" href="conf.cgi?sub=objects&amp;type=$1&amp;data.name=$2">$2<\/a>' /gmx;
    $c->stash->{'output'} =~ s/Error\s*:\s*the\s+service\s+([^\s]+)\s+on\s+host\s+'([^']+)'/Error: the service <a class="link dotted textALERT" href="conf.cgi?sub=objects&amp;type=service&amp;data.name=$1&amp;data.name2=$2">$1<\/a> on host '$2'/gmx;
    $c->stash->{'output'} = "<pre>".$c->stash->{'output'}."</pre>";
    return;
}

##########################################################
sub _cmd {
    my($c, $cmd, $stdin) = @_;

    my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd, $stdin);
    $c->stash->{'output'} = $output;
    if($rc != 0) {
        return 0;
    }
    return 1;
}

##########################################################

1;
