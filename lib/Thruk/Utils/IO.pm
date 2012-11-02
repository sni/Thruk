package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use Fcntl ':mode';

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

=head2 ensure_permissions

  ensure_permissions($mode, $path)

ensure permissions and ownership

=cut

sub ensure_permissions {
    my($mode, $path) = @_;
    return unless -e $path;

    return if defined $ENV{'THRUK_NO_TOUCH_PERM'};

    my @stat = stat($path);
    my $cur  = sprintf "%04o", S_IMODE($stat[2]);

    # set modes
    if($mode eq 'file') {
        if($cur ne '0660') {
            chmod(0660, $path)
                or warn("failed to ensure permissions (0660/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn $path`);
        }
    }
    elsif($mode eq 'dir') {
        if($cur ne '0770') {
            chmod(0770, $path)
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
    chown($uid, $ENV{'THRUK_GROUP_ID'}, $path);
    return;
}

##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
