package Monitoring::Config;

use strict;
use warnings;
use Carp qw/cluck/;
use Monitoring::Config::File;
use Encode qw/decode_utf8/;
use Data::Dumper;
use Carp;
use Storable qw/dclone/;
use Thruk::Utils;
use Thruk::Config;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Monitoring::Config - Thruks Object Database

=head1 DESCRIPTION

Provides access to core objects like hosts, services etc...

=head1 METHODS

=cut

$Monitoring::Config::save_options = {
    indent_object_key           => 2,
    indent_object_value         => 30,
    indent_object_comments      => 68,
    list_join_string            => ',',
    break_long_arguments        => 1,
    object_attribute_key_order  => [
                                    'name',
                                    'service_description',
                                    'host_name',
                                    'timeperiod_name',
                                    'contact_name',
                                    'contactgroup_name',
                                    'hostgroup_name',
                                    'servicegroup_name',
                                    'command_name',
                                    'alias',
                                    'address',
                                    'parents',
                                    'use',
                                    'monday',
                                    'tuesday',
                                    'wednesday',
                                    'thursday',
                                    'friday',
                                    'saturday',
                                    'sunday',
                                    'module_name',
                                    'module_type',
                                    'path',
                                    'args',
                                ],
      object_cust_var_order     => [
                                   '_TYPE',
                                   '_TAGS',
                                   '_APPS',
                                ],
};
$Monitoring::Config::key_sort = undef;

$Monitoring::Config::plugin_pathspec = '(/plugins/|/libexec/|/monitoring\-plugins/)';

##########################################################

=head2 new

    new({
        core_conf           => path to core config
        obj_file            => path to core config file
        obj_dir             => path to core config path
        obj_resource_file   => paths to resource.cfg file
        obj_readonly        => readonly pattern
        obj_exclude         => exclude pattern
        git_base_dir        => git history base folder
        localdir            => local path used for remote configs
        relative            => allow relative paths
    })

return new objects database

=cut
sub new {
    my $class  = shift;
    my $config = shift;

    my $self = {
        'config'             => {},
        'errors'             => [],
        'parse_errors'       => [],
        'files'              => [],
        'files_index'        => {},
        'initialized'        => 0,
        'cached'             => 0,
        'needs_update'       => 0,
        'needs_commit'       => 0,
        'last_changed'       => 0,
        'needs_index_update' => 0,
        'coretype'           => 'auto',
        'cache'              => {},
        'remotepeer'         => undef,
    };

    $self->{'config'}->{'localdir'} =~ s/\/$//gmx if defined $self->{'config'}->{'localdir'};

    for my $key (keys %{$config}) {
        next if $key eq 'configs'; # creates circular dependency otherwise
        $self->{'config'}->{$key} = $config->{$key};
    }

    bless $self, $class;

    _set_output_format($Monitoring::Config::save_options);

    # read rc file
    $self->read_rc_file();

    return $self;
}


##########################################################

=head2 init

    init($config, [ $stats ])

initialize configs

=cut
sub init {
    my($self, $config, $stats, $remotepeer) = @_;
    delete $self->{'remotepeer'};
    if(defined $remotepeer and lc($remotepeer->{'type'}) eq 'http') {
        $self->{'remotepeer'} = $remotepeer;
    }
    $self->{'stats'} = $stats if defined $stats;

    # some keys might have been changed in the thruk_local.conf, so update them
    for my $key (qw/git_base_dir/) {
        $self->{'config'}->{$key} = $config->{$key};
    }

    # update readonly config
    if($self->_array_diff($self->_list($self->{'config'}->{'obj_readonly'}), $self->_list($config->{'obj_readonly'}))) {
        $self->{'config'}->{'obj_readonly'} = $config->{'obj_readonly'};

        # update all readonly file settings
        for my $file (@{$self->{'files'}}) {
            $file->update_readonly_status($self->{'config'}->{'obj_readonly'});
        }
    }

    # read rc file, must be read every time, otherwise key_sort is not defined
    $self->read_rc_file();

    return $self unless $self->{'initialized'} == 0;
    $self->{'initialized'} = 1;

    delete $self->{'config'}->{'localdir'};
    for my $key (keys %{$config}) {
        next if $key eq 'configs'; # creates circular dependency otherwise
        $self->{'config'}->{$key} = $config->{$key};
    }
    $self->update();
    $self->{'cached'}      = 0;
    $self->{'config'}->{'localdir'} =~ s/\/$//gmx if defined $self->{'config'}->{'localdir'};

    # set default excludes when defined manual paths
    if(!defined $self->{'config'}->{'obj_exclude'}
       && !$self->{'config'}->{'core_conf'}) {
        $self->{'config'}->{'obj_exclude'} = [
                    '^cgi.cfg$',
                    '^resource.cfg$',
                    '^naemon.cfg$',
                    '^nagios.cfg$',
                    '^icinga.cfg$',
        ];
    }

    delete $self->{'remotepeer'};

    return $self;
}


##########################################################

=head2 discard_changes

    discard_changes()

Forget all changes made so far and not yet saved to disk

=cut
sub discard_changes {
    my($self) = @_;
    $self->{'logs'} = []; # clear audit log stash
    $self->check_files_changed(1);
    return;
}


##########################################################

=head2 commit

    commit([$c])

Commit changes to disk. Returns 1 on success.

$c is only needed when syncing with remote sites.

=cut
sub commit {
    my($self, $c) = @_;
    my $rc    = 1;

    my $filesroot    = $self->get_files_root();
    my $backend_name = '';

    # run pre hook
    if($c and $c->config->{'Thruk::Plugin::ConfigTool'}->{'pre_obj_save_cmd'}) {
        $backend_name = $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'};
        local $ENV{THRUK_BACKEND_ID}   = $c->stash->{'param_backend'};
        local $ENV{THRUK_BACKEND_NAME} = $backend_name;
        my $cmd = $c->config->{'Thruk::Plugin::ConfigTool'}->{'pre_obj_save_cmd'}." pre '".$filesroot."' 2>&1";
        my($rc, $out) = Thruk::Utils::IO::cmd($c, $cmd);
        _debug("pre save hook: '" . $cmd . "', rc: " . $rc);
        if($rc != 0) {
            _info('pre save hook out: '.$out);
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "Save canceled by pre_obj_save_cmd hook!\n".$out, escape => 0 });
            return;
        }
        _debug('pre save hook out: '.$out);
    }

    # log stashed changes
    if($self->{'logs'}) {
        if($c && !$ENV{'THRUK_TEST_CONF_NO_LOG'}) {
            my $uniq = {};
            for my $l (@{$self->{'logs'}}) {
                _audit_log("configtool", $l) unless $uniq->{$l};
                $uniq->{$l} = 1;
            }
        }
        $self->{'logs'} = [];
    }

    my $files = { changed => [], deleted => []};
    my $changed_files = $self->get_changed_files();
    for my $file (@{$changed_files}) {
        my $is_new_file = $file->{'is_new_file'};
        if(scalar @{$file->{'objects'}} == 0) {
            $self->file_delete($file);
        }
        unless($file->save()) {
            $rc = 0;
        } else {
            # do some logging
            _audit_log("configtool",
                            sprintf("[config][%s][%s] %s file '%s'",
                                        $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                        $c->stash->{'remote_user'},
                                        $is_new_file ? 'created' : 'saved',
                                        $file->{'display'},
            )) if($c && !$ENV{'THRUK_TEST_CONF_NO_LOG'});
        }
        push @{$files->{'changed'}}, [ $file->{'display'}, decode_utf8("".$file->get_new_file_content()), $file->{'mtime'} ] unless $file->{'deleted'};
    }

    # remove deleted files from files
    my @new_files;
    my %new_index;
    for my $f (@{$self->{'files'}}) {
        if(!$f->{'deleted'} || -f $f->{'path'}) {
            push @new_files, $f;
            $new_index{$f->{'display'}} = $f;
            $new_index{$f->{'path'}}    = $f;
        } else {
            if($c && $f->{'deleted'}) {
                _audit_log("configtool",
                                sprintf("[config][%s][%s] deleted file '%s'",
                                            $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                            $c->stash->{'remote_user'},
                                            $f->{'display'},
                )) if $c;
            }
            push @{$files->{'deleted'}}, $f->{'display'};
        }
    }
    $self->{'files'}       = \@new_files;
    $self->{'files_index'} = \%new_index;
    if($rc == 1) {
        $self->{'needs_commit'} = 0;
        $self->{'last_changed'} = time() if scalar @{$changed_files} > 0;
    }

    $self->_collect_errors();

    if($self->is_remote()) {
        confess("no c") unless $c;
        $self->remote_file_save($c, $files);
    }

    # run post hook
    if($c and $c->config->{'Thruk::Plugin::ConfigTool'}->{'post_obj_save_cmd'}) {
        local $ENV{THRUK_BACKEND_ID}   = $c->stash->{'param_backend'};
        local $ENV{THRUK_BACKEND_NAME} = $backend_name;
        my $cmd = $c->config->{'Thruk::Plugin::ConfigTool'}->{'post_obj_save_cmd'}." post '".$filesroot."' 2>&1";
        my($rc, $out) = Thruk::Utils::IO::cmd($c, $cmd);
        _debug("post save hook: '" . $cmd . "', rc: " . $rc);
        if($rc != 0) {
            _info('post save hook out: '.$out);
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "post_obj_save_cmd hook failed!\n".$out, escape => 0 });
            return;
        }
        _debug('post save hook out: '.$out);
    }

    $self->_rebuild_index(); # also checks files again for errors
    return $rc;
}

##########################################################

=head2 print_errors

    print_errors([$fh])

Print all errors to stdout or supplied filehandle

=cut
sub print_errors {
    my($self, $fh) = @_;
    $fh = *STDOUT unless $fh;

    $self->_collect_errors();
    for my $err (@{$self->{'parse_errors'}}) {
        print $fh $err, "\n";
    }
    for my $err (@{$self->{'errors'}}) {
        print $fh $err, "\n";
    }

    return;
}


##########################################################

=head2 get_files

    get_files()

Get all files. Returns list of L<Monitoring::Config::File|Monitoring::Config::File> objects.

=cut
sub get_files {
    my $self = shift;
    return $self->{'files'};
}


##########################################################

=head2 get_file_by_path

    get_file_by_path($path)

Get file by path. Returns L<Monitoring::Config::File|Monitoring::Config::File> object or undef.

=cut
sub get_file_by_path {
    my($self, $path) = @_;
    my $file = $self->{'files_index'}->{$path};
    return($file) if $file;
    for my $file (@{$self->{'files'}}) {
        if($file->{'path'} eq $path or $file->{'display'} eq $path) {
            $self->{'files_index'}->{$file->{display}} = $file;
            $self->{'files_index'}->{$file->{path}}    = $file;
            return $file;
        }
    }
    return;
}


##########################################################

=head2 get_changed_files

    get_changed_files()

Get all changed files. Returns list of L<Monitoring::Config::File|Monitoring::Config::File> objects.

=cut
sub get_changed_files {
    my $self = shift;
    my @files;
    for my $file (@{$self->{'files'}}) {
        push @files, $file if $file->{'changed'} == 1;
    }
    $self->{'needs_commit'} = (scalar @files == 0) ? 0 : 1;
    return \@files;
}


##########################################################

=head2 get_objects

    $list = get_objects()

Get all objects. Returns list of L<Monitoring::Config::Object|Monitoring::Config::Object> objects.

=cut
sub get_objects {
    my $self = shift;
    my @objects = values %{$self->{'objects'}->{'byid'}};
    return \@objects;
}


##########################################################

=head2 get_objects_by_type

    $list = get_objects_by_type($type, [ $filter ], [ $origin])

Returns list of L<Monitoring::Config::Object|Monitoring::Config::Object> objects for a type.

filter is verified against the name if its a scalar value. Otherwise it has to be like

 $filter = {
    attribute => value
 };

 origin is used for commands and can be 'check', 'eventhandler' or 'notification'

=cut
sub get_objects_by_type {
    my($self, $type, $filter, $origin) = @_;

    return [] unless defined $self->{'objects'}->{'byname'}->{$type};

    # scalar filter by name only
    if(defined $filter and ref $filter eq '') {
        if(defined $self->{'objects'}->{'byname'}->{$type}->{$filter}) {
            my $id  = $self->{'objects'}->{'byname'}->{$type}->{$filter};
            return $id if ref $id;
            return({$type.'_name' => { $filter => $id }});
        }
        return;
    }

    my $objs = [];
    for my $id (@{$self->{'objects'}->{'bytype'}->{$type}}) {
        my $obj = $self->get_object_by_id($id);
        die($id) unless defined $obj;

        if(defined $filter and ref $filter eq 'HASH') {
            my $ok = 1;
            for my $attr (keys %{$filter}) {
                if(!defined $obj->{'conf'}->{$attr}) {
                    $ok = 0;
                }
                elsif(ref $obj->{'conf'}->{$attr} eq '') {
                    $ok = 0 unless $obj->{'conf'}->{$attr} eq $filter->{$attr};
                }
                elsif(ref $obj->{'conf'}->{$attr} eq 'ARRAY') {
                    my $found = 0;
                    for my $el (@{$obj->{'conf'}->{$attr}}) {
                        if($el eq $filter->{$attr}) {
                            $found = 1;
                            last;
                        }
                    }
                    $ok = 0 unless $found;
                }
                last unless $ok;
            }
            push @{$objs}, $obj if $ok;
        } else {
            push @{$objs}, $obj;
        }
    }

    # filter by origin?
    if($type eq 'command' and defined $origin) {
        my $command_list = {};
        if($origin eq 'check') {
            for my $otype (qw/host service/) {
                my $os = $self->get_objects_by_type($otype);
                for my $o (@{$os}) {
                    next unless defined $o->{'conf'}->{'check_command'};
                    my($cmd, $args) = split(/\!/mx, $o->{'conf'}->{'check_command'}, 2);
                    $command_list->{$cmd} = 1;
                }
            }
        }
        if($origin eq 'notification') {
            my $os = $self->get_objects_by_type('contact');
            for my $o (@{$os}) {
                if(defined $o->{'conf'}->{'host_notification_commands'}) {
                    for my $cmd (@{$o->{'conf'}->{'host_notification_commands'}}) {
                        $command_list->{$cmd} = 1;
                    }
                }
                if(defined $o->{'conf'}->{'service_notification_commands'}) {
                    for my $cmd (@{$o->{'conf'}->{'service_notification_commands'}}) {
                        $command_list->{$cmd} = 1;
                    }
                }
            }
        }
        if($origin eq 'eventhandler') {
            for my $otype (qw/host service/) {
                my $os = $self->get_objects_by_type($otype);
                for my $o (@{$os}) {
                    next unless defined $o->{'conf'}->{'event_handler'};
                    for my $cmd (@{$o->{'conf'}->{'event_handler'}}) {
                        $command_list->{$cmd} = 1;
                    }
                }
            }
        }
        # reduce object list by origin filter
        @{$objs} = grep { defined $command_list->{$_->get_primary_name()} } @{$objs};
    }

    return $objs;
}


##########################################################

=head2 get_objects_by_name

    get_objects_by_name($type, $name, [ $templates_only , [ $name2 ]])

Get objects by name. Returns list of L<Monitoring::Config::Object|Monitoring::Config::Object> objects.

=cut
sub get_objects_by_name {
    my $self           = shift;
    my $type           = shift;
    my $name           = shift;
    my $templates_only = shift || 0;
    my $name2          = shift;

    # object with secondary name
    if(defined $name2 and $name2 ne '') {
        my $subtype;
        ($subtype,$name2) = split/:/mx, $name2, 2;
        my $objects = $self->get_objects_by_type($type, $name);
        my $id;
        if($subtype eq 'ho') {
            $id = $objects->{'host_name'}->{$name2};
        } elsif($subtype eq 'hg') {
            $id = $objects->{'hostgroup_name'}->{$name2};
        }
        if(defined $id) {
            my $obj = $self->get_object_by_id($id);
            confess("corrupt objects") unless defined $obj;
            return [$obj];
        }
        return [];
    }

    # existing template
    my $objs = {};
    my $tid  = $self->{'objects'}->{'byname'}->{'templates'}->{$type}->{$name};
    if(defined $tid) {
        my $obj = $self->get_object_by_id($tid);
        confess("corrupt objects") unless defined $obj;
        $objs->{$tid} = $obj;
    }

    # existing object
    unless($templates_only) {
        if(defined $self->{'objects'}->{'byname'}->{$type}->{$name}) {
            my $id = $self->{'objects'}->{'byname'}->{$type}->{$name};
            unless(ref $id) {
                my $obj = $self->get_object_by_id($id);
                confess("corrupt objects") unless defined $obj;
                $objs->{$id} = $obj;
            } else {
                for my $subtype (keys %{$id}) {
                    for my $subid (values %{$id->{$subtype}}) {
                        my $obj = $self->get_object_by_id($subid);
                        confess("corrupt objects") unless defined $obj;
                        $objs->{$subid} = $obj;
                    }
                }
            }
        }
    }
    my @objects = values %{$objs};
    return \@objects;
}


##########################################################

=head2 get_objects_by_path

    get_objects_by_path($path)

Get all objects by path. Returns L<Monitoring::Config::Object|Monitoring::Config::Object> objects or undef.

=cut
sub get_objects_by_path {
    my($self, $path) = @_;

    my $objects = [];
    my $file    = $self->get_file_by_path($path);
    if($file) {
        for my $obj (@{$file->{'objects'}}) {
            push @{$objects}, $obj;
        }
    }
    return $objects;
}


##########################################################

=head2 get_templates_by_type

    get_templates_by_type($type)

Get templates by type. Returns list of L<Monitoring::Config::Object|Monitoring::Config::Object> objects.

=cut
sub get_templates_by_type {
    my($self, $type) = @_;

    return [] unless defined $self->{'objects'}->{'byname'}->{'templates'}->{$type};

    my $objs = [];
    my $ids  = [ values %{$self->{'objects'}->{'byname'}->{'templates'}->{$type}} ];
    for my $id (@{$ids}) {
        push @{$objs}, $self->get_object_by_id($id);
    }
    return $objs;
}


##########################################################

=head2 get_template_by_name

    get_template_by_name($type, $name)

Get template object by name. Returns list of L<Monitoring::Config::Object|Monitoring::Config::Object> objects.

=cut
sub get_template_by_name {
    my $self = shift;
    my $type = shift;
    my $name = shift;

    # existing template
    if(defined $self->{'objects'}->{'byname'}->{'templates'}->{$type}->{$name}) {
        return $self->get_object_by_id($self->{'objects'}->{'byname'}->{'templates'}->{$type}->{$name});
    }

    return;
}

##########################################################

=head2 get_object_by_location

    get_object_by_location($path, $linenr)

Get single object by path and line number. Returns L<Monitoring::Config::Object|Monitoring::Config::Object> objects or undef.

=cut
sub get_object_by_location {
    my($self, $path, $line) = @_;

    my $file = $self->get_file_by_path($path);
    if($file) {
        for my $obj (@{$file->{'objects'}}) {
            if(defined $obj->{'line'} and defined $obj->{'line2'}
               and $obj->{'line'} ne '' and $obj->{'line2'} ne ''
               and $line >= $obj->{'line'} and $line <= $obj->{'line2'}) {
                return $obj;
            }
        }
    }
    return;
}


##########################################################

=head2 get_object_by_id

    get_object_by_id($id)

Get object by id. Returns L<Monitoring::Config::Object|Monitoring::Config::Object> object or undef.

=cut
sub get_object_by_id {
    my $self = shift;
    my $id   = shift || confess("no id");

    return $self->{'objects'}->{'byid'}->{$id};
}


##########################################################

=head2 get_services_for_host

    get_services_for_host($hostobj)

Get services by host. Returns a hashref with ids of references:

 { host => {}, group => {} }

=cut
sub get_services_for_host {
    my $self    = shift;
    my $host    = shift;

    $self->{'stats'}->profile(begin => "M::C::get_services_for_host()") if defined $self->{'stats'};

    my($host_conf_keys, $host_config) = $host->get_computed_config($self);

    my $services  = { 'host' => {}, 'group' => {}};
    my $host_name = $host->get_name();
    my $groups    = $host->get_groups($self);

    for my $svc (@{$self->get_objects_by_type('service')}) {
        my($svc_conf_keys, $svc_config) = $svc->get_computed_config($self);

        # exclude hosts by !host_name
        if(defined $svc_config->{'host_name'} and grep { $_ eq '!'.$host_name } @{$svc_config->{'host_name'}}) {
            next;
        }

        # exclude hostgroup by !group
        if(defined $svc_config->{'hostgroup_name'}) {
            my $found = 0;
            for my $group (@{$groups}) {
                if(grep { $_ eq '!'.$group } @{$svc_config->{'hostgroup_name'}}) {
                    $found++;
                    last;
                }
            }
            next if $found;
        }

        my $name = $svc->get_name();
        if(defined $name) {
            if(defined $svc_config->{'host_name'} and grep { $_ eq $host_name } @{$svc_config->{'host_name'}}) {
                $services->{'host'}->{$name} = $svc;
            }
            if(defined $svc_config->{'hostgroup_name'}) {
                for my $group (@{$groups}) {
                    if(grep { $_ eq $group} @{$svc_config->{'hostgroup_name'}}) {
                        $services->{'group'}->{$name} = {'svc' => $svc, 'groups' => [] } unless defined $services->{'group'}->{$name};
                        push @{$services->{'group'}->{$name}->{'groups'}}, $group;
                        last;
                    }
                }
            }
        }
    }

    $self->{'stats'}->profile(end => "M::C::get_services_for_host()") if defined $self->{'stats'};

    return $services;
}

##########################################################

=head2 get_services_by_name

    get_services_by_name($host_name, $service_description)

Returns list of services for given host and service names

=cut
sub get_services_by_name {
    my($self, $host, $service) = @_;

    my $services = [];
    my $hosts = $self->get_objects_by_name('host', $host, 0);
    return $services unless $hosts;
    for my $h (@{$hosts}) {
        my $objs = $self->get_services_for_host($h);
        for my $type (keys %{$objs}) {
            for my $descr (keys %{$objs->{$type}}) {
                if($descr eq $service) {
                    my $o;
                    if(defined $objs->{$type}->{$descr}->{'svc'}) {
                        $o = $objs->{$type}->{$service}->{'svc'};
                    } else {
                        $o = $objs->{$type}->{$service};
                    }
                    push @{$services}, $o;
                }
            }
        }
    }
    return($services);
}

##########################################################

=head2 get_hosts_for_service

    get_hosts_for_service($svcobj)

Get hosts for service. Returns a list of hosts using this service.

=cut
sub get_hosts_for_service {
    my($self, $service) = @_;

    $self->{'stats'}->profile(begin => "M::C::get_hosts_for_service()") if defined $self->{'stats'};

    my($svc_conf_keys, $svc_config) = $service->get_computed_config($self);

    my $hosts = {};

    # directly assigned to service
    if(defined $svc_config->{'host_name'}) {
        for my $hst_name (@{$svc_config->{'host_name'}}) {
            my $hsts = $self->get_objects_by_name('host', $hst_name);
            if(scalar @{$hsts} > 0) {
                for my $hst (@{$hsts}) {
                    next if $hst->is_template();
                    $hosts->{$hst_name} = $hst->get_id();
                }
            }
        }
    }

    # assigned by hostgroup
    if(defined $svc_config->{'hostgroup_name'}) {
        for my $group_name (@{$svc_config->{'hostgroup_name'}}) {
            my $groups = $self->get_objects_by_name('hostgroup', $group_name);
            if($groups->[0]) {
                my $group = $groups->[0];
                my($grp_conf_keys, $grp_config) = $group->get_computed_config($self);
                if($grp_config->{'members'}) {
                    for my $hst_name (@{$grp_config->{'members'}}) {
                        my $hsts = $self->get_objects_by_name('host', $hst_name);
                        $hosts->{$hst_name} = $hsts->[0]->get_id() if $hsts->[0];
                    }
                }
                my $refs = $self->get_references($group);
                if($refs->{'host'}) {
                    for my $hst_id (keys %{$refs->{'host'}}) {
                        my $hst = $self->get_object_by_id($hst_id);
                        if($hst->is_template()) {
                            # check all refs for this host template too
                            my $child_refs = $self->get_references($hst);
                            if($refs->{'host'}) {
                                for my $hst_id (keys %{$child_refs->{'host'}}) {
                                    my $hst = $self->get_object_by_id($hst_id);
                                    $hosts->{$hst->get_name()} = $hst->get_id() if $hst;
                                }
                            }
                        } else {
                            $hosts->{$hst->get_name()} = $hst->get_id() if $hst;
                        }
                    }
                }
            }
        }
    }

    $self->{'stats'}->profile(end => "M::C::get_hosts_for_service()") if defined $self->{'stats'};

    return $hosts;
}


##########################################################

=head2 update

    update()

update objects config

=cut
sub update {
    my ( $self ) = @_;

    $self->{'needs_commit'} = 0;
    $self->{'needs_update'} = 0;
    $self->{'last_changed'} = 0;

    $self->_reset_errors();
    $self->_set_config();
    $self->_set_files();
    $self->_read_objects();
    return 1;
}


##########################################################

=head2 check_files_changed

    check_files_changed([ $reload ])

update objects config

=cut
sub check_files_changed {
    my $self   = shift;
    my $reload = shift || 0;

    my $errors1 = scalar @{$self->{'errors'}};

    $self->{'needs_update'} = 0;
    $self->{'last_changed'} = 0 if $reload;

    if($self->{'_corefile'} && $self->{'_corefile'}->{'path'} && $self->_check_file_changed($self->{'_corefile'})) {
        # maybe core type has changed
        $self->_set_coretype();
    }

    # since we reuse existing files, we need to remove changed files here
    $self->_set_files(1) if $reload;

    $self->_check_files_changed($reload);
    my $errors2 = scalar @{$self->{'errors'}};

    if($errors2 > $errors1) {
        $self->{'needs_update'} = 1;
    }
    if($reload or $self->{'needs_index_update'}) {
        $self->{'needs_update'} = 0;
        $self->update();
    }

    return 1;
}


##########################################################

=head2 update_object

    update_object($obj, $newdata, [ $comments, [ $rebuild ]])

update objects config

=cut
sub update_object {
    my $self    = shift;
    my $obj     = shift;
    my $data    = shift;
    my $comment = shift || '';
    my $rebuild = shift;
    $rebuild = 1 unless defined $rebuild;
    if(ref $comment eq 'ARRAY') { $comment = join("\n", @{$comment}); }

    return unless defined $obj;

    my $oldchanged = $obj->{'file'}->{'changed'};
    my $oldcommit  = $self->{'needs_commit'};

    my $oldname = $obj->get_name();

    my $file = $obj->{'file'};

    # invalidate all caches, because this object might have been used as template
    for my $file (@{$self->{'files'}}) {
        for my $o (@{$file->{'objects'}}) {
            $o->{'cache'} = {};
        }
    }

    # delete some references
    $self->delete_object($obj, 0);

    # update object
    $obj->{'conf'}     = $data;
    $obj->{'comments'} = [ split/\n/mx, $comment ];

    # unify comments
    for my $com (@{$obj->{'comments'}}) {
        $com =~ s/^\s+//gmx
    }

    return 0 unless(defined $file and $file->{'path'});

    push @{$file->{'objects'}}, $obj;

    my $newname = $obj->get_name();

    if(defined $oldname and defined $newname and $oldname ne $newname) {
        $self->rename_dependencies($obj, $oldname, $newname);
    }

    # restore old status if file hasn't changed
    if($file->diff() eq '') {
        $obj->{'file'}->{'changed'} = $oldchanged;
        $self->{'needs_commit'}     = $oldcommit;
    } else {
        $file->{'changed'}      = 1;
        $self->{'needs_commit'} = 1;
    }

    $self->_rebuild_index() if $rebuild;

    return 1;
}


##########################################################

=head2 delete_object

    delete_object($obj, [ $rebuild ])

update objects config

=cut
sub delete_object {
    my $self    = shift;
    my $obj     = shift;
    my $rebuild = shift;
    $rebuild    = 1 unless defined $rebuild;

    my $file                = $obj->{'file'};
    $file->{'changed'}      = 1;
    $self->{'needs_commit'} = 1;

    # remove object from file
    my @new_objects;
    for my $o (@{$file->{'objects'}}) {
        next if $o eq $obj;
        push @new_objects, $o;
    }
    $file->{'objects'} = \@new_objects;

    $self->_rebuild_index() if $rebuild;

    return 1;
}


##########################################################

=head2 move_object

    move_object($obj, $newfile, [ $rebuild ])

move object to different file

=cut
sub move_object {
    my($self, $obj, $newfile, $rebuild) = @_;
    $rebuild    = 1 unless defined $rebuild;

    return unless defined $newfile;
    return unless defined $obj;

    my $file                = $obj->{'file'};
    $file->{'changed'}      = 1;
    $newfile->{'changed'}   = 1;
    $self->{'needs_commit'} = 1;

    $self->delete_object($obj, 1);

    $obj->{'line'} = 0; # put new object at the end
    $obj->set_file($newfile);
    push @{$newfile->{'objects'}}, $obj;

    $self->_rebuild_index() if $rebuild;

    return 1;
}


##########################################################

=head2 file_add

    file_add($file, [ $rebuild ])

add new file to config

=cut
sub file_add {
    my($self, $file, $rebuild) = @_;
    $rebuild = 1 unless defined $rebuild;
    push @{$self->{'files'}}, $file;
    $self->{'files_index'}->{$file->{display}} = $file;
    $self->{'files_index'}->{$file->{path}}    = $file;
    $self->_rebuild_index() if $rebuild;
    return;
}


##########################################################

=head2 file_delete

    file_delete($file, [ $rebuild ])

remove a file from the config

=cut
sub file_delete {
    my($self, $file, $rebuild) = @_;
    $rebuild                = 1 unless defined $rebuild;
    $file->{'deleted'}      = 1;
    $file->{'changed'}      = 1;
    $self->{'needs_commit'} = 1;

    $self->_rebuild_index() if $rebuild;
    return;
}


##########################################################

=head2 file_undelete

    file_undelete($file, [ $rebuild ])

undelete a file marked for removal

=cut
sub file_undelete {
    my $self    = shift;
    my $file    = shift;
    my $rebuild = shift;

    $rebuild                = 1 unless defined $rebuild;
    $file->{'deleted'}      = 0;
    $file->{'changed'}      = 1;
    $self->{'needs_commit'} = 1;

    $self->_rebuild_index() if $rebuild;
    return;
}

##########################################################

=head2 rebuild_index

    rebuild_index()

rebuild object index

=cut
sub rebuild_index {
    my($self) = @_;
    return $self->_rebuild_index();
}

##########################################################

=head2 rename_dependencies

    rename_dependencies($obj, $oldname, $newname)

rename dependencies

=cut
sub rename_dependencies {
    my($self, $object, $old, $new) = @_;
    my $refs = $self->get_references($object, $old);

    # replace references in other objects
    for my $t (keys %{$refs}) {
        for my $oid (keys %{$refs->{$t}}) {
            my $obj = $self->get_object_by_id($oid);
            if($obj->{'file'}->{'readonly'}) {
                push @{$self->{'errors'}}, "could not update dependency in read-only file: ".$obj->{'file'}->{'display'};
                next;
            }
            for my $key (keys %{$refs->{$t}->{$oid}}) {
                if($obj->{'default'}->{$key}->{'type'} eq 'STRING') {
                    my $m2 = "$obj->{'conf'}->{$key}";
                    my $pre = substr($m2, 0, 1);
                    if($pre eq '!' or $pre eq '+') { $m2 = substr($m2, 1); } else { $pre = ''; }
                    $obj->{'conf'}->{$key} = $pre.$new;
                }
                elsif($obj->{'default'}->{$key}->{'type'} eq 'LIST') {
                    my $x = 0;
                    for my $m (@{$obj->{'conf'}->{$key}}) {
                        my $m2 = "$m";
                        $x++;
                        my $pre = substr($m2, 0, 1);
                        if($pre eq '!' or $pre eq '+') { $m2 = substr($m2, 1); } else { $pre = ''; }
                        next unless $m2 eq $old;
                        $obj->{'conf'}->{$key}->[$x-1] = $pre.$new;
                    }
                }
                elsif($obj->{'default'}->{$key}->{'type'} eq 'COMMAND') {
                    my($cmd,$arg) = split(/!/mx, $obj->{'conf'}->{$key}, 2);
                    if(!defined $arg || $arg eq '') {
                        $obj->{'conf'}->{$key} = $new;
                    } else {
                        $obj->{'conf'}->{$key} = $new.'!'.$arg;
                    }
                }
                else {
                    confess("replace for ".$obj->{'default'}->{$key}->{'type'}." not implemented");
                }
            }
            $obj->{'file'}->{'changed'} = 1;
        }
    }

    return;
}

##########################################################

=head2 clone_refs

    clone_refs($orig, $obj, $cloned_name, $newname, [$clone_refs],  [$test_mode])

clone all incoming references of object. In test mode nothing will be changed
and just the list of clonables will be returned.
If clone_refs is set, only those ids will be cloned.

=cut
sub clone_refs {
    my($self, $orig, $obj, $cloned_name, $new_name, $clone_refs, $test_mode) = @_;

    my $clone_refs_lookup = {};
    $clone_refs_lookup = Thruk::Utils::array2hash($clone_refs) if $clone_refs;

    my $clonables = {};
    # clone incoming references
    my $clonedtype = $obj->get_type();
    my($incoming, $outgoing) = $self->gather_references($orig);
    if($incoming) {
        for my $type (keys %{$incoming}) {
            for my $name (keys %{$incoming->{$type}}) {
                my $ref_id = $incoming->{$type}->{$name}->{'id'};
                my $ref    = $self->get_object_by_id($ref_id);
                if(!$test_mode && $ref->{'file'}->{'readonly'}) {
                    next;
                }
                for my $attr (keys %{$ref->{'conf'}}) {
                    if(defined $ref->{'default'}->{$attr} && $ref->{'default'}->{$attr}->{'link'} && $ref->{'default'}->{$attr}->{'link'} eq $clonedtype) {
                        if(ref $ref->{'conf'}->{$attr} eq 'ARRAY' && grep /^\Q$cloned_name\E$/mx, @{$ref->{'conf'}->{$attr}}) {
                            if($test_mode) {
                                $clonables->{$type}->{$ref_id} = {
                                    readonly => $ref->{'file'}->{'readonly'} ? 1 : 0,
                                    name     => $ref->get_name(),
                                    attr     => $attr,
                                };
                                next;
                            }
                            if($clone_refs && !$clone_refs_lookup->{$ref_id}) {
                                next;
                            }
                            push @{$ref->{'conf'}->{$attr}}, $new_name;
                            $self->update_object($ref, dclone($ref->{'conf'}), join("\n", @{$ref->{'comments'}}));
                        }
                    }
                }
            }
        }
    }
    return $clonables if $test_mode;
    return;
}

##########################################################

=head2 gather_references

    gather_references($obj)

return incoming and outgoing references

=cut
sub gather_references {
    my($self, $obj) = @_;

    # references from other objects
    my $refs = $self->get_references($obj);
    my $incoming = {};
    for my $type (keys %{$refs}) {
        $incoming->{$type} = {};
        for my $id (keys %{$refs->{$type}}) {
            my $obj = $self->get_object_by_id($id);
            $incoming->{$type}->{$obj->get_name()} = {
                id       => $id,
                readonly => $obj->{'file'}->readonly(),
            };
        }
    }

    # references from this to other objects
    my $outgoing = {};
    my $resolved = $obj->get_resolved_config($self);
    for my $attr (keys %{$resolved}) {
        my $refs = $resolved->{$attr};
        if(ref $refs eq '') { $refs = [$refs]; }
        if(defined $obj->{'default'}->{$attr} && $obj->{'default'}->{$attr}->{'link'}) {
            my $type = $obj->{'default'}->{$attr}->{'link'};
            my $count = 0;
            for my $r (@{$refs}) {
                my $r2 = "$r";
                if($type eq 'command') {
                    $r2 =~ s/\!.*$//mx;
                }
                if($count == 0) {
                    $r2 =~ s/^\+//gmx;
                    $r2 =~ s/^\!//gmx;
                }
                next if $r2 eq '';
                $outgoing->{$type}->{$r2} = '';
                $count++;
            }
        }
    }
    # add used templates
    if(defined $obj->{'conf'}->{'use'}) {
        for my $t (@{$obj->{'conf'}->{'use'}}) {
            $outgoing->{$obj->get_type()}->{$t} = '';
        }
    }
    return($incoming, $outgoing);
}

##########################################################

=head2 get_references

    get_references($obj, [ $name ])

return all references for this object

=cut
sub get_references {
    my($self, $obj, $name) = @_;
    $name = $obj->get_name() unless defined $name;
    $name = '' unless defined $name;

    my $type = $obj->get_type();
    my $list = {};

    # create list of types with that reference
    my $refs = {};
    for my $t (@{$Monitoring::Config::Object::Types}) {
        my $obj = Monitoring::Config::Object->new(type => $t, coretype => $self->{'coretype'});
        for my $key (keys %{$obj->{'default'}}) {
            next unless defined $obj->{'default'}->{$key}->{'link'};
            next unless $obj->{'default'}->{$key}->{'link'} eq $type;
            $refs->{$t}->{$key} = 0;
        }
    }

    # gather references in all objects
    for my $obj (@{$self->get_objects()}) {
        my $t = $obj->get_type();
        next unless defined $refs->{$t};
        for my $key (keys %{$refs->{$t}}) {
            next unless defined $obj->{'conf'}->{$key};
            if($obj->{'default'}->{$key}->{'type'} eq 'STRING') {
                next unless $obj->{'conf'}->{$key} eq $name;
                $list->{$t}->{$obj->get_id()}->{$key} = 1;
            }
            elsif($obj->{'default'}->{$key}->{'type'} eq 'LIST') {
                my $x = 0;
                for my $m (@{$obj->{'conf'}->{$key}}) {
                    my $m2  = "$m";
                    my $pre = substr($m2, 0, 1);
                    if($pre eq '!' or $pre eq '+') { $m2 = substr($m2, 1); }
                    next unless $m2 eq $name;
                    $list->{$t}->{$obj->get_id()}->{$key} = $x;
                    $x++;
                }
            }
            elsif($obj->{'default'}->{$key}->{'type'} eq 'COMMAND') {
                my($cmd,$arg) = split(/!/mx, $obj->{'conf'}->{$key}, 2);
                next if $cmd ne $name;
                $list->{$t}->{$obj->get_id()}->{$key} = 0;
            }
            else {
                confess("reference for ".$obj->{'default'}->{$key}->{'type'}." not implemented");
            }
        }
    }

    return $list;
}

##########################################################

=head2 get_default_keys

    get_default_keys($type, [ $options ])

 $options = {
     no_alias => 0,   # skip alias definitions and only return real config attributes
     sort     => 0,   # sort by default attribute order
 }

return the default config keys for a type of object

=cut
sub get_default_keys {
    my($self,$type, $options) = @_;
    $options = {} unless defined $options;
    $options->{'no_alias'} = 0 unless defined $options->{'no_alias'};
    my $obj = Monitoring::Config::Object->new(type     => $type,
                                              coretype => $self->{'coretype'});
    my @keys;
    for my $key (keys %{$obj->{'default'}}) {
        next if $options->{'no_alias'} == 1 and $obj->{'default'}->{$key}->{'type'} eq 'ALIAS';
        next if $obj->{'default'}->{$key}->{'type'} eq 'DEPRECATED';
        push @keys, $key;
    }

    if($obj->{'has_custom'}) {
        push @keys, 'customvariable';
    }

    if($options->{'sort'}) {
        @keys = @{Monitoring::Config::Object::Parent::get_sorted_keys(undef, \@keys)};
    }

    return \@keys;
}

##########################################################

=head2 get_files_for_folder

    get_files_for_folder($dir, [ $regex ])

return all files below this folder (matching the regex)

=cut
sub get_files_for_folder {
    my ( $self, $dir, $match ) = @_;
    return $self->_get_files_for_folder($dir, $match);
}


##########################################################

=head2 get_files_root

    get_files_root()

return root folder for config files

=cut
sub get_files_root {
    my ( $self ) = @_;

    return $self->{'cache'}->{'files_root'}  if $self->{'cache'}->{'files_root'};
    return $self->{'config'}->{'files_root'} if $self->{'config'}->{'files_root'};
    my $files = [];
    for my $file (@{$self->{'files'}}) {
        push @{$files}, $file->{'path'};
    }
    my $root = Thruk::Utils::Conf::get_root_folder($files);
    if($root ne '' and $self->is_remote()) {
        my $localdir = $self->{'config'}->{'localdir'};
        $root =~ s|^$localdir||mx;
    }

    # file root is empty when there are no files (yet)
    if($root eq '') {
        return $self->{'config'}->{'files_root'} if $self->{'config'}->{'files_root'};
        my $dirs = Thruk::Utils::list($self->{'config'}->{'obj_dir'});
        if(defined $dirs->[0]) {
            $root = $dirs->[0];
        }
    }
    $self->{'cache'}->{'files_root'} = $root;
    return $root;
}

##########################################################

=head2 is_host_in_hostgroup

    is_host_in_hostgroup()

return list of hostgroups if this host is member of the group

=cut
sub is_host_in_hostgroup {
    my($self, $group, $host_name, $hostgroups) = @_;

    my $group_name = $group->get_name();
    if(defined $hostgroups) {
        for my $hostgroup (@{$hostgroups}) {
            return([$group_name]) if $hostgroup eq $group_name;
        }
    }

    my($grp_conf_keys, $grp_config) = $group->get_computed_config($self);
    if(defined $grp_config->{'members'} and grep { $_ eq $host_name} @{$grp_config->{'members'}}) {
        return([$group_name]);
    }
    if(defined $grp_config->{'hostgroup_members'}) {
        for my $name (@{$grp_config->{'hostgroup_members'}}) {
            for my $subgroup (@{$self->get_objects_by_name('hostgroup', $name)}) {
                my $sg = $self->is_host_in_hostgroup($subgroup, $host_name, $hostgroups);
                return([@{$sg}, $group_name]) if $sg;
            }
        }
    }

    return;
}

##########################################################
# INTERNAL SUBS
##########################################################
sub _set_config {
    my($self)  = @_;

    if($self->{'config'}->{'core_conf'}) {
        $self->{'config'}->{'obj_file'}          = [];
        $self->{'config'}->{'obj_dir'}           = [];
        $self->{'config'}->{'obj_resource_file'} = [];

        my $core_conf = $self->{'config'}->{'core_conf'};
        if(defined $ENV{'OMD_ROOT'}
           && -d $ENV{'OMD_ROOT'}."/version/."
           && ! -s $core_conf
           && scalar(@{Thruk::Utils::list($self->{'config'}->{'obj_dir'})})  == 0
           && scalar(@{Thruk::Utils::list($self->{'config'}->{'obj_file'})}) == 0) {
            my $newest = $self->_newest_file(
                                             $ENV{'OMD_ROOT'}.'/tmp/naemon/naemon.cfg',
                                             $ENV{'OMD_ROOT'}.'/tmp/nagios/nagios.cfg',
                                             $ENV{'OMD_ROOT'}.'/tmp/icinga/icinga.cfg',
                                             $ENV{'OMD_ROOT'}.'/tmp/icinga/nagios.cfg',
                                             $ENV{'OMD_ROOT'}.'/tmp/shinken/shinken.cfg',
                                            );
            $core_conf = $newest if defined $newest;
        }

        if($core_conf =~ m|/omd/sites/(.*?)/etc/nagios/nagios.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/nagios/nagios.cfg';
        }
        elsif($core_conf =~ m|/omd/sites/(.*?)/etc/naemon/naemon.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/naemon/naemon.cfg';
        }
        elsif($core_conf =~ m|/omd/sites/(.*?)/etc/icinga/icinga.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/icinga/nagios.cfg' if -e '/omd/sites/'.$1.'/tmp/icinga/nagios.cfg';
            $core_conf = '/omd/sites/'.$1.'/tmp/icinga/icinga.cfg' if -e '/omd/sites/'.$1.'/tmp/icinga/icinga.cfg';
        }
        elsif($core_conf =~ m|/omd/sites/(.*?)/etc/shinken/shinken.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/shinken/shinken.cfg';
        }

        $self->_update_core_conf($core_conf);
    } else {
        $self->{'_corefile'} = undef;
    }

    $self->_set_coretype();

    return;
}


##########################################################
sub _update_core_conf {
    my $self      = shift;
    my $core_conf = shift;

    if(!defined $self->{'_coreconf'} || $self->{'_coreconf'} ne $core_conf) {
        if($core_conf) {
            $self->{'_corefile'} = Monitoring::Config::File->new($core_conf, $self->{'config'}->{'obj_readonly'}, $self->{'coretype'}, $self->{'relative'});
        } else {
            $self->{'_corefile'} = undef;
            return;
        }
    }
    $self->{'_coreconf'} = $core_conf;

    my $basedir = $core_conf;
    $basedir =~ s/\/[^\/]*?$//mx;

    open(my $fh, '<', $core_conf) or do {
        push @{$self->{'errors'}}, "cannot read $self->{'_coreconf'}: $!";
        $self->{'initialized'} = 0;
        return;
    };
    $self->{'_corefile'}->{'conf'} = {};
    while(my $line = <$fh>) {
        chomp($line);
        next if $line =~ m/^\s*\#/mx;
        my($key,$value) = split/\s*=\s*/mx, $line, 2;
        next unless defined $value;
        $key   =~ s/^\s*(.*?)\s*$/$1/mx;
        $value =~ s/^\s*(.*?)\s*$/$1/mx;

        if(defined $self->{'_corefile'}->{'conf'}->{$key}) {
            if(ref $self->{'_corefile'}->{'conf'}->{$key} eq '') {
                my $values = [ $self->{'_corefile'}->{'conf'}->{$key} ];
                $self->{'_corefile'}->{'conf'}->{$key} = $values;
            }
            push @{$self->{'_corefile'}->{'conf'}->{$key}}, $value;
        } else {
            $self->{'_corefile'}->{'conf'}->{$key} = $value;
        }

        if($key eq 'cfg_file') {
            push @{$self->{'config'}->{'obj_file'}}, $self->_resolve_relative_path($value, $basedir);
        }
        if($key eq 'cfg_dir') {
            push @{$self->{'config'}->{'obj_dir'}}, $self->_resolve_relative_path($value, $basedir);
        }
        if($key eq 'resource_file') {
            push @{$self->{'config'}->{'obj_resource_file'}}, $self->_resolve_relative_path($value, $basedir);
        }
    }
    CORE::close($fh) or die("cannot close file ".$self->{'path'}.": ".$!);

    return;
}


##########################################################
sub _set_coretype {
    my($self) = @_;

    # fixed value from config
    if(defined $self->{'config'}->{'core_type'} and $self->{'config'}->{'core_type'} ne 'auto') {
        $self->{'coretype'} = $self->{'config'}->{'core_type'};
        return;
    }

    # try to determine core type from main config
    if(defined $self->{'_corefile'} and defined $self->{'_corefile'}->{'conf'}->{'icinga_user'}) {
        $self->{'coretype'} = 'icinga';
        return;
    }

    if(defined $self->{'_corefile'}) {
        if($self->{'_corefile'}->{'conf'}->{'naemon_user'}) {
            $self->{'coretype'} = 'naemon';
            return;
        }
        if($self->{'_corefile'}->{'conf'}->{'command_file'} && $self->{'_corefile'}->{'conf'}->{'command_file'} =~ m|/naemon\.cmd|gmx) {
            $self->{'coretype'} = 'naemon';
            return;
        }
        if($self->{'_corefile'}->{'conf'}->{'query_socket'} && $self->{'_corefile'}->{'conf'}->{'query_socket'} =~ m|/naemon\.qh|gmx) {
            $self->{'coretype'} = 'naemon';
            return;
        }
    }

    # get core from init script link (omd)
    if(defined $ENV{'OMD_ROOT'}) {
        if(-e $ENV{'OMD_ROOT'}.'/etc/init.d/core') {
            $self->{'coretype'} = readlink($ENV{'OMD_ROOT'}.'/etc/init.d/core');
            return;
        }
    }

    if($self->{'coretype'} eq 'auto') {
        # fallback to naemon
        $self->{'coretype'} = 'naemon';
    }

    return;
}


##########################################################
sub _read_objects {
    my ( $self ) = @_;
    $self->_set_objects_from_files();
    $self->_rebuild_index();
    return;
}


##########################################################
sub _set_objects_from_files {
    my ( $self ) = @_;

    for my $file (@{$self->{'files'}}) {
        next if $file->{'deleted'} == 1;
        $file->update_objects();
    }

    return;
}


##########################################################
sub _get_files_for_folder {
    my ( $self, $dir, $match ) = @_;
    my @files;
    $dir =~ s/\/$//gmxo;

    my @tmpfiles;
    opendir(my $dh, $dir) or confess("cannot open directory $dir: $!");
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        push @tmpfiles, $file;
    }
    closedir $dh;

    for my $file (@tmpfiles) {
        # follow sub directories
        if(-d $dir."/".$file."/.") {
            push @files, @{$self->_get_files_for_folder($dir."/".$file, $match)};
        }

        # if its a file, make sure it matches our pattern
        if(defined $match) {
            my $test = $dir."/".$file;
            next unless $test =~ m/$match/mx;
        }

        my $localdir = $self->{'config'}->{'localdir'};
        if($localdir) {
            my $display = $dir.'/'.$file;
            $display    =~ s/^$localdir\///mx;
            my $d = $dir.'/'.$file;
            $d    =~ s|/+|/|gmx;
            $self->{'file_trans'}->{$d} = $display;
        }

        # skip broken symlinks
        my $path = $dir."/".$file;
        if(-l $path && !-e $path) {
            next;
        }

        push @files, $path;
    }

    return \@files;
}


##########################################################
sub _set_files {
    my($self, $discard_changes) = @_;
    my($files, $index)     = $self->_get_files($discard_changes);
    $self->{'files'}       = $files;
    $self->{'files_index'} = $index;
    return;
}


##########################################################
sub _get_files {
    my ($self, $discard_changes) = @_;

    my @files;
    my %index;
    my $filenames = $self->_get_files_names();
    for my $filename (@{$filenames}) {
        my $file = $self->get_file_by_path($filename);
        if($discard_changes && $file->{'changed'}) {
            undef $file;
        }
        # reuse existing file, otherwise merge would not work
        if(!$file) {
            my $force = 0;
            $force    = 1 if $self->{'config'}->{'force'} or $self->{'config'}->{'relative'};
            $file = Monitoring::Config::File->new($filename, $self->{'config'}->{'obj_readonly'}, $self->{'coretype'}, $force, $self->{'file_trans'}->{$filename});
        }
        if(defined $file) {
            push @files, $file;
            $index{$file->{'display'}} = $file;
        } else {
            warn('got no valid file for: '.$filename);
        }
    }

    return(\@files, \%index);
}


##########################################################
sub _get_files_names {
    my ( $self ) = @_;
    my $files    = {};
    my $config   = $self->{'config'};
    $self->{'file_trans'} = {};

    # single folders
    if(defined $config->{'obj_dir'}) {
        for my $dir ( ref $config->{'obj_dir'} eq 'ARRAY' ? @{$config->{'obj_dir'}} : ($config->{'obj_dir'}) ) {
            my $path = $dir;
            $path = $self->{'config'}->{'localdir'}.'/'.$dir if $self->{'config'}->{'localdir'};
            for my $file (@{$self->_get_files_for_folder($path, '\.cfg$')}) {
                Thruk::Utils::decode_any($file);
                $file =~ s|/+|/|gmx;
                $files->{$file} = 1;
            }
        }
    }

    # exclude some files?
    # exclude happens before obj_file to make it possible to
    # specify files even if they match an exclude
    if(defined $config->{'obj_exclude'}) {
        for my $ex ( ref $config->{'obj_exclude'} eq 'ARRAY' ? @{$config->{'obj_exclude'}} : ($config->{'obj_exclude'}) ) {
            for my $file (keys %{$files}) {
                if($file =~ m/$ex/gmx) {
                    delete $files->{$file};
                }
            }
        }
    }

    # single files
    if(defined $config->{'obj_file'}) {
        for my $file ( ref $config->{'obj_file'} eq 'ARRAY' ? @{$config->{'obj_file'}} : ($config->{'obj_file'}) ) {
            Thruk::Utils::decode_any($file);
            if($self->{'config'}->{'localdir'}) {
                my $display = $file;
                $file       = $self->{'config'}->{'localdir'}.'/'.$file;
                $file =~ s|/+|/|gmx;
                $self->{'file_trans'}->{$file} = $display;
            }
            $files->{$file} = 1;
        }
    }

    if(!defined $config->{'obj_dir'} && !defined $config->{'obj_file'}) {
        push @{$self->{'parse_errors'}}, "you need to configure paths (obj_dir, obj_file)";
    }

    my $cleanfiles = {};
    for my $f (keys %{$files}) {
        $f =~ s|/+|/|gmx;
        $cleanfiles->{$f} = 1;
    }

    my @uniqfiles = keys %{$cleanfiles};
    return \@uniqfiles;
}


##########################################################
sub _check_files_changed {
    my $self   = shift;
    my $reload = shift || 0;

    my $oldfiles = {};
    my @newfiles;
    for my $file ( @{$self->{'files'}} ) {
        # don' report newly added files as deleted
        if($file->{'is_new_file'}) {
            push @newfiles, $file;
            next;
        }

        $oldfiles->{$file->{'path'}} = 1;
        my $check = $self->_check_file_changed($file);

        if($check == 1) {
            if(!$reload || $file->{'changed'}) {
                push @newfiles, $file;
                push @{$self->{'errors'}}, "file ".$file->{'display'}." has been deleted.";
                $self->{'needs_index_update'} = 1;
                next;
            }
        }
        elsif($check == 2) {
            if($reload || !$file->{'changed'}) {
                $file->{'parsed'} = 0;
                $file->update_objects();
                $file->_update_meta_data();
                $self->{'needs_index_update'} = 1;
            } else {
                if($file->try_merge()) {
                    $self->{'needs_commit'}       = 1;
                    $self->{'obj_model_changed'}  = 1;
                    $self->{'needs_index_update'} = 1;
                } else {
                    push @{$self->{'errors'}}, "Conflict in file ".$file->{'display'}.". File has been changed on disk and via config tool.";
                    push @{$self->{'errors'}}, @{$file->{'errors'}} if $file->{'errors'};
                }
            }
        }

        # changed or new files still exist
        if($check == 0 or $check == 2) {
            push @newfiles, $file;
        }
    }
    $self->{'files'} = \@newfiles;

    for my $file (@{$self->_get_files_names()}) {
        if(!defined $oldfiles->{$file}) {
            push @{$self->{'files'}}, Monitoring::Config::File->new($file, $self->{'config'}->{'obj_readonly'}, $self->{'coretype'}, undef, $self->{'file_trans'}->{$file});
            $self->{'needs_index_update'} = 1;
        }
    }

    return;
}


##########################################################
# check if file has changed
# returns:
#   0 if file did not change
#   1 if file is new / created
#   2 if hexdigest sum changed
sub _check_file_changed {
    my($self, $file) = @_;

    confess("no file given") unless($file && $file->{'path'});

    # mtime & inode
    my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
       $atime,$mtime,$ctime,$blksize,$blocks)
       = stat($file->{'path'});

    if(!defined $ino || !defined $file->{'inode'}) {
        return 1;
    }
    else {
        # inode or mtime changed?
        if($file->{'inode'} ne $ino or $file->{'mtime'} ne $mtime) {
            $file->{'inode'} = $ino;
            $file->{'mtime'} = $mtime;
            # get hexdigest
            my $meta = $file->get_meta_data();
            if($meta->{'hex'} ne $file->{'hex'}) {
                return 2;
            }
        }
    }
    return 0;
}


##########################################################
# collect errors from all files
sub _collect_errors {
    my ( $self ) = @_;
    $self->{'parse_errors'} = [];
    for my $file ( @{$self->{'files'}} ) {
        push @{$self->{'errors'}},       @{$file->{'errors'}};
        push @{$self->{'parse_errors'}}, @{$file->{'parse_errors'}};
    }
    return scalar @{$self->{'errors'}} + scalar @{$self->{'parse_errors'}};
}


##########################################################
sub _rebuild_index {
    my ( $self ) = @_;

    $self->{'stats'}->profile(begin => "M::C::_rebuild_index()") if defined $self->{'stats'};

    my $objects_without_primary = [];
    my $macros = {
        'host'    => {},
        'service' => {},
    };
    $self->{'cache'} = {};

    # collect errors from all files
    $self->_collect_errors();

    # sort objects into hash
    my $objects = {};
    for my $file ( @{$self->{'files'}} ) {
        for my $obj ( @{$file->{'objects'}} ) {
            my $found = $self->_update_obj_in_index($objects, $obj);
            push @{$objects_without_primary}, $obj if $found == 0;
        }
        for my $type (qw/host service/) {
            for my $macro (keys %{$file->{'macros'}->{$type}}) {
                $macros->{$type}->{$macro} = 1;
            }
        }
        $self->{'files_index'}->{$file->{'display'}} = $file;
        $self->{'files_index'}->{$file->{'path'}}    = $file;
    }

    if(scalar @{$objects_without_primary} > 0) {
        for my $obj (@{$objects_without_primary}) {
            my $conf = $obj->get_resolved_config($objects);
            my $tmp_obj = Monitoring::Config::Object->new(type => $obj->get_type(), conf => $conf, coretype => $self->{'coretype'});
            my $primary = $tmp_obj->get_primary_name();
            if(defined $primary) {
                my $found = $self->_update_obj_in_index($objects, $obj, $primary, $conf);
                if($found == 0) {
                    $objects->{'byname'}->{$obj->{'type'}}->{$primary} = $obj->{'id'};
                }
            } else {
                if($obj->must_have_name()) {
                    push @{$self->{'parse_errors'}}, $obj->get_type()." object has no name in ".Thruk::Utils::Conf::link_obj($obj);
                }
            }
        }
    }

    $self->{'objects'}            = $objects;
    $self->{'macros'}             = $macros;
    $self->{'needs_index_update'} = 0;

    my $parse_errors = $self->_check_references();
    push @{$self->{'parse_errors'}}, @{$parse_errors} if scalar @{$parse_errors} > 0;

    $self->{'stats'}->profile(end => "M::C::_rebuild_index()") if defined $self->{'stats'};
    return;
}


##########################################################
sub _update_obj_in_index {
    my($self, $objects, $obj, $primary, $tmpconf) = @_;

    my $pname  = $obj->get_primary_name(1, $tmpconf);
    my $tname  = $obj->get_template_name();
    my $found  = 0;

    # set uniq id
    $obj->set_uniq_id($objects);

    # by id
    $objects->{'byid'}->{$obj->{'id'}} = $obj;

    return 1 if $obj->{'disabled'};

    # by template name
    if(defined $tname) {
        my $existing_id = $objects->{'byname'}->{'templates'}->{$obj->{'type'}}->{$tname};
        if(defined $existing_id and $existing_id eq $obj->{'id'}) {
            my $orig = $self->get_object_by_id($existing_id);
            if(defined $orig) {
                push @{$self->{'parse_errors'}}, "duplicate ".$obj->{'type'}." template definition $tname in ".Thruk::Utils::Conf::link_obj($obj)."\n  -> already defined in ".Thruk::Utils::Conf::link_obj($orig);
            } else {
                push @{$self->{'parse_errors'}}, "duplicate ".$obj->{'type'}." template definition $tname in ".Thruk::Utils::Conf::link_obj($obj);
            }
        }
        $objects->{'byname'}->{'templates'}->{$obj->{'type'}}->{$tname} = $obj->{'id'};
        $found++;
    }

    # by name
    if(defined $pname and ref $pname eq 'ARRAY') {
        # multiple primarys
        if(ref $pname->[1] eq '') {
            for my $primary (@{$pname}) {
                $objects->{'byname'}->{$obj->{'type'}}->{$primary} = $obj->{'id'};
                $found++;
            }
        }

        # secondary keys
        else {
            $pname->[0] = $primary if defined $primary;
            if(defined $pname->[0]) {
                for my $secondary (@{$pname->[1]}) {
                    my $type  = $secondary->[0];
                    my $value = $secondary->[1];
                    for my $v (ref $value eq 'ARRAY' ? @{$value} : [ $value ]) {
                        $objects->{'byname'}->{$obj->{'type'}}->{$pname->[0]}->{$type}->{$v} = $obj->{'id'};
                        $found++;
                    }
                }
            }
        }
    }
    elsif(defined $pname or defined $primary) {
        # single primary key
        $pname = $primary if defined $primary;
        my $existing_id = $objects->{'byname'}->{$obj->{'type'}}->{$pname};
        if(defined $existing_id and $existing_id ne $obj->{'id'}) {
            my $orig = $self->get_object_by_id($existing_id);
            if(!defined $orig) {
                push @{$self->{'parse_errors'}},
                    "duplicate ".$obj->{'type'}." definition $pname in ".Thruk::Utils::Conf::link_obj($obj);
            } else {
                push @{$self->{'parse_errors'}},
                    "duplicate ".$obj->{'type'}." definition $pname in ".Thruk::Utils::Conf::link_obj($obj)."\n  -> already defined in ".Thruk::Utils::Conf::link_obj($orig);
            }
        }
        $objects->{'byname'}->{$obj->{'type'}}->{$pname} = $obj->{'id'};
        $found++;
    }

    if($found || defined $primary) {
        # by type
        if(!defined $obj->{'conf'}->{'register'} || $obj->{'conf'}->{'register'} != 0) {
            push @{$objects->{'bytype'}->{$obj->{'type'}}}, $obj->{'id'};
        }
    }

    return $found;
}


##########################################################
sub _reset_errors {
    my($self, $no_parse) = @_;
    $self->{'errors'}       = [];
    $self->{'parse_errors'} = [] unless $no_parse;
    return;
}


##########################################################
sub _newest_file {
    my($self, @files) = @_;
    my %filelist;
    for my $file (@files) {
        my @stat = stat($file);
        if(defined $stat[9]) {
            $filelist{$stat[9]} = $file;
        }
    }
    my @sorted = sort {$a <=> $b} keys %filelist;
    my $newest = shift @sorted;
    return $filelist{$newest} if defined $newest;
    return;
}


##########################################################
sub _check_references {
    my($self, %options) = @_;

    $self->{'stats'}->profile(begin => "M::C::_check_references()") if defined $self->{'stats'};
    my $templates_by_name = $self->{'objects'}->{'byname'}->{'templates'};
    my $objects_by_name   = $self->{'objects'}->{'byname'};
    my @parse_errors;
    $self->_all_object_links_callback(sub {
        my($file, $obj, $attr, $link, $val) = @_;
        return if $obj->{'disabled'};
        if($attr eq 'use') {
            if(!defined $templates_by_name->{$link}->{$val}) {
                if($options{'hash'}) {
                    push @parse_errors, { ident     => $obj->get_id().'/'.$attr.';'.$val,
                                          id        => $obj->get_id(),
                                          type      => $obj->get_type(),
                                          name      => $obj->get_name(),
                                          obj       => $obj,
                                          message   => "referenced template '$val' does not exist",
                                          cleanable => 0,
                                        };
                } else {
                    push @parse_errors, "referenced template '$val' does not exist in ".Thruk::Utils::Conf::link_obj($obj);
                }
            }
        }
        else {
            # 'null' is a special value used to cancel inheritance
            return if $val eq 'null';

            # hostgroups are allowed to have a register 0
            return if ($link eq 'hostgroup' and defined $templates_by_name->{$link}->{$val});
            # host are allowed to have a register 0
            return if ($link eq 'host' and defined $templates_by_name->{$link}->{$val});

            # shinken defines this command by itself
            return if ($self->{'coretype'} eq 'shinken' and $val eq 'bp_rule');
            return if ($self->{'coretype'} eq 'shinken' and $link eq 'command' and $val eq '_internal_host_up');

            if($link eq 'service_description') { $link = 'service'; }

            if(defined $objects_by_name->{$link}->{$val}) {
                return;
            } elsif(Thruk::Utils::looks_like_regex($val)) {
                # expand wildcards and regex
                my $newval = Thruk::Utils::convert_wildcards_to_regex($val);
                for my $tst (keys %{$objects_by_name->{$link}}) {
                    ## no critic
                    return if $tst =~ m/$newval/;
                    ## use critic
                }
            }

            if($options{'hash'}) {
                push @parse_errors, { ident     => $obj->get_id().'/'.$attr.';'.$val,
                                      id        => $obj->get_id(),
                                      type      => $obj->get_type(),
                                      name      => $obj->get_name(),
                                      obj       => $obj,
                                      message   => 'referenced '.$link." '".$val."' does not exist",
                                      cleanable => 0,
                                    };
            } else {
                push @parse_errors, 'referenced '.$link." '".$val."' does not exist in ".Thruk::Utils::Conf::link_obj($obj);
            }
        }
    });

    $self->{'stats'}->profile(end => "M::C::_check_references()") if defined $self->{'stats'};
    return \@parse_errors;
}


##########################################################
sub _check_orphaned_objects {
    my($self) = @_;
    $self->{'stats'}->profile(begin => "M::C::_check_orphaned_objects()") if defined $self->{'stats'};
    my @errors;

    # build list of objects
    my $all_templates = {};
    my $all_objects   = {};
    for my $type (keys %{$self->{'objects'}->{'byname'}}) {
        next if $type eq 'templates';
        my @values = keys %{$self->{'objects'}->{'byname'}->{$type}};
        for my $v (@values) { $all_objects->{$type}->{$v} = 1; }
    }
    for my $type (keys %{$self->{'objects'}->{'byname'}->{'templates'}}) {
        my @values = keys %{$self->{'objects'}->{'byname'}->{'templates'}->{$type}};
        for my $v (@values) { $all_templates->{$type}->{$v} = 1; }
    }

    $self->_all_object_links_callback(sub {
        my($file, $obj, $attr, $link, $val) = @_;
        if($attr eq 'use') {
            delete $all_templates->{$link}->{$val};
        }
        else {
            delete $all_templates->{$link}->{$val} if $link eq 'hostgroup';
            delete $all_objects->{$link}->{$val};
        }
    });
    for my $type (keys %{$all_templates}) {
        for my $name (keys %{$all_templates->{$type}}) {
            my $obj = $self->get_object_by_id($self->{'objects'}->{'byname'}->{'templates'}->{$type}->{$name});
            push @errors, { ident     => $obj->get_id(),
                            id        => $obj->get_id(),
                            type      => $type,
                            name      => $obj->get_name(),
                            obj       => $obj,
                            message   => "this ".$type." template is not used anywhere",
                            cleanable => 1,
                        };
        }
    }
    for my $type (keys %{$all_objects}) {
        next if $type eq 'service';
        next if $type eq 'servicedependency';
        for my $name (keys %{$all_objects->{$type}}) {
            my $obj = $self->get_object_by_id($self->{'objects'}->{'byname'}->{$type}->{$name});
            next if !defined $obj;
            next if defined $obj->{'conf'}->{'members'};
            next if $type eq 'host';
            push @errors, { ident     => $obj->get_id(),
                            id        => $obj->get_id(),
                            type      => $obj->get_type(),
                            name      => $obj->get_name(),
                            obj       => $obj,
                            message   => "this ".$type." is not used anywhere",
                            cleanable => 1,
                        };
        }
    }

    $self->{'stats'}->profile(end => "M::C::_check_orphaned_objects()") if defined $self->{'stats'};
    return \@errors;
}


##########################################################
# run callback function for every link
#
# ex.: _all_object_links_callback(sub {
#          my($file, $obj, $attr, $link, $val, $args) = @_;
#          $file  = reference to file object
#          $obj   = reference to object itself
#          $attr  = attribute name of link, ex.: use, members, ...
#          $link  = link type, ex.: host, hostgroup, ...
#          $val   = value name, ex.: hostgroup_abc, generic-host, ...
#          $args  = optional arguments of commands
#      })
#
sub _all_object_links_callback {
    my($self, $cb) = @_;

    for my $file ( @{$self->{'files'}} ) {
        for my $obj ( @{$file->{'objects'}} ) {
            for my $key (keys %{$obj->{'conf'}}) {
                next unless defined $obj->{'default'}->{$key};
                next unless defined $obj->{'default'}->{$key}->{'link'};
                my $link = $obj->{'default'}->{$key}->{'link'};
                next if $link eq 'servicemember';
                next if $link eq 'icon';
                if($key eq 'use') {
                    for my $ref (@{$obj->{'conf'}->{$key}}) {
                        my $ref2 = "$ref";
                        if(substr($ref2, 0, 1) eq '!' or substr($ref2, 0, 1) eq '+') { $ref2 = substr($ref2, 1); }
                        next if index($ref2, '*') != -1;
                        next if $ref2 eq '';
                        &{$cb}($file, $obj, $key, $link, $ref2);
                    }
                }
                elsif($obj->{'default'}->{$key}->{'type'} eq 'STRING') {
                    &{$cb}($file, $obj, $key, $link, $obj->{'conf'}->{$key});
                }
                elsif($obj->{'default'}->{$key}->{'type'} eq 'LIST') {
                    for my $ref (@{$obj->{'conf'}->{$key}}) {
                        my $ref2 = "$ref";
                        if(substr($ref2, 0, 1) eq '!' or substr($ref2, 0, 1) eq '+') { $ref2 = substr($ref2, 1); }
                        next if index($ref2, '*') != -1;
                        next if $ref2 eq '';
                        my $args;
                        # list of commands, like eventhandlers
                        if($obj->{'default'}->{$key}->{'link'} eq 'command') {
                            ($ref2,$args) = split(/!/mx, $ref2, 2);
                        }
                        &{$cb}($file, $obj, $key, $link, $ref2, $args);
                    }
                }
                elsif($obj->{'default'}->{$key}->{'type'} eq 'COMMAND') {
                    my($cmd,$args) = split(/!/mx, $obj->{'conf'}->{$key}, 2);
                    &{$cb}($file, $obj, $key, $link, $cmd, $args);
                }
            }
        }
    }
    return;
}


##########################################################
sub _resolve_relative_path {
    my ($self, $file, $basedir) = @_;
    if($file !~ m|^/|mx) {
        $file = $basedir.'/'.$file;
        $file =~ s|//|/|gmx;
        my $x = 0;
        while( $x < 10 && $file =~ s|/[^/]+/\.\./|/|gmx) { $x++ }
    }
    return $file;
}


##########################################################
sub _array_diff {
    my($self, $list1, $list2) = @_;
    return 0 if(!defined $list1 && !defined $list2);
    return 1 if !defined $list1;
    return 1 if !defined $list2;

    my $nr1 = scalar @{$list1} - 1;
    my $nr2 = scalar @{$list2} - 1;
    return 1 if $nr1 != $nr2;

    for my $x (0..$nr1) {
        next if(!defined $list1->[$x] && !defined $list2->[$x]);
        return 1 if !defined $list1->[$x];
        return 1 if !defined $list2->[$x];
        return 1 if $list1->[$x] ne $list2->[$x];
    }

    return 0;
}

##########################################################
# convert anything to a list
sub _list {
    $_[1] = [] unless defined $_[1];
    if(ref $_[1] ne 'ARRAY') { $_[1] = [$_[1]]; }
    return $_[1];
}

##########################################################
# do something on remote site
sub _remote_do {
    my($self, $c, $sub, $args) = @_;
    my $res;
    eval {
        $res = $self->{'remotepeer'}
                    ->{'class'}
                    ->request('configtool', {
                        sub      => $sub,
                        args     => $args,
                    }, {
                        auth     => $c->stash->{'remote_user'},
                        keep_su  => 1,
                    });
    };
    if($@) {
        warn($@) if Thruk->mode eq 'TEST';
        my $msg = $@;
        _error($@);
        $msg    =~ s|\s+(at\s+.*?\s+line\s+\d+)||mx;
        my @text = split(/\n/mx, $msg);
        Thruk::Utils::set_message( $c, 'fail_message', $sub." failed: ".$text[0] );
        return;
    }
    die("bogus result: ".Dumper($res)) if(!defined $res || ref $res ne 'ARRAY' || !defined $res->[2]);
    return $res->[2];
}

##########################################################
# do something on remote site in background
sub _remote_do_bg {
    my($self, $c, $sub, $args) = @_;
    my $res = $self->{'remotepeer'}
                   ->{'class'}
                   ->request('configtool', {
                        sub      => $sub,
                        args     => $args,
                   }, {
                        auth     => $c->stash->{'remote_user'},
                        keep_su  => 1,
                        wait     => 1,
                   });
    die("bogus result: ".Dumper($res)) if(!defined $res || ref $res ne 'ARRAY' || !defined $res->[2]);
    return $res->[2];
}

##########################################################

=head2 is_remote

    is_remote()

return true if this backend has a remote connection

=cut
sub is_remote {
    my($self) = @_;
    return 1 if defined $self->{'remotepeer'};
    return 0;
}

##########################################################

=head2 remote_file_sync

    remote_file_sync()

syncronize files from remote

=cut
sub remote_file_sync {
    my($self, $c) = @_;
    return unless $self->is_remote();
    $c->stats->profile(begin => "remote_file_sync");
    my $files = {};
    for my $f (@{$self->{'files'}}) {
        next unless -f $f->{'path'};
        $files->{$f->{'display'}} = {
            'mtime'        => $f->{'mtime'},
            'hex'          => $f->{'hex'},
        };
    }
    my $remotefiles = $self->_remote_do($c, 'syncfiles', { files => $files });
    if(!$remotefiles) {
        return $c->detach_error({msg => "syncing remote configuration files failed", code => 500, log => 1});
    }

    my $localdir = $c->config->{'tmp_path'}."/localconfcache/".$self->{'remotepeer'}->{'key'};
    $self->{'config'}->{'localdir'} = $localdir;
    $self->{'config'}->{'obj_dir'}  = '/';
    Thruk::Utils::IO::mkdir_r($localdir);
    for my $path (keys %{$remotefiles}) {
        my $f = $remotefiles->{$path};
        if(defined $f->{'content'}) {
            my $localpath = $localdir.'/'.$path;
            _debug('updating file: '.$path);
            my $dir       = $localpath;
            $dir          =~ s/\/[^\/]+$//mx;
            Thruk::Utils::IO::mkdir_r($dir);
            Thruk::Utils::IO::write($localpath, $f->{'content'}, $f->{'mtime'});
            $c->req->parameters->{'refreshdata'} = 1; # must be set to save changes to tmp obj retention
        }
    }
    for my $f (@{$self->{'files'}}) {
        _debug('checking file: '.$f->{'display'});
        if(!defined $remotefiles->{$f->{'display'}}) {
            _debug('deleting file: '.$f->{'display'});
            $c->req->parameters->{'refreshdata'} = 1; # must be set to save changes to tmp obj retention
            unlink($f->{'path'});
        } else {
            _debug('keeping file: '.$f->{'display'});
        }
    }

    # if there are no files (yet), we need the files root
    if(scalar @{$self->{'files'}} == 0) {
        my $settings = $self->_remote_do($c, 'configsettings');
        return unless $settings;
        Thruk::Utils::IO::mkdir_r($self->{'config'}->{'localdir'}.'/'.$settings->{'files_root'});
        $self->{'config'}->{'files_root'} = $settings->{'files_root'}.'/';
        $self->{'config'}->{'files_root'} =~ s|/+|/|gmx;
    }

    $c->stats->profile(end => "remote_file_sync");
    return;
}

##########################################################

=head2 remote_config_check

    remote_config_check()

do config check on remote site

=cut
sub remote_config_check {
    my($self, $c) = @_;
    return unless $self->is_remote();
    my($rc, $output) = @{$self->_remote_do_bg($c, 'configcheck')};
    $c->stash->{'output'} = $output;
    return !$rc;
}

##########################################################

=head2 remote_config_reload

    remote_config_reload()

do a config reload on remote site

=cut
sub remote_config_reload {
    my($self, $c) = @_;
    return unless $self->is_remote();
    my($rc, $output) = @{$self->_remote_do_bg($c, 'configreload')};
    $c->stash->{'output'} = $output;
    return !$rc;
}

##########################################################

=head2 remote_file_save

    remote_file_save()

save files to remote site

=cut
sub remote_file_save {
    my($self, $c, $files) = @_;
    return unless $self->is_remote();
    my $res = $self->_remote_do($c, 'configsave', $files);
    return;
}

##########################################################

=head2 remote_get_plugins

    remote_get_plugins()

return plugins from remote site

=cut
sub remote_get_plugins {
    my($self, $c) = @_;
    return unless $self->is_remote();
    return $self->_remote_do($c, 'configplugins');
}

##########################################################

=head2 remote_get_pluginhelp

    remote_get_pluginhelp()

return plugin help from remote site

=cut
sub remote_get_pluginhelp {
    my($self, $c, $name) = @_;
    return unless $self->is_remote();
    return $self->_remote_do($c, 'configpluginhelp', $name);
}

##########################################################

=head2 remote_get_pluginpreview

    remote_get_pluginpreview()

return plugin preview from remote site

=cut
sub remote_get_pluginpreview {
    my($self, $c,$command,$args,$host,$service) = @_;
    return unless $self->is_remote();
    return $self->_remote_do($c, 'configpluginpreview', [$command,$args,$host,$service]);
}

##########################################################

=head2 read_rc_file

    read_rc_file()

read naglint rc file and create sort function

=cut
sub read_rc_file {
    my($self, $file) = @_;
    my @rcfiles  = glob($file || '~/.naglintrc /etc/thruk/naglint.conf '.(defined $ENV{'OMD_ROOT'} ? $ENV{'OMD_ROOT'}.'/etc/thruk/naglint.conf' : ''));
    for my $f (@rcfiles) {
        if(defined $f && -r $f) {
            $file = $f;
            last;
        }
    }

    my $settings;
    if($file and -r $file) {
        $settings = Thruk::Config::read_config_file($file);
        for my $key (qw/object_attribute_key_order object_cust_var_order/) {
            next unless defined $settings->{$key};
            $settings->{$key} =~ s/^\s*\[\s*(.*?)\s*\]\s*$/$1/gmx;
            $settings->{$key} = [ split/\s+/mx, $settings->{$key} ];
        }
    }
    $self->set_save_config($settings);
    return;
}

##########################################################

=head2 set_save_config

updates file save config

=cut
sub set_save_config {
    my($self, $settings) = @_;

    my $cfg = $Monitoring::Config::save_options;
    $Monitoring::Config::key_sort = Monitoring::Config::Object::Parent::sort_by_object_keys($cfg->{object_attribute_key_order}, $cfg->{object_cust_var_order});
    _set_output_format($cfg);
    return $cfg unless defined $settings;

    for my $key (keys %{$settings}) {
        $cfg->{$key} = $settings->{$key} if defined $cfg->{$key};
    }

    $Monitoring::Config::key_sort = Monitoring::Config::Object::Parent::sort_by_object_keys($cfg->{object_attribute_key_order}, $cfg->{object_cust_var_order});
    _set_output_format($cfg);

    return $cfg;
}

##########################################################

=head2 get_plugins

return list of plugins

=cut
sub get_plugins {
    my($self, $c) = @_;

    if($self->is_remote()) {
        return $self->remote_get_plugins($c);
    }

    my $user_macros = Thruk::Utils::read_resource_file($self->{'config'}->{'obj_resource_file'});
    my $objects     = {};
    my $pathspec    = $Monitoring::Config::plugin_pathspec;
    for my $macro (keys %{$user_macros}) {
        my $dir = $user_macros->{$macro};
        $dir = $dir.'/.';
        next unless -d $dir;
        if($dir =~ m%$pathspec%mx) {
            $self->_set_plugins_for_directory($c, $dir, $macro, $objects);
        }
    }
    return $objects;
}

##########################################################
sub _set_plugins_for_directory {
    my($self, $c, $dir, $macro, $objects) = @_;
    my $files = $self->_get_files_for_folder($dir);
    for my $file (@{$files}) {
        next if $file =~ m/\/utils\.pm/mx;
        next if $file =~ m/\/utils\.sh/mx;
        next if $file =~ m/\/p1\.pl/mx;
        if(-x $file) {
            my $shortfile = $file;
            $shortfile =~ s/$dir/$macro/gmx;
            $objects->{$shortfile} = $file;
        }
    }
    return $objects;
}

##########################################################

=head2 get_plugin_help

return plugin help

=cut
sub get_plugin_help {
    my($self, $c, $name) = @_;
    my $help = 'help is only available for plugins!';
    return "got no command name" unless defined $name;

    if($self->is_remote()) {
        return $self->remote_get_pluginhelp($c, $name);
    }

    my $cmd;
    my $plugins         = $self->get_plugins($c);
    my $objects         = $self->get_objects_by_name('command', $name);
    if(!defined $objects->[0]) {
        return(sprintf("did not find a command with name: %s", $name));
    }
    my($file,$args) = split/\s+/mx, $objects->[0]->{'conf'}->{'command_line'}, 2;
    my $user_macros = Thruk::Utils::read_resource_file($self->{'config'}->{'obj_resource_file'});
    ($file)         = $c->{'db'}->_get_replaced_string($file, $user_macros);
    if(!-x $file) {
        return(sprintf("%s is not executable", $file));
    }
    my $pathspec = $Monitoring::Config::plugin_pathspec;
    if($file !~ m%$pathspec%mx) {
        return(sprintf("%s does not match path spec: %s", $file, $pathspec));
    }
    $cmd = $file;
    if(defined $plugins->{$name}) {
        $cmd = $plugins->{$name};
    }
    if(!defined $cmd) {
        return $help;
    }
    eval {
        local $SIG{ALRM} = sub { die('alarm'); };
        alarm(5);
        $cmd = $cmd." -h 2>/dev/null";
        $help = `$cmd`;
        alarm(0);
    };
    return $help;
}

##########################################################

=head2 get_plugin_preview

return plugin preview

=cut
sub get_plugin_preview {
    my($self,$c,$command,$args,$host,$service) = @_;

    if($self->is_remote()) {
        return $self->remote_get_pluginpreview($c,$command,$args,$host,$service);
    }

    my $output = 'plugin preview is only available for plugins!';
    return("command has no arguments") unless defined $args;

    my $cfg = $Monitoring::Config::save_options;
    $Monitoring::Config::key_sort = Monitoring::Config::Object::Parent::sort_by_object_keys($cfg->{object_attribute_key_order}, $cfg->{object_cust_var_order});

    my $macros = $c->{'db'}->_get_macros({skip_user => 1, args => [split/\!/mx, $args]});
    $macros    = Thruk::Utils::read_resource_file($self->{'config'}->{'obj_resource_file'}, $macros);

    if(defined $host and $host ne '') {
        my $objects = $self->get_objects_by_name('host', $host);
        if(defined $objects->[0]) {
            $macros = $objects->[0]->get_macros($c->{'obj_db'}, $macros);
        }
    }

    if(defined $service and $service ne '' and $service ne 'undefined') {
        my $objects = $self->get_objects_by_name('service', $service, 0, 'ho:'.$host);
        if(defined $objects->[0]) {
            $macros = $objects->[0]->get_macros($self, $macros);
        }
    }

    my $objects = $self->get_objects_by_name('command', $command);
    if(!defined $objects->[0]) {
        return(sprintf("did not find a command with name: %s", $command));
    }

    my($file,$cmd_args) = split/\s+/mx, $objects->[0]->{'conf'}->{'command_line'}, 2;
    ($file) = $c->{'db'}->_get_replaced_string($file, $macros);
    if(!-x $file) {
        return(sprintf("%s is not executable", $file));
    }
    my $pathspec = $Monitoring::Config::plugin_pathspec;
    if($file !~ m%$pathspec%mx) {
        return(sprintf("%s does not match path spec: %s", $file, $pathspec));
    }
    my($cmd, $rc) = $c->{'db'}->_get_replaced_string($objects->[0]->{'conf'}->{'command_line'}, $macros);

    if(!defined $cmd || !$rc) {
        return(sprintf("could not replace all macros in: %s", $file));
    }

    eval {
        local $SIG{ALRM} = sub { die('alarm'); };
        alarm(45);
        $cmd = $cmd." 2>/dev/null";
        $output = `$cmd`;
        alarm(0);
    };
    return $output;
}

##########################################################
sub _set_output_format {
    my($cfg) = @_;
    $Monitoring::Config::format_comments  = "%-".$cfg->{'indent_object_comments'}."s %s";
    $Monitoring::Config::format_values    = "%-".$cfg->{'indent_object_key'}."s%-".$cfg->{'indent_object_value'}."s %s";
    $Monitoring::Config::format_values_nl = "%-".$cfg->{'indent_object_key'}."s%-".$cfg->{'indent_object_value'}."s %s\n";
    $Monitoring::Config::format_keys      = "%-".$cfg->{'indent_object_key'}."s%s\n";
    return;
}

##########################################################

1;
