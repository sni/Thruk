package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use Fcntl qw/:mode :flock/;
use Thruk::Backend::Pool;
use JSON::XS;
use Encode qw/encode_utf8/;

$Thruk::Utils::IO::config = undef;

##############################################
=head1 METHODS

=head2 close

  close($fh, $filename, $just_close)

close filehandle and ensure permissions and ownership

=cut
sub close {
    my($fh, $filename, $just_close) = @_;
    my $rc = CORE::close($fh);
    ensure_permissions('file', $filename) unless $just_close;
    return $rc;
}

##############################################

=head2 mkdir

  mkdir($dirname)

create folder and ensure permissions and ownership

=cut

sub mkdir {
    for my $dirname (@_) {
        unless(-d $dirname) {
            CORE::mkdir($dirname) or confess("failed to create ".$dirname.": ".$!)
        }
        ensure_permissions('dir', $dirname);
    }
    return 1;
}

##############################################

=head2 mkdir_r

  mkdir_r($dirname)

create folder recursive

=cut

sub mkdir_r {
    for my $dirname (@_) {
        my $path = '';
        for my $part (split/(\/)/mx, $dirname) {
            $path .= $part;
            next if $path eq '';
            Thruk::Utils::IO::mkdir($path) unless -d $path;
        }
    }
    return 1;
}

##############################################

=head2 write

  write($path, $content, [ $mtime ])

creates file and ensure permissions

=cut

sub write {
    my($path,$content,$mtime) = @_;
    open(my $fh, '>', $path) or die('cannot create file '.$path.': '.$!);
    print $fh $content;
    Thruk::Utils::IO::close($fh, $path);
    utime($mtime, $mtime, $path) if $mtime;
    return 1;
}

##############################################

=head2 ensure_permissions

  ensure_permissions($mode, $path)

ensure permissions and ownership

=cut

sub ensure_permissions {
    my($mode, $path) = @_;
    return if defined $ENV{'THRUK_NO_TOUCH_PERM'};

    die("need a path") unless defined $path;
    return unless -e $path;

    my @stat = stat($path);
    my $cur  = sprintf "%04o", S_IMODE($stat[2]);

    $Thruk::Utils::IO::config = Thruk::Backend::Pool::get_config() unless $Thruk::Utils::IO::config;
    my $config = $Thruk::Utils::IO::config;
    # set modes
    if($mode eq 'file') {
        if($cur ne $config->{'mode_file'}) {
            chmod(oct($config->{'mode_file'}), $path)
                or warn("failed to ensure permissions (0660/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn $path`);
        }
    }
    elsif($mode eq 'dir') {
        if($cur ne $config->{'mode_dir'}) {
            chmod(oct($config->{'mode_dir'}), $path)
                or warn("failed to ensure permissions (0770/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn $path`);
        }
    }
    else {
        chmod($mode, $path)
            or warn("failed to ensure permissions (".$mode.") with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn $path`);
    }

    # change owner too if we are root
    my $uid = -1;
    if($> == 0) {
        $uid = $ENV{'THRUK_USER_ID'} or confess('no user id!');
    }

    # change group
    chown($uid, $ENV{'THRUK_GROUP_ID'}, $path) if defined $ENV{'THRUK_GROUP_ID'};
    return;
}

##############################################

=head2 json_lock_store

  json_lock_store($file, $data, [$pretty])

stores data json encoded

=cut

sub json_lock_store {
    my($file, $data, $pretty) = @_;

    my $json = JSON::XS->new->utf8;
    $json = $json->pretty if $pretty;

    open(my $fh, '>', $file) or die('cannot write file '.$file.': '.$!);
    alarm(30);
    local $SIG{'ALRM'} = sub { die("timeout while trying to lock_ex: ".$file); };
    flock($fh, LOCK_EX) or die 'Cannot lock '.$file.': '.$!;
    print $fh $json->encode($data);
    flock($fh, LOCK_UN) or die 'Cannot unlock '.$file.': '.$!;
    alarm(0);
    Thruk::Utils::IO::close($fh, $file);
    return 1;
}

##############################################

=head2 json_lock_retrieve

  json_lock_retrieve($file)

retrieve json data

=cut

sub json_lock_retrieve {
    my($file) = @_;

    my $json = JSON::XS->new->utf8;
    my $data;

    open(my $fh, '<', $file) or die('cannot read file '.$file.': '.$!);
    alarm(30);
    local $SIG{'ALRM'} = sub { die("timeout while trying to lock_sh: ".$file); };
    flock($fh, LOCK_SH) or die 'Cannot lock '.$file.': '.$!;
    while(my $line = <$fh>) {
        $line = encode_utf8($line);
        $json->incr_parse($line);
    }
    $data = $json->incr_parse;
    flock($fh, LOCK_UN) or die 'Cannot unlock '.$file.': '.$!;
    alarm(0);
    CORE::close($fh);
    return $data;
}

##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
