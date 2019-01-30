package Monitoring::Config::File;

use strict;
use warnings;
use Carp;
use File::Temp qw/ tempfile /;
use Monitoring::Config::Object;
use File::Slurp;
use Encode qw(encode_utf8 decode);
use Thruk::Utils;
use Thruk::Utils::Conf;
use Thruk::Utils::IO;

=head1 NAME

Monitoring::Conf::File - Object Configuration File

=head1 DESCRIPTION

Defaults for host objects

=head1 METHODS

=cut

my $semicolonreplacement = chr(0).chr(0);

##########################################################

=head2 new

return new file object

=cut
sub new {
    my ( $class, $file, $readonlypattern, $coretype, $force, $remotepath ) = @_;
    Thruk::Utils::decode_any($file);
    Thruk::Utils::decode_any($remotepath);
    my $self = {
        'path'         => $file,
        'display'      => $remotepath || $file,
        'backup'       => '',
        'mtime'        => undef,
        'md5'          => undef,
        'inode'        => 0,
        'parsed'       => 0,
        'changed'      => 0,
        'readonly'     => 0,
        'lines'        => 0,
        'is_new_file'  => 0,
        'deleted'      => 0,
        'objects'      => [],
        'errors'       => [],
        'parse_errors' => [],
        'macros'       => { 'host' => {}, 'service' => {}},
        'coretype'     => $coretype,
    };
    bless $self, $class;

    confess('no core type!') unless defined $coretype;

    # dont save relative paths
    if(!$force && $file =~ m/\.\./mx) {
        warn("won't open relative path: $file");
        return;
    }

    # config files must end on .cfg
    if(!$force && $file !~ m/\.cfg$/mx) {
        warn("unknown suffix for file $file. Should be '.cfg'.");
        return;
    }

    # no double slashes in paths
    $self->{'path'}    =~ s|/+|/|gmx;
    $self->{'display'} =~ s|/+|/|gmx;

    # readonly file?
    $self->update_readonly_status($readonlypattern);

    # new file?
    unless(-f $self->{'path'}) {
        $self->{'is_new_file'} = 1;
        $self->{'changed'}     = 1;
    }

    # refresh meta data
    $self->_update_meta_data();

    return $self;
}

##########################################################

=head2 update_objects

update all objects from this file

=cut
sub update_objects {
    my ( $self ) = @_;

    return unless $self->{'parsed'} == 0;
    return unless defined $self->{'md5'};

    my $text = Thruk::Utils::decode_any(scalar read_file($self->{'path'}));
    $self->update_objects_from_text($text);
    $self->{'changed'} = 0;
    $self->{'backup'}  = "";
    return;
}


##########################################################

=head2 update_objects_from_text

update all objects from this file by text

=cut
sub update_objects_from_text {
    my ($self, $text, $lastline) = @_;

    # reset macro index
    $self->{'macros'} = { 'host' => {}, 'service' => {}};

    my $current_object;
    my $object_at_line;
    my $in_unknown_object;
    my $in_disabled_object;
    my $comments            = [];
    my $inl_comments        = {};
    $self->{'objects'}      = [];
    $self->{'errors'}       = [];
    $self->{'parse_errors'} = [];
    $self->{'comments'}     = [];

    my $linenr = 0;
    my $buffer = '';
    my @lines = split(/\n/mx, $text);
    while(@lines) {
        my $line = shift @lines;
        $line =~ s/\s+$//gmxo;
        $line =~ s/^\s+//gmxo;
        $linenr++;
        if(substr($line, -1) eq '\\') {
            $line = substr($line, 0, -1);
            if($buffer ne '' && substr($line, 0, 1) eq '#') {
                $line = substr($line, 1);
            }
            $buffer .= $line;
            next;
        }
        if($buffer) {
            if(substr($line, 0, 1) eq '#') {
                $line = substr($line, 1);
            }
            $line =~ s/^\s+//mx;
            $line   = $buffer.$line;
            $buffer = '';
        }
        next unless $line;

        if($linenr < 10) {
            if($line =~ m/^\#\s*thruk:\s*readonly/mxo) {
                $self->{'readonly'} = 1;
            }
        }

        my $first_char = substr($line, 0, 1);

        # full line comments
        if(!$in_disabled_object && ($first_char eq '#' || $first_char eq ';') && $line !~ m/^(;|\#)\s*define\s+/mxo) {
            $line =~ s/^(;|\#)\s+//mx;
            push @{$comments}, $line;
            next;
        }

        if(index($line, ';') != -1) {
            # escaped semicolons are allowed
            $line =~ s/\\;/$semicolonreplacement/gmxo;

            # inline comments only with ; not with #
            if($line =~ s/^(.+?)\s*([\;].*)$//gmxo) {
                $line = $1;
                my $comment = $2;
                # save inline comments if possible
                my($key, $value) = split(/\s+/mxo, $line, 2);
                $inl_comments->{$key} = $comment if defined $key;
            }

            $line =~ s/$semicolonreplacement/\\;/gmxo;
        }

        # old object finished
        if($first_char eq '}' || ($in_disabled_object && $line =~ m/^(;|\#)\s*}$/mxo)) {
            unless(defined $current_object) {
                push @{$self->{'parse_errors'}}, "unexpected end of object in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
                next;
            }
            $current_object->{'comments'}     = $comments;
            $current_object->{'inl_comments'} = $inl_comments;
            $current_object->{'line2'}        = $linenr;
            my $parse_errors = $current_object->parse();
            if(scalar @{$parse_errors} > 0) { push @{$self->{'parse_errors'}}, @{$parse_errors} }
            $current_object->{'id'} = $current_object->_make_id();
            push @{$self->{'objects'}}, $current_object;
            undef $current_object;
            $comments     = [];
            $inl_comments = {};
            $in_unknown_object  = 0;
            $in_disabled_object = 0;
            next;
        }

        # new object starts
        elsif(index($line, 'define') != -1 && $line =~ m/^(;|\#|)\s*define\s+(\w+)(\s|{|$)/mxo) {
            $in_disabled_object = $1 ? 1 : 0;
            $current_object = Monitoring::Config::Object->new(type => $2, file => $self, line => $linenr, 'coretype' => $self->{'coretype'}, disabled => $in_disabled_object);
            unless(defined $current_object) {
                push @{$self->{'parse_errors'}}, "unknown object type '".$2."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
                $in_unknown_object  = 1;
            }
            next;
        }

        elsif($in_unknown_object) {
            # silently skip attributes from unknown objects
            next;
        }

        # in an object definition
        elsif(defined $current_object) {
            if($in_disabled_object) { $line =~ s/^(\#|;)\s*//mxo; }
            my($key, $value) = split(/\s+/mxo, $line, 2);
            next if($in_disabled_object && !defined $key);
            # different parsing for timeperiods
            if($current_object->{'type'} eq 'timeperiod'
               and $key ne 'use'
               and $key ne 'register'
               and $key ne 'name'
               and $key ne 'timeperiod_name'
               and $key ne 'alias'
               and $key ne 'exclude'
            ) {
                my($timedef, $timeranges);
                if($line =~ m/^(.*?)\s+(\d{1,2}:\d{1,2}\-\d{1,2}:\d{1,2}[\d,:\-\s]*)/mxo) {
                    $timedef    = $1;
                    $timeranges = $2;
                }
                if(defined $timedef) {
                    if(defined $current_object->{'conf'}->{$timedef} and $current_object->{'conf'}->{$timedef} ne $timeranges) {
                        push @{$self->{'parse_errors'}}, "duplicate attribute $timedef in '".$line."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
                    }
                    $current_object->{'conf'}->{$timedef} = $timeranges;
                    if(defined $inl_comments->{$key} and $key ne $timedef) {
                        $inl_comments->{$timedef} = delete $inl_comments->{$key};
                    }
                } else {
                    push @{$self->{'parse_errors'}}, "unknown time definition '".$line."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
                }
            }
            else {
                if(defined $current_object->{'conf'}->{$key} and $current_object->{'conf'}->{$key} ne $value and substr($key, 0, 1) ne '#') {
                    push @{$self->{'parse_errors'}}, "duplicate attribute $key in '".$line."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
                }
                $current_object->{'conf'}->{$key} = $value;

                # save index of custom macros
                $self->{'macros'}->{$current_object->{'type'}}->{$key} = 1 if substr($key, 0, 1) eq '_';
            }
            next;
        }

        else {
            my($key,$value) = split/\s*=\s*/mx, $line, 2;
            # shinken macros can be anywhere
            if(defined $value and $self->{'coretype'} eq 'shinken') {
                $key   =~ s/^\s*(.*?)\s*$/$1/mx;
                $value =~ s/^\s*(.*?)\s*$/$1/mx;
                if (substr($key, 0, 1) eq '$' and substr($key, -1, 1) eq '$') {
                    # Ignore macros
                } elsif($key =~ /^[a-z0-9_]+$/mx) {
                    # Ignore cfg_dir, cfg_file, ...
                } else {
                    push @{$self->{'parse_errors'}}, "syntax invalid: '".$line."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
                }
            # something totally unknown
            } else {
                push @{$self->{'parse_errors'}}, "syntax invalid: '".$line."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
            }
            next;
        }
    }

    $self->{'lines'} = $linenr; # set line counter

    if(defined $current_object or $in_unknown_object) {
        push @{$self->{'parse_errors'}}, "expected end of object in ".$self->{'path'}.":".$linenr;
    }

    # add trailing comments to last object
    if(defined $comments and scalar @{$comments} > 0) {
        # only if we have at least one object
        if(scalar @{$self->{'objects'}} > 0) {
            push @{$self->{'objects'}->[scalar @{$self->{'objects'}}-1]->{'comments'}}, @{$comments};
        } else {
            $self->{'comments'} = $comments;
        }
    }

    $self->{'parsed'}  = 1;
    $self->{'changed'} = 1;

    # return object for given line
    if(defined $lastline) {
        for my $obj (@{$self->{'objects'}}) {
            if($obj->{'line'} >= $lastline) {
                return($obj);
            }
        }
    }
    return;
}

##########################################################

=head2 add_object

add object to file

=cut
sub add_object {
    my($self, $conf) = @_;

    $conf->{'file'}     = $self;
    $conf->{'coretype'} = $self->{'coretype'};
    push @{$self->{'objects'}}, Monitoring::Config::Object->new(%{$conf});
    $self->{'changed'} = 1;

    return;
}

##########################################################

=head2 readonly

return true if file is readonly

=cut
sub readonly {
    my($self, $set) = @_;
    if(defined $set) {
        $self->{'readonly'} = $set;
    }
    return $self->{'readonly'};
}

##########################################################

=head2 update_readonly_status

updates the readonly status for this file

=cut
sub update_readonly_status {
    my($self, $readonlypattern) = @_;
    if(defined $readonlypattern) {
        for my $p ( ref $readonlypattern eq 'ARRAY' ? @{$readonlypattern} : ($readonlypattern) ) {
            if($self->{'path'} =~ m|$p|mx) {
                $self->{'readonly'} = 1;
                last;
            }
        }
    }
    return $self->{'readonly'};
}

##########################################################

=head2 get_meta_data

return meta data for this file

=cut

sub get_meta_data {
    my ( $self ) = @_;

    my $meta = {
        'mtime' => undef,
        'inode' => undef,
        'md5'   => undef,
    };
    if($self->{'is_new_file'}) {
        return $meta;
    }
    if(!-f $self->{'path'} || !-r $self->{'path'}) {
        push @{$self->{'errors'}}, "cannot read file: ".$self->{'path'}.": ".$!;
        return $meta;
    }

    # md5 hex
    my $ctx = Digest::MD5->new;
    open(my $fh, '<', $self->{'path'});
    $ctx->addfile($fh);
    $meta->{'md5'} = $ctx->hexdigest;
    CORE::close($fh) or die("cannot close file ".$self->{'path'}.": ".$!);

    # mtime & inode
    my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
       $atime,$mtime,$ctime,$blksize,$blocks)
       = stat($self->{'path'});
    $meta->{'mtime'} = $mtime;
    $meta->{'inode'} = $ino;

    return $meta;
}


##########################################################

=head2 save

save changes to disk

=cut
sub save {
    my ($self) = @_;

    $self->{'errors'}       = [];
    $self->{'parse_errors'} = [];
    if($self->{'readonly'}) {
        push @{$self->{'errors'}}, 'write denied for readonly file: '.$self->{'path'};
        return;
    }

    if($self->{'is_new_file'}) {
        my @dirs = ();
        my @path = split /\//mx, $self->{'path'};
        pop @path; # remove file
        map { push @dirs, $_; mkdir join('/', @dirs) } @path;
        if(open(my $fh, '>', $self->{'path'})) {
            Thruk::Utils::IO::close($fh, $self->{'path'});
        } else {
            push @{$self->{'errors'}}, "cannot create ".$self->{'path'}.": ".$!;
            return;
        }
    }

    if($self->{'deleted'}) {
        unlink($self->{'path'}) or do {
            push @{$self->{'errors'}}, "cannot delete ".$self->{'path'}.": ".$!;
        };
        return;
    }

    my $content = $self->get_new_file_content(1);
    open(my $fh, '>', $self->{'path'}) or do {
        push @{$self->{'errors'}}, "cannot write to ".$self->{'path'}.": ".$!;
        return;
    };
    print $fh $content;
    Thruk::Utils::IO::close($fh, $self->{'path'});

    $self->{'changed'}     = 0;
    $self->{'is_new_file'} = 0;
    $self->{'backup'}      = '';
    $self->_update_meta_data();

    return 1;
}


##########################################################

=head2 diff

get diff of changes

=cut
sub diff {
    my ( $self ) = @_;

    my ($fh, $filename) = tempfile();
    my $content         = $self->get_new_file_content();
    print $fh $content;
    CORE::close($fh);

    my $diff = "";
    my $cmd = 'diff -wuN "'.$self->{'path'}.'" "'.$filename.'" 2>&1';
    open(my $ph, '-|', $cmd);
    while(<$ph>) {
        my $line = $_;
        Thruk::Utils::decode_any($line);
        $diff .= $line;
    }
    unlink($filename);

    # nice file path
    $diff =~ s/\Q$self->{'path'}\E/$self->{'display'}/mx;

    return $diff;
}


##########################################################
sub _update_meta_data {
    my ( $self ) = @_;
    my $meta = $self->get_meta_data();
    $self->{'md5'}   = $meta->{'md5'};
    $self->{'mtime'} = $meta->{'mtime'};
    $self->{'inode'} = $meta->{'inode'};
    return $meta;
}

##########################################################

=head2 get_new_file_content

returns the current raw file content

=cut
sub get_new_file_content {
    my($self, $update_linenr) = @_;
    my $new_content = '';

    return $new_content if $self->{'deleted'};

    return encode_utf8(Thruk::Utils::decode_any(scalar read_file($self->{'path'}))) unless $self->{'changed'};

    my $linenr = 1;

    # file with comments only
    if($self->{'comments'}) {
        $new_content  = Monitoring::Config::Object::format_comments($self->{'comments'});
        $linenr      += scalar @{$self->{'comments'}};
    }

    # sort by line number, but put line 0 at the end
    for my $obj (sort { $b->{'line'} > 0 <=> $a->{'line'} > 0 || $a->{'line'} <=> $b->{'line'} } @{$self->{'objects'}}) {

        my($text, $nr_comment_lines, $nr_object_lines) = $obj->as_text();
        $new_content .= $text;
        $linenr      += $nr_comment_lines;

        # update line number of object
        if($update_linenr) {
            $obj->{'line'}  = $linenr;
            $obj->{'line2'} = $linenr+$nr_object_lines;
        }

        $linenr += $nr_object_lines;
    }

    return encode_utf8($new_content);
}

##########################################################

=head2 set_backup

set backup file content in order to generate change diff later

=cut
sub set_backup {
    my($self) = @_;
    return if $self->{'backup'};
    return if $self->{'is_new_file'};
    # read file from disk
    $self->{'backup'}  = scalar read_file($self->{'path'});
    return;
}

##########################################################

=head2 try_merge

merge our changes into a changed file from disk.

returns true if file has been updated and false if merge fails.

=cut
sub try_merge {
    my($self) = @_;
    return 1 unless $self->{'changed'};
    if($self->{'is_new_file'}) {
        push @{$self->{'errors'}}, "a file with the same name has been created on disk meanwhile.";
        return;
    }
    if(!$self->{'backup'}) {
        push @{$self->{'errors'}}, "cannot merge, got no backup";
        return;
    }

    my $tmpdir = File::Temp::tempdir();

    # save our backup as clean file
    my $file1 = Monitoring::Config::File->new($tmpdir.'/file1.cfg', undef, $self->{'coretype'});
    $file1->update_objects_from_text($self->{'backup'});
    open(my $fh1, '>', $tmpdir.'/file1.cfg') or die("cannot write: ".$tmpdir."/file1.cfg: ".$!);
    print $fh1 $file1->get_new_file_content();
    Thruk::Utils::IO::close($fh1, $tmpdir.'/file1.cfg');

    # save our current content as clean file
    my $file2 = Monitoring::Config::File->new($tmpdir.'/file2.cfg', undef, $self->{'coretype'});
    $file2->update_objects_from_text($self->get_new_file_content());
    open(my $fh2, '>', $tmpdir.'/file2.cfg') or die("cannot write: ".$tmpdir."/file2.cfg: ".$!);
    print $fh2 $file2->get_new_file_content();
    Thruk::Utils::IO::close($fh2, $tmpdir.'/file2.cfg');

    # get diff from new file from disk compared to our backup
    my $cmd = 'cd '.$tmpdir.' && diff -u file1.cfg file2.cfg > patch 2>/dev/null';
    my($rc) = Thruk::Utils::IO::cmd(undef, $cmd);

    # save cleaned version of current file from disk
    my $file3 = Monitoring::Config::File->new($self->{'path'}, undef, $self->{'coretype'});
    $file3->update_objects();
    $file3->{'changed'} = 1;
    open(my $fh3, '>', $tmpdir.'/file1.cfg') or die("cannot write: ".$tmpdir."/file1.cfg: ".$!);
    print $fh3 $file3->get_new_file_content();
    Thruk::Utils::IO::close($fh3, $tmpdir.'/file1.cfg');

    # try to apply patch to current file from disk
    $cmd = 'cd '.$tmpdir.' && patch -F 10 -p0 < patch 2>&1';
    my($rc2, $out) = Thruk::Utils::IO::cmd(undef, $cmd);

    my $text = Thruk::Utils::decode_any(scalar read_file($tmpdir.'/file1.cfg'));

    my $rej;
    $rej = ":\n".Thruk::Utils::decode_any(scalar read_file($tmpdir.'/file1.cfg.rej')) if -e $tmpdir.'/file1.cfg.rej';

    # cleanup
    unlink(glob($tmpdir.'/*'));
    rmdir($tmpdir);

    # merge successful
    if($rc2 == 0) {
        # read merged file and replace our content with the merged one
        $self->update_objects_from_text($text);
        $self->{'backup'} = "";
        $self->set_backup();
        $self->_update_meta_data();
        return 1;
    }

    my $error = "unable to merge local disk changes:\n".$out;
    $error .= ":\n".$rej if $rej;
    push @{$self->{'errors'}}, $error;
    return;
}

##########################################################

1;
