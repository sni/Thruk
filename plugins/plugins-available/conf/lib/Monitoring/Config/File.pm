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

##########################################################

=head2 new

return new host

=cut
sub new {
    my ( $class, $file, $readonlypattern, $coretype, $force, $remotepath ) = @_;
    Thruk::Utils::decode_any($file);
    Thruk::Utils::decode_any($remotepath);
    my $self = {
        'path'         => $file,
        'display'      => $remotepath || $file,
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

    # reset macro index
    $self->{'macros'} = { 'host' => {}, 'service' => {}};

    my $current_object;
    my $in_unknown_object;
    my $in_disabled_object;
    my $comments            = [];
    my $inl_comments        = {};
    $self->{'objects'}      = [];
    $self->{'errors'}       = [];
    $self->{'parse_errors'} = [];
    $self->{'comments'}     = [];

    open(my $fh, '<', $self->{'path'}) or die("cannot open file ".$self->{'path'}.": ".$!);
    while(my $line = <$fh>) {
        Thruk::Utils::decode_any($line);
        chomp($line);
        if($. < 10) {
            if($line =~ m/^\#\s*thruk:\s*readonly/mxo) {
                $self->{'readonly'} = 1;
            }
        }
        # connect multiple lines
        while(substr($line, -1) eq '\\' and (substr($line, 0, 1) ne '#' or $in_disabled_object)) {
            my $newline = <$fh>;
            chomp($newline);
            StripLSpace($newline);
            if($in_disabled_object) {
                $newline = substr($newline, 1);
            }
            $line = substr($line, 0, -1).$newline;
        }
        ($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object)
            = $self->_parse_line($line, $current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object);
    }
    CORE::close($fh) or die("cannot close file ".$self->{'path'}.": ".$!);

    if(defined $current_object or $in_unknown_object) {
        push @{$self->{'parse_errors'}}, "expected end of object in ".$self->{'path'}.":".$.;
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
    $self->{'changed'} = 0;
    return;
}


##########################################################

=head2 update_objects_from_text

update all objects from this file by text

=cut
sub update_objects_from_text {
    my ( $self, $text, $lastline ) = @_;

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

    my $linenr = 1;
    my $buffer = '';
    for my $line (split/\n/mx, $text) {
        StripTSpace($line);
        if(substr($line, -1) eq '\\' and substr($line, 0, 1) ne '#') {
            StripLSpace($line);
            $line    = substr($line, 0, -1);
            $buffer .= $line;
            $linenr++;
            next;
        }
        if($buffer ne '') {
            StripLSpace($line);
            $line   = $buffer.$line;
            $buffer = '';
        }
        ($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object)
            = $self->_parse_line($line, $current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object, $linenr);
        if(defined $lastline && $lastline ne '' && !defined $object_at_line) {
            if($linenr >= $lastline) {
                $object_at_line = $current_object;
            }
        }
        $linenr++;
    }

    if(defined $current_object or $in_unknown_object) {
        push @{$self->{'parse_errors'}}, "expected end of object in ".$self->{'path'}.":".$.;
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

    return $object_at_line if defined $lastline;
    return;
}

##########################################################

=head2 readonly

return true if file is readonly

=cut
sub readonly {
    my($self) = @_;
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

=head2 _parse_line

parse a single config line

=cut
sub _parse_line {
    my ( $self, $line, $current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object, $linenr) = @_;

    chomp($line);

    # strip whitespaces
    StripLTSpace($line);

    # skip empty lines;
    return($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object) if $line eq '';

    # full line comments
    if(!$in_disabled_object
       && (    substr($line, 0, 1) eq '#'
            || substr($line, 0, 1) eq ';')
       && $line !~ m/^(;|\#)\s*define\s+/mxo
    ) {
        $line =~ s/^(;|\#)\s+//mx;
        push @{$comments}, $line;
        return($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object);
    }

    # escaped semicolons are allowed
    my $semicolonreplacement = chr(0).chr(0);
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

    $linenr = $. unless defined $linenr;
    $self->{'lines'} = $linenr; # increase line counter

    # new object starts
    if($line =~ m/^(;|\#|)\s*define\s+(\w+)(\s|{|$)/mxo) {
        $in_disabled_object = $1 ? 1 : 0;
        $current_object = Monitoring::Config::Object->new(type => $2, file => $self, line => $linenr, 'coretype' => $self->{'coretype'}, disabled => $in_disabled_object);
        unless(defined $current_object) {
            push @{$self->{'parse_errors'}}, "unknown object type '".$2."' in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
            $in_unknown_object  = 1;
            return($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object);
        }
    }

    # old object finished
    elsif($line eq '}' or ($in_disabled_object and $line =~ m/^(;|\#)\s*}$/mxo)) {
        unless(defined $current_object) {
            push @{$self->{'parse_errors'}}, "unexpected end of object in ".Thruk::Utils::Conf::_link_obj($self->{'path'}, $linenr);
            return($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object);
        }
        $current_object->{'comments'}     = $comments;
        $current_object->{'inl_comments'} = $inl_comments;
        $current_object->{'line2'}    = $linenr;
        my $parse_errors = $current_object->parse();
        if(scalar @{$parse_errors} > 0) { push @{$self->{'parse_errors'}}, @{$parse_errors} }
        $current_object->{'id'} = $current_object->_make_id();
        push @{$self->{'objects'}}, $current_object;
        undef $current_object;
        $comments     = [];
        $inl_comments = {};
        $in_unknown_object  = 0;
        $in_disabled_object = 0;
    }

    elsif($in_unknown_object) {
        # silently skip attributes from unknown objects
    }

    # in an object definition
    elsif(defined $current_object) {
        if($in_disabled_object) { $line =~ s/^(\#|;)\s*//mxo; }
        my($key, $value) = split(/\s+/mxo, $line, 2);
        return($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object) if($in_disabled_object && !defined $key);
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
    }

    return($current_object, $in_unknown_object, $comments, $inl_comments, $in_disabled_object);
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

    my $content = $self->get_new_file_content();
    open(my $fh, '>', $self->{'path'}) or do {
        push @{$self->{'errors'}}, "cannot write to ".$self->{'path'}.": ".$!;
        return;
    };
    print $fh $content;
    Thruk::Utils::IO::close($fh, $self->{'path'});

    $self->{'changed'}     = 0;
    $self->{'is_new_file'} = 0;
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
    my($self) = @_;
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
        $obj->{'line'} = $linenr;

        $linenr += $nr_object_lines;
    }

    return encode_utf8($new_content);
}

##########################################################

=head2 StripTSpace

strip trailing whitespace

replacement for string::strip, which is broken on 64 bit
https://rt.cpan.org/Ticket/Display.html?id=70028

=cut
sub StripTSpace {
    $_[0] =~ s/\s+$//mx;
    return;
}

##########################################################

=head2 StripLSpace

strip leading whitespace

=cut
sub StripLSpace {
    $_[0] =~ s/^\s+//mx;
    return;
}

##########################################################

=head2 StripLTSpace

strip leading and trailing whitespace

=cut
sub StripLTSpace {
    $_[0] =~ s/^\s+//mx;
    $_[0] =~ s/\s+$//mx;
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
