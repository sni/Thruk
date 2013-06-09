package FCGI::ProcManager::MaxRequestsThruk;
use parent 'FCGI::ProcManager::MaxRequests';

use strict;

our $VERSION = '0.01';

=head2 pm_post_dispatch

 MaxRequests.pm

=cut

sub pm_post_dispatch {
    my $self = shift;
    if ($self->max_requests > 0 && --$self->{_request_counter} == 0) {
        $self->pm_exit();
    }
    return $self->SUPER::pm_post_dispatch();
}

=head2 pm_exit

 pm_exit()

DESCRIPTION:

=cut

sub pm_exit {
  my ($this,$msg,$n) = FCGI::ProcManager::self_or_default(@_);
  $n ||= 0;

  # if we still have children at this point, something went wrong.
  # SIGKILL them now.
  kill "KILL", keys %{$this->{PIDS}} if $this->{PIDS};

  $this->pm_warn($msg) if defined $msg;
  $@ = $msg;
  exit $n;
}


=head1 NAME

FCGI::ProcManager::MaxRequestsThruk - patched version of FCGI::ProcManager::MaxRequests

=head1 SYNOPSIS

Usage same as FCGI::ProcManager::MaxRequests

the verbose logging has been removed

=head1 DESCRIPTION

See FCGI::ProcManager::MaxRequests

=cut

1;

