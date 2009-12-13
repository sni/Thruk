package Nagios::Web::Action::AddDefaults;

=head1 NAME

Nagios::Web::Action::AddDefaults - Add Defaults to the context

=head1 DESCRIPTION

loads cgi.cfg

creates MKLivestatus object

=head1 METHODS

=cut

=head2 index

=cut

use strict;
use warnings;
use Moose;
use Carp;
use Nagios::Web::Helper;

extends 'Catalyst::Action';

########################################
before 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    ###############################
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    ###############################
    # add program status
    my $processinfo = $c->{'live'}->selectrow_hashref("GET status\nColumns: program_version accept_passive_host_checks accept_passive_service_checks check_external_commands check_host_freshness check_service_freshness enable_event_handlers enable_flap_detection enable_notifications execute_host_checks execute_service_checks last_command_check last_log_rotation nagios_pid obsess_over_hosts obsess_over_services process_performance_data program_start");
    $c->stash->{'pi'} = $processinfo;

    $c->stash->{'page'} = 'status'; # set a default page, so at least some css is loaded
};

########################################
after 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;
    if(defined $c->{'cgi_cfg'}->{'refresh_rate'} and (!defined $c->stash->{'no_auto_reload'} or $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->{'cgi_cfg'}->{'refresh_rate'};
        $c->response->headers->header('refresh' => $c->{'cgi_cfg'}->{'refresh_rate'})
    }
};

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
