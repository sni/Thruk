package Thruk::Backend::Provider::HTTP;

use strict;
use warnings;
use Carp;

=head1 NAME

Thruk::Backend::Provider::DashboardHTTP - connection provider for http connections

=head1 DESCRIPTION

connection provider for http connections

=cut

################################################################

=head1 METHODS

=head2 get_host_stats_dashboard

  get_host_stats_dashboard

returns the host statistics for the dashboard page

=cut
sub get_host_stats_dashboard {
    my($self, @options) = @_;
    my $res = $self->_req('get_host_stats_dashboard', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'SUM');
}

##########################################################

=head2 get_service_stats_dashboard

  get_service_stats_dashboard

returns the services statistics for the dashboard page

=cut
sub get_service_stats_dashboard {
    my($self, @options) = @_;
    my $res = $self->_req('get_service_stats_dashboard', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'SUM');
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=cut

1;
