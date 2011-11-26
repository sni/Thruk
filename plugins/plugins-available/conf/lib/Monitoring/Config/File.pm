package Monitoring::Config::File;

use strict;
use warnings;
use Carp;
use File::Temp qw/ tempfile /;
use Monitoring::Config::Object;
use File::Slurp;

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
    my ( $class, $file, $readonlypattern ) = @_;
    my $self = {
        'path'        => $file,
        'mtime'       => undef,
        'md5'         => undef,
        'inode'       => 0,
        'parsed'      => 0,
        'changed'     => 0,
        'readonly'    => 0,
        'lines'       => 0,
        'is_new_file' => 0,
        'deleted'     => 0,
        'objects'     => [],
        'errors'      => [],
    };
    bless $self, $class;

    # dont save relative paths
    if($file =~ m/\.\./mx or $file !~ m/\.cfg$/mx) {
        return;
    }

    # readonly file?
    if(defined $readonlypattern) {
        for my $p ( ref $readonlypattern eq 'ARRAY' ? @{$readonlypattern} : ($readonlypattern) ) {
            if($file =~ m|$p|mx) {
                $self->{'readonly'} = 1;
                last;
            }
        }
    }

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

    my $current_object;
    my $in_unknown_object;
    my $comments       = [];
    $self->{'objects'} = [];
    $self->{'errors'}  = [];

    open(my $fh, '<', $self->{'path'}) or die("cannot open file ".$self->{'path'}.": ".$!);
    while(my $line = <$fh>) {
        chomp($line);
        while(substr($line, -1) eq '\\' and substr($line, 0, 1) ne '#') {
            my $newline = <$fh>;
            chomp($newline);
            StripLSpace($newline);
            $line = substr($line, 0, -1).$newline;
        }
        ($current_object, $in_unknown_object, $comments)
            = $self->_parse_line($line, $current_object, $in_unknown_object, $comments);
    }

    if(defined $current_object or $in_unknown_object) {
        push @{$self->{'errors'}}, "expected end of object in ".$self->{'path'}.":".$.;
    }

    # add trailing comments to last object
    if(defined $comments and scalar @{$comments} > 0 and scalar @{$self->{'objects'}} > 0) {
        push @{$self->{'objects'}->[scalar @{$self->{'objects'}}-1]->{'comments'}}, @{$comments};
    }

    close($fh);

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

    my $current_object;
    my $object_at_line;
    my $in_unknown_object;
    my $comments       = [];
    $self->{'objects'} = [];
    $self->{'errors'}  = [];

    my $linenr = 1;
    my $buffer = '';
    for my $line (split/\n/mx, $text) {
        chomp($line);
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
        ($current_object, $in_unknown_object, $comments)
            = $self->_parse_line($line, $current_object, $in_unknown_object, $comments, $linenr);
        if(defined $lastline and $lastline ne '' and !defined $object_at_line) {
            if($linenr >= $lastline) {
                $object_at_line = $current_object;
            }
        }
        $linenr++;
    }

    if(defined $current_object or $in_unknown_object) {
        push @{$self->{'errors'}}, "expected end of object in ".$self->{'path'}.":".$.;
    }

    # add trailing comments to last object
    if(defined $comments and scalar @{$comments} > 0) {
        push @{$self->{'objects'}->[scalar @{$self->{'objects'}}-1]->{'comments'}}, @{$comments};
    }

    $self->{'parsed'}  = 1;
    $self->{'changed'} = 1;

    return $object_at_line if defined $lastline;
    return;
}


##########################################################

=head2 _parse_line

parse a single config line

=cut
sub _parse_line {
    my ( $self, $line, $current_object, $in_unknown_object, $comments, $linenr ) = @_;

    chomp($line);

    # strip whitespaces
    StripLTSpace($line);

    # full line comments
    if(substr($line, 0, 1) eq '#' or substr($line, 0, 1) eq ';') {
        push @{$comments}, $line;
        return($current_object, $in_unknown_object, $comments);
    }

    # skip empty lines;
    return($current_object, $in_unknown_object, $comments) if $line eq '';

    # inline comments only with ; not with #
    if($line =~ s/^(.*?)\s*([\;].*)$//gmxo) {
        # remove inline comments
        #push @{$comments}, $2;
        $line = $1;
    }

    $linenr = $. unless defined $linenr;
    $self->{'lines'} = $linenr;

    # new object starts
    if(substr($line, 0, 7) eq 'define ' and $line =~ m/^define\s+(.*?)\s*{/gmxo) {
        $current_object = Monitoring::Config::Object->new(type => $1, file => $self, line => $linenr);
        unless(defined $current_object) {
            push @{$self->{'errors'}}, "unknown object type '".$1."' in ".$self->{'path'}.":".$linenr;
            $in_unknown_object = 1;
            return($current_object, $in_unknown_object, $comments);
        }
    }

    # old object finished
    elsif($line eq '}') {
        unless(defined $current_object) {
            push @{$self->{'errors'}}, "unexpected end of object in ".$self->{'path'}.":".$linenr;
            return($current_object, $in_unknown_object, $comments);
        }
        $current_object->{'comments'} = $comments;
        my $errors = $current_object->parse();
        if(scalar @{$errors} > 0) { push @{$self->{'errors'}}, @{$errors} }
        $current_object->{'id'} = $current_object->_make_id();
        push @{$self->{'objects'}}, $current_object;
        undef $current_object;
        $comments = [];
        $in_unknown_object = 0;
    }

    elsif($in_unknown_object) {
        # silently skip attributes from unknown objects
    }

    # in an object definition
    elsif(defined $current_object) {
        my($key, $value) = split(/\s+/mxo, $line, 2);
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
            if($line =~ /^(.*?)\s+(\d{1,2}:\d{1,2}\-\d{1,2}:\d{1,2}[\d,:\-\s]*)/gmxo) {
                $timedef    = $1;
                $timeranges = $2;
            }
            if(defined $timedef) {
                if(defined $current_object->{'conf'}->{$timedef}) {
                    push @{$self->{'errors'}}, "duplicate attribute $timedef in '".$line."' in ".$self->{'path'}.":".$linenr;
                }
                $current_object->{'conf'}->{$timedef} = $timeranges;
            } else {
                push @{$self->{'errors'}}, "unknown time definition '".$line."' in ".$self->{'path'}.":".$linenr;
            }
        }
        else {
            if(defined $current_object->{'conf'}->{$key}) {
                push @{$self->{'errors'}}, "duplicate attribute $key in '".$line."' in ".$self->{'path'}.":".$linenr;
            }
            $current_object->{'conf'}->{$key} = $value;
        }
    }

    # something totally unknown
    else {
        push @{$self->{'errors'}}, "syntax invalid: '".$line."' in ".$self->{'path'}.":".$linenr;
    }

    return($current_object, $in_unknown_object, $comments);
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
    if(!-f $self->{'path'} or !-r $self->{'path'}) {
        push @{$self->{'errors'}}, "cannot read file: ".$self->{'path'}.": ".$!;
        return $meta;
    }

    # md5 hex
    my $ctx = Digest::MD5->new;
    open(my $fh, $self->{'path'});
    $ctx->addfile($fh);
    $meta->{'md5'} = $ctx->hexdigest;
    close($fh);

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
    my ( $self ) = @_;

    $self->{'errors'} = [];
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
            close($fh);
        } else {
            push @{$self->{'errors'}}, "cannot write to ".$self->{'path'}.": ".$!;
            return;
        }
    }

    unless(-w $self->{'path'}) {
        push @{$self->{'errors'}}, "cannot write to ".$self->{'path'}.": ".$!;
        return;
    }

    if($self->{'deleted'}) {
        unlink($self->{'path'});
        return;
    }

    my $content = $self->_get_new_file_content();
    open(my $fh, '>', $self->{'path'}) or die("cannot write to file: $!");
    print $fh $content;
    close($fh);

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
    my $content         = $self->_get_new_file_content();
    print $fh $content;
    close($fh);

    my $diff = `diff -wuN "$self->{'path'}" "$filename" 2>&1`;

    unlink($filename);
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

=head2 _get_new_file_content

returns the current raw file content

=cut
sub _get_new_file_content {
    my $self        = shift;
    my $new_content = "";

    return $new_content if $self->{'deleted'};

    return read_file($self->{'path'}) unless $self->{'changed'};

    my $linenr = 0;

    # sort by line number, but put line 0 at the end
    for my $obj (sort { $b->{'line'} > 0 <=> $a->{'line'} > 0 || $a->{'line'} <=> $b->{'line'} } @{$self->{'objects'}}) {
        # save comments
        for my $line (@{$obj->{'comments'}}) {
            $line =~ s/^#\s+//gmxo;
            $line =~ s/^;\s+//gmxo;
            unless(substr($line,0,1) eq '#' or substr($line,0,1) eq ';') {
                $line = '# '.$line;
            }
            $line =~ s/\s+$//gmx;
            $new_content .= $line."\n"; $linenr++;
        }

        # save object itself
        $new_content .= "define ".$obj->{'type'}." {\n"; $linenr++;

        # update line number of object
        $obj->{'line'} = $linenr;

        for my $key (@{$obj->get_sorted_keys()}) {
            my $value;
            if(defined $obj->{'default'}->{$key}
                and ($obj->{'default'}->{$key}->{'type'} eq 'LIST'
                  or $obj->{'default'}->{$key}->{'type'} eq 'ENUM'
                )
            ) {
                $value = join(',', @{$obj->{'conf'}->{$key}});
            } else {
                $value = $obj->{'conf'}->{$key};
            }
            # empty values are valid syntax
            $value = '' unless defined $value;
            $new_content .= sprintf "  %-30s %s\n", $key, $value;
            $linenr++
        }
        $new_content .= "}\n\n";
        $linenr += 2;
    }

    return $new_content;
}

##########################################################
# replacement for string::strip, which is broken on 64 bit
# https://rt.cpan.org/Ticket/Display.html?id=70028
sub StripTSpace {
    $_[0] =~ s/\s+$//;
}

##########################################################
sub StripLSpace {
    $_[0] =~ s/^\s+//;
}

##########################################################
sub StripLTSpace {
    $_[0] =~ s/^\s+//;
    $_[0] =~ s/\s+$//;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
