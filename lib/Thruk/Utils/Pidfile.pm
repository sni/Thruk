package Thruk::Utils::Pidfile;

=head1 NAME

Thruk::Utils::Pidfile - Utilities Collection for managing pid files

=head1 DESCRIPTION

Pidfile offers functions to manage pid files.

=cut

use warnings;
use strict;

use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 lock

  lock($c, $pidfile)

returns undef on success or current pid if lock already exists

=cut
sub lock {
    my($c, $pidfile) = @_;
    if(-e $pidfile) {
        my $pid = Thruk::Utils::IO::read($pidfile);
        if($pid && $pid != $$) {
            if($pid && kill(0, $pid)) {
                return($pid);
            }
            _warn("WARNING: removing stale pid file: %s", $pidfile);
            unlink($pidfile);
        }
    }
    Thruk::Utils::IO::write($pidfile, $$);
    _debug("pidfile %s created", $pidfile);
    return;
}

##############################################

=head2 unlock

  unlock($c, $pidfile)

removes pid file

=cut
sub unlock {
    my($c, $pidfile) = @_;
    unlink($pidfile);
    _debug("pidfile %s removed", $pidfile);
    return;
}

##############################################

1;
