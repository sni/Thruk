package FCGI::ProcManager::MaxRequests;
use strict;

use base 'FCGI::ProcManager';

our $VERSION = '0.02';

sub new {
    my $proto = shift;
    my $self = $proto->SUPER::new(@_);
    $self->{max_requests} = $ENV{PM_MAX_REQUESTS} || 0 unless defined $self->{max_requests};
    return $self;
}

sub max_requests { shift->pm_parameter('max_requests', @_); }

sub handling_init {
    my $self = shift;
    $self->SUPER::handling_init();
    $self->{_request_counter} = $self->max_requests;
}

sub pm_post_dispatch {
    my $self = shift;
    if ($self->max_requests > 0 && --$self->{_request_counter} == 0) {
        #$self->pm_exit("safe exit after max_requests");
        $self->pm_exit();
    }
    $self->SUPER::pm_post_dispatch();
}

=head1 NAME

FCGI::ProcManager::MaxRequests - restrict max number of requests by each child

=head1 SYNOPSIS

Usage same as FCGI::ProcManager:

    use CGI::Fast;
    use FCGI::ProcManager::MaxRequests;

    my $m = FCGI::ProcManager::MaxRequests->new({
        n_processes => 10,
        max_requests => 100,
    });
    $m->manage;

    while( my $cgi = CGI::Fast->new() ) {
        $m->pm_pre_dispatch();
        ...
        $m->pm_post_dispatch();
    }

=head1 DESCRIPTION

FCGI-ProcManager-MaxRequests is a extension of FCGI-ProcManager that allow
restrict fastcgi processes to process only limiting number of requests.
This may help avoid growing memory usage and compensate memory leaks.

This module subclass L<FCGI::ProcManager>. After server process max_requests
number of requests, it simple exit, and manager starts another server process.
Maximum number of requests can be set from PM_MAX_REQUESTS environment variable,
max_requests - constructor argument and max_requests accessor.

=head1 OVERLOADED METHODS

=head2 new

    my $pm = FCGI::ProcManager::MaxRequests->new(\%args);

Constructs new proc manager object.

=head2 max_requests

    $pm->max_requests($max_requests);
    my $max_requests = $pm->max_requests;

Set/get current max_requests value.

=head2 handling_init

Initialize requests counter after new worker process forks.

=head2 pm_post_dispatch

Do all work. Decrements requests counter after each request and exit worker when needed.

=head1 USING WITH CATALYST

At this time, L<Catalyst::Engine::FastCGI> do not allow set any args to FCGI::ProcManager subclass constructor.
Because of this we should use environment PM_MAX_REQUESTS ;-)

    PM_MAX_REQUESTS=100 ./script/myapp_fastcgi.pl -n 10 -l <host>:<port> -d -M FCGI::ProcManager::MaxRequests


=head1 SEE ALSO

You can also see L<FCGI::Spawn>, but it don't support TCP sockets and try use CGI::Fast...

=head1 AUTHOR

Vladimir Timofeev, C<< <vovkasm at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-fcgi-procmanager-maxrequests at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=FCGI-ProcManager-MaxRequests>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc FCGI::ProcManager::MaxRequests

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=FCGI-ProcManager-MaxRequests>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/FCGI-ProcManager-MaxRequests>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/FCGI-ProcManager-MaxRequests>

=item * Search CPAN

L<http://search.cpan.org/dist/FCGI-ProcManager-MaxRequests/>

=item * Source code repository

L<http://svn.vovkasm.org/FCGI-ProcManager-MaxRequests>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 Vladimir Timofeev.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

