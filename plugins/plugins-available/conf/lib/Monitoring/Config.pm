package Monitoring::Config;

use strict;
use warnings;
use Monitoring::Config::File;

=head1 NAME

Monitoring::Config - Object Configuration

=head1 DESCRIPTION

Defaults for various objects

=head1 METHODS

=cut


##########################################################

=head2 new

return objects object

=cut
sub new {
    my $class  = shift;
    my $config = shift;

    my $self = {
        'config'           => $config,
        'errors'           => [],
        'errors_displayed' => 0,
        'files'            => [],
        'initialized'      => 0,
        'cached'           => 0,
        'needs_update'     => 0,
        'needs_commit'     => 0,
        'needs_reload'     => 0,
    };

    bless $self, $class;

    return $self;
}


##########################################################

=head2 init

initialize configs

=cut
sub init {
    my $self   = shift;
    my $config = shift;

    return $self unless $self->{'initialized'} == 0;
    $self->{'initialized'} = 1;

    for my $key (keys %{$config}) {
        $self->{'config'}->{$key} = $config->{$key};
    }
    $self->update();
    $self->{'cached'}      = 0;

    # set default excludes when defined manual paths
    if(!defined $self->{'config'}->{'obj_exclude'}
       and !defined $self->{'config'}->{'core_conf'}) {
        $self->{'config'}->{'obj_exclude'} = [
                    '^cgi.cfg$',
                    '^resource.cfg$',
                    '^nagios.cfg$',
                    '^icinga.cfg$'
        ];
    }

    return $self;
}


##########################################################

=head2 commit

commit changes to disk

=cut
sub commit {
    my $self = shift;
    my $rc   = 1;
    my $changed_files = $self->get_changed_files();
    for my $file (@{$changed_files}) {
        unless($file->save()) {
            $rc = 0;
        }
    }

    # remove deleted files from files
    my @new_files;
    for my $f (@{$self->{'files'}}) {
        if(!$f->{'deleted'} or -f $f->{'path'}) {
            push @new_files, $f;
        }
    }
    $self->{'files'}        = \@new_files;
    if($rc == 1) {
        $self->{'needs_commit'} = 0;
        $self->{'needs_reload'} = 1 if scalar @{$changed_files} > 0;
    }

    $self->_collect_errors();

    return $rc;
}


##########################################################

=head2 get_files

get all files

=cut
sub get_files {
    my $self = shift;
    return $self->{'files'};
}


##########################################################

=head2 get_file_by_path

get file by path

=cut
sub get_file_by_path {
    my $self = shift;
    my $path = shift;
    for my $file (@{$self->{'files'}}) {
        return $file if $file->{'path'} eq $path;
    }
    return;
}


##########################################################

=head2 get_changed_files

get all changed files

=cut
sub get_changed_files {
    my $self = shift;
    my @files;
    for my $file (@{$self->{'files'}}) {
        push @files, $file if $file->{'changed'} == 1;
    }
    return \@files;
}


##########################################################

=head2 get_objects

get all objects

=cut
sub get_objects {
    my $self = shift;
    my @objects = values %{$self->{'objects'}->{'byid'}};
    return \@objects;
}


##########################################################

=head2 get_objects_by_type

get objects by type

=cut
sub get_objects_by_type {
    my $self   = shift;
    my $type   = shift;
    my $filter = shift;

    return [] unless defined $self->{'objects'}->{'byname'}->{$type};

    if(defined $filter) {
        if(defined $self->{'objects'}->{'byname'}->{$type}->{$filter}) {
            return $self->{'objects'}->{'byname'}->{$type}->{$filter};
        }
        return;
    }

    my $objs = [];
    for my $id (@{$self->{'objects'}->{'bytype'}->{$type}}) {
        my $obj = $self->get_object_by_id($id);
        die($id) unless defined $obj;
        push @{$objs}, $obj;
    }

    return $objs;
}


##########################################################

=head2 get_objects_by_name

get objects by name

=cut
sub get_objects_by_name {
    my $self           = shift;
    my $type           = shift;
    my $name           = shift;
    my $templates_only = shift || 0;
    my $name2          = shift;

    my @objs;

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
            push @objs, $self->get_object_by_id($id);
        }
        return \@objs;
    }

    # existing template
    if(defined $self->{'objects'}->{'byname'}->{'templates'}->{$type}->{$name}) {
        push @objs, $self->get_object_by_id($self->{'objects'}->{'byname'}->{'templates'}->{$type}->{$name});
    }

    # existing object
    unless($templates_only) {
        if(defined $self->{'objects'}->{'byname'}->{$type}->{$name}) {
            my $id = $self->{'objects'}->{'byname'}->{$type}->{$name};
            unless(ref $id) {
                push @objs, $self->get_object_by_id($id);
            } else {
                my %ids;
                for my $subtype (keys %{$id}) {
                    for my $subid (values %{$id->{$subtype}}) {
                        $ids{$subid} = 1;
                    }
                }
                for my $id (keys %ids) {
                    push @objs, $self->get_object_by_id($id);
                }
            }
        }
    }

    return \@objs;
}


##########################################################

=head2 get_templates_by_type

get templates by type

=cut
sub get_templates_by_type {
    my $self   = shift;
    my $type   = shift;

    return [] unless defined $self->{'objects'}->{'byname'}->{$type};

    my $objs = [];
    my $ids  = [ values %{$self->{'objects'}->{'byname'}->{'templates'}->{$type}} ];
    for my $id (@{$ids}) {
        push @{$objs}, $self->get_object_by_id($id);
    }
    return $objs;
}


##########################################################

=head2 get_template_by_name

get template object by name

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

get object by location

=cut
sub get_object_by_location {
    my $self = shift;
    my $path = shift;
    my $line = shift;

    for my $file (@{$self->{'files'}}) {
        next unless $file->{'path'} eq $path;
        for my $obj (@{$file->{'objects'}}) {
            next unless $obj->{'line'} eq $line or $obj->{'line'}+1 eq $line;
            return $obj;
        }
    }
    return;
}


##########################################################

=head2 get_object_by_id

get object by location

=cut
sub get_object_by_id {
    my $self = shift;
    my $id   = shift;

    return $self->{'objects'}->{'byid'}->{$id};
}


##########################################################

=head2 get_services_for_host

returns services

=cut
sub get_services_for_host {
    my $self    = shift;
    my $host    = shift;
    my $objects = shift;

    $self->{'stats'}->profile(begin => "M::C::get_services_for_host()") if defined $self->{'stats'};;

    my($host_conf_keys, $host_config) = $host->get_computed_config($objects);

    my $services  = { 'host' => {}, 'group' => {}};
    my $host_name = $host->get_name();
    my $groups    = $host->get_groups($self, $objects);

    for my $svc (@{$self->get_objects_by_type('service')}) {
        my($svc_conf_keys, $svc_config) = $svc->get_computed_config($objects);

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

        if(defined $svc_config->{'host_name'} and grep { $_ eq $host_name } @{$svc_config->{'host_name'}}) {
            $services->{'host'}->{$svc->get_name()} = $svc;
        }
        if(defined $svc_config->{'hostgroup_name'}) {
            for my $group (@{$groups}) {
                if(grep { $_ eq $group} @{$svc_config->{'hostgroup_name'}}) {
                    $services->{'group'}->{$svc->get_name()} = $svc;
                    last;
                }
            }
        }
    }

    $self->{'stats'}->profile(end => "M::C::get_services_for_host()") if defined $self->{'stats'};;

    return $services;
}


##########################################################

=head2 update

update objects config

=cut
sub update {
    my ( $self ) = @_;

    $self->{'needs_commit'} = 0;
    $self->{'needs_update'} = 0;
    $self->{'needs_reload'} = 0;

    $self->_reset_errors();
    $self->_set_config();
    $self->_set_files();
    $self->_read_objects();
    return 1;
}


##########################################################

=head2 check_files_changed

update objects config

=cut
sub check_files_changed {
    my $self   = shift;
    my $reload = shift || 0;

    # reset errors
    $self->_reset_errors();
    my $errors1 = scalar @{$self->{'errors'}};

    $self->{'needs_update'} = 0;
    $self->{'needs_reload'} = 0 if $reload;
    $self->_check_files_changed($reload);
    my $errors2 = scalar @{$self->{'errors'}};

    if($errors2 > $errors1) {
        $self->{'needs_update'} = 1;
    }
    if($reload) {
        $self->update();
    }
    return 1;
}


##########################################################

=head2 update_object

update objects config

=cut
sub update_object {
    my $self    = shift;
    my $obj     = shift;
    my $data    = shift;
    my $comment = shift || '';
    my $rebuild = shift;
    $rebuild = 1 unless defined $rebuild;

    return unless defined $obj;

    # reset errors
    $self->_reset_errors();

    my $file = $obj->{'file'};

    # delete some references
    $self->delete_object($obj, 0);

    # update object
    $obj->{'conf'}          = $data;
    $obj->{'comments'}      = [ split/\n/mx, $comment ];
    $file->{'changed'}      = 1;
    $self->{'needs_commit'} = 1;

    push @{$file->{'objects'}}, $obj;

    $self->_rebuild_index() if $rebuild;

    return 1;
}


##########################################################

=head2 delete_object

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

move object to different file

=cut
sub move_object {
    my $self    = shift;
    my $obj     = shift;
    my $newfile = shift;
    my $rebuild = shift;
    $rebuild    = 1 unless defined $rebuild;

    return unless defined $newfile;
    return unless defined $obj;

    my $file                = $obj->{'file'};
    $file->{'changed'}      = 1;
    $newfile->{'changed'}   = 1;
    $self->{'needs_commit'} = 1;

    $self->delete_object($obj, 1);

    $obj->{'line'} = 0; # put new object at the end
    push @{$newfile->{'objects'}}, $obj;

    $self->_rebuild_index() if $rebuild;

    return 1;
}


##########################################################

=head2 file_add

add new file to config

=cut
sub file_add {
    my $self    = shift;
    my $file    = shift;
    my $rebuild = shift;
    $rebuild    = 1 unless defined $rebuild;
    push @{$self->{'files'}}, $file;
    $self->_rebuild_index() if $rebuild;
    return;
}


##########################################################

=head2 file_delete

remove a file from the config

=cut
sub file_delete {
    my $self    = shift;
    my $file    = shift;
    my $rebuild = shift;
    $rebuild                = 1 unless defined $rebuild;
    $file->{'deleted'}      = 1;
    $file->{'changed'}      = 1;
    $self->{'needs_commit'} = 1;

    $self->_rebuild_index() if $rebuild;
    return;
}


##########################################################

=head2 file_undelete

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
sub _set_config {
    my $self  = shift;

    if(defined $self->{'config'}->{'core_conf'}) {
        $self->{'config'}->{'obj_file'}          = [];
        $self->{'config'}->{'obj_dir'}           = [];
        $self->{'config'}->{'obj_resource_file'} = undef;

        my $core_conf = $self->{'config'}->{'core_conf'};
        if(defined $ENV{'OMD_ROOT'} and -s $ENV{'OMD_ROOT'}."/version") {
            my $newest = $self->_newest_file(
                                             $ENV{'OMD_ROOT'}.'/tmp/nagios/nagios.cfg',
                                             $ENV{'OMD_ROOT'}.'/tmp/icinga/icinga.cfg',
                                             $ENV{'OMD_ROOT'}.'/tmp/shinken/shinken.cfg',
                                            );
            $core_conf = $newest if defined $newest;
        }

        if($core_conf =~ m|/omd/sites/(.*?)/etc/nagios/nagios.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/nagios/nagios.cfg';
        }
        elsif($core_conf =~ m|/omd/sites/(.*?)/etc/icinga/icinga.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/icinga/icinga.cfg';
        }
        elsif($core_conf =~ m|/omd/sites/(.*?)/etc/shinken/shinken.cfg|mx) {
            $core_conf = '/omd/sites/'.$1.'/tmp/shinken/shinken.cfg';
        }

        open(my $fh, '<', $core_conf) or do {
            push @{$self->{'errors'}}, "cannot read $core_conf: $!";
            $self->{'initialized'} = 0;
            return;
        };
        while(my $line = <$fh>) {
            chomp($line);
            my($key,$value) = split/\s*=\s*/mx, $line, 2;
            next unless defined $value;
            $key   =~ s/^\s*(.*?)\s*$/$1/mx;
            $value =~ s/^\s*(.*?)\s*$/$1/mx;
            if($key eq 'cfg_file') {
                push @{$self->{'config'}->{'obj_file'}}, $value;
            }
            if($key eq 'cfg_dir') {
                push @{$self->{'config'}->{'obj_dir'}}, $value;
            }
            if($key eq 'resource_file') {
                $self->{'config'}->{'obj_resource_file'} = $value;
            }
        }
        close($fh);
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
    my $self  = shift;

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
    opendir(my $dh, $dir) or die("cannot open directory $dir: $!");
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

        push @files, $dir."/".$file;
    }

    return \@files;
}


##########################################################
sub _set_files {
    my ( $self ) = @_;
    $self->{'files'} = $self->_get_files();
    return;
}


##########################################################
sub _get_files {
    my ( $self ) = @_;

    my @files;
    my $filenames = $self->_get_files_names();
    for my $filename (@{$filenames}) {
        my $file = Monitoring::Config::File->new($filename, $self->{'config'}->{'obj_readonly'});
        push @files, $file;
    }

    return \@files;
}


##########################################################
sub _get_files_names {
    my ( $self ) = @_;
    my $files    = {};
    my $config   = $self->{'config'};

    # single folders
    if(defined $config->{'obj_dir'}) {
        for my $dir ( ref $config->{'obj_dir'} eq 'ARRAY' ? @{$config->{'obj_dir'}} : ($config->{'obj_dir'}) ) {
            for my $file (@{$self->_get_files_for_folder($dir, '\.cfg$')}) {
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
            $files->{$file} = 1;
        }
    }

    if(!defined $config->{'obj_dir'} and !defined $config->{'obj_file'}) {
        push @{$self->{'errors'}}, "you need to configure paths (obj_dir, obj_file)";
    }

    my @uniqfiles = keys %{$files};
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

        # mtime & inode
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
           $atime,$mtime,$ctime,$blksize,$blocks)
           = stat($file->{'path'});

        if(!defined $ino) {
            unless($reload) {
                push @newfiles, $file;
                push @{$self->{'errors'}}, "file ".$file->{'path'}." has been deleted.";
            }
        }
        else {
            # inode or mtime changed?
            if($file->{'inode'} ne $ino or $file->{'mtime'} ne $mtime) {
                $file->{'inode'} = $ino;
                $file->{'mtime'} = $mtime;
                # get md5
                my $meta = $file->get_meta_data();
                if($meta->{'md5'} ne $file->{'md5'}) {
                    if($reload) {
                        $file->{'parsed'} = 0;
                        $file->update_objects();
                        $file->_update_meta_data();
                    } else {
                        push @{$self->{'errors'}}, "file ".$file->{'path'}." has been changed since reading it.";
                    }
                }
            }
            push @newfiles, $file;
        }
    }
    $self->{'files'} = \@newfiles;

    for my $file (@{$self->_get_files_names()}) {
        if(!defined $oldfiles->{$file}) {
            if($reload) {
                push @{$self->{'files'}}, Monitoring::Config::File->new($file, $self->{'config'}->{'obj_readonly'});
            } else {
                push @{$self->{'errors'}}, "file ".$file." has been added.";
            }
        }
    }

    return;
}


##########################################################
# collect errors from all files
sub _collect_errors {
    my ( $self ) = @_;
    for my $file ( @{$self->{'files'}} ) {
        push @{$self->{'errors'}}, @{$file->{'errors'}};
    }
    return scalar @{$self->{'errors'}};
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
    }

    if(scalar @{$objects_without_primary} > 0) {
        for my $obj (@{$objects_without_primary}) {
            my $conf = $obj->get_resolved_config($objects);
            my $tmp_obj = Monitoring::Config::Object->new(type => $obj->get_type(), conf => $conf);
            my $primary = $tmp_obj->get_primary_name();
            if(defined $primary) {
                $self->_update_obj_in_index($objects, $obj, $primary);
            } else {
                push @{$self->{'errors'}}, "object has no name in ".$obj->{'file'}->{'path'}.":".$obj->{'line'};
            }
        }
    }

    $self->{'objects'} = $objects;
    $self->{'macros'}  = $macros;

    $self->{'stats'}->profile(end => "M::C::_rebuild_index()") if defined $self->{'stats'};;
    return;
}


##########################################################
sub _update_obj_in_index {
    my $self    = shift;
    my $objects = shift;
    my $obj     = shift;
    my $primary = shift;

    my $pname  = $obj->get_primary_name(1);
    my $tname  = $obj->get_template_name();
    my $found  = 0;

    # set uniq id
    $obj->set_uniq_id($objects);

    # by template name
    if(defined $tname) {
        if(defined $objects->{'byname'}->{'templates'}->{$obj->{'type'}}->{$tname}) {
            my $orig = $self->get_object_by_id($objects->{'byname'}->{'templates'}->{$obj->{'type'}}->{$tname});
            push @{$self->{'errors'}}, "duplicate ".$obj->{'type'}." template definition $tname in ".$obj->{'file'}->{'path'}.":".$obj->{'line'}."\n -> already defined in ".$orig->{'file'}->{'path'}.":".$orig->{'line'};
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
        if(defined $existing_id) {
            my $orig = $self->get_object_by_id($existing_id);
            if(!defined $orig) {
                push @{$self->{'errors'}},
                    "duplicate ".$obj->{'type'}." definition $pname in ".$obj->{'file'}->{'path'}.":".$obj->{'line'};
            } else {
                push @{$self->{'errors'}},
                    "duplicate ".$obj->{'type'}." definition $pname in ".$obj->{'file'}->{'path'}.":".$obj->{'line'}."\n -> already defined in ".$orig->{'file'}->{'path'}.":".$orig->{'line'};
            }
        }
        $objects->{'byname'}->{$obj->{'type'}}->{$pname} = $obj->{'id'};
        $found++;
    }

    if($found or defined $primary) {
        # by id
        $objects->{'byid'}->{$obj->{'id'}} = $obj;

        # by type
        if(!defined $tname) {
            push @{$objects->{'bytype'}->{$obj->{'type'}}}, $obj->{'id'};
        }
    }

    return $found;
}


##########################################################
sub _reset_errors {
    my $self = shift;
    if($self->{'errors_displayed'}) {
        $self->{'errors'}           = [];
        $self->{'errors_displayed'} = 0;
    }
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
    use Data::Dumper; print STDERR Dumper(\@sorted);
    my $newest = shift @sorted;
    return $filelist{$newest} if defined $newest;
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
