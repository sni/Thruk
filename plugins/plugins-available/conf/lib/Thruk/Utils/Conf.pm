package Thruk::Utils::Conf;

use strict;
use warnings;
use File::Slurp;
use Digest::MD5 qw(md5_hex);
use Storable qw/store retrieve/;
use Data::Dumper;

=head1 NAME

Thruk::Utils::Conf.pm - Helper Functios for the Config Tool

=head1 DESCRIPTION

Helper Functios for the Config Tool

=head1 METHODS

=cut


######################################

=head2 read_objects

read objects and store them as storable

=cut
sub read_objects {
    my $c             = shift;
    $c->stats->profile(begin => "read_objects()");
    my $model         = $c->model('Objects');
    my $peer_conftool = $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'configtool'};
    my $obj_db        = $model->init($c->stash->{'param_backend'}, $peer_conftool);
    store_model_retention($c);
    $c->stash->{model_type} = 'Objects';
    $c->stash->{model_init} = [ $c->stash->{'param_backend'}, $peer_conftool, $obj_db ];
    $c->stats->profile(end => "read_objects()");
    return;
}


######################################

=head2 update_conf

update inline config

=cut
sub update_conf {
    my $file     = shift;
    my $data     = shift;
    my $md5      = shift;
    my $defaults = shift;
    my $update_c = shift;

    my($old_content, $old_data, $old_md5) = read_conf($file, $defaults);
    if($md5 ne $old_md5) {
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
            }
        }
    }

    my $new_content = merge_conf($old_content, $data);

    if($new_content eq $old_content) {
        return("no changes made");
    }

    open(my $fh, ">", $file) or return("cannot update, failed to write to $file: $!");
    print $fh $new_content;
    close($fh);

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
        my $data = {
            'configs'      => $model->{'configs'},
            'release_date' => $c->config->{'released'},
            'version'      => $c->config->{'version'},
        };
        store($data, $file);
        $c->stash->{'obj_model_changed'} = 0;
        $c->log->debug('saved object retention data');
    };
    if($@) {
        $c->log->error($@);
        $c->stats->profile(end => "store_model_retention()");
        return;
    }

    $c->stats->profile(end => "store_model_retention()");
    return;
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

    return unless -f $file;

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
                    $model->init($backend, undef, $model_configs->{$backend});
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

=head2 init_cached_config

set current obj_db from cached config

=cut
sub init_cached_config {
    my($c, $peer_conftool, $model) = @_;

    $c->stats->profile(begin => "init_cached_config()");

    $c->{'obj_db'} = $model->init($c->stash->{'param_backend'}, $peer_conftool);
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

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
