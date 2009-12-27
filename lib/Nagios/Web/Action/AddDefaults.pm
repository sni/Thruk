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

    $c->stats->profile(begin => "AddDefaults::before");
#    $c->stash->{'no_auto_reload'} = 0;

    ###############################
    # parse cgi.cfg
    $c->{'cgi_cfg'} = Nagios::Web::Helper->get_cgi_cfg($c);

    ###############################
    # get livesocket object
    $c->{'live'} = Nagios::Web::Helper->get_livestatus($c);

    $c->log->debug("checking auth");
    unless ($c->user_exists) {
        $c->log->debug("user not authenticated yet");
        unless ($c->authenticate( {} )) {
            # return 403 forbidden or kick out the user in other way
            $c->log->debug("user is not authenticated");
            $c->detach('/error/index/10');
        };
    }
    $c->log->debug("user authenticated as: ".$c->user->get('username'));

    ###############################
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    ###############################
    # add program status
    eval {
        my $processinfo = $c->{'live'}->selectall_hashref("GET status\n".Nagios::Web::Helper::get_auth_filter($c, 'status')."\nColumns: livestatus_version program_version accept_passive_host_checks accept_passive_service_checks check_external_commands check_host_freshness check_service_freshness enable_event_handlers enable_flap_detection enable_notifications execute_host_checks execute_service_checks last_command_check last_log_rotation nagios_pid obsess_over_hosts obsess_over_services process_performance_data program_start", 'peer_key', { AddPeer => 1});
        # TODO: replace by correct value
        for my $val (values %{$processinfo}) {
            $val->{'interval_length'} = 60;
        }
        my $overall_processinfo = Nagios::Web::Helper->_calculate_overall_processinfo($processinfo);
        $c->stash->{'pi'}        = $overall_processinfo;
        $c->stash->{'pi_detail'} = $processinfo;
    };
    if($@) {
        $c->detach('/error/index/9');
    }

    ###############################
    my @possible_backends = $c->{'live'}->peer_key();
    my %backend_detail;
    for my $back (@possible_backends) {
        $backend_detail{$back} = {
            "name" => $c->{'live'}->_get_peer_by_key($back)->peer_name(),
            "addr" => $c->{'live'}->_get_peer_by_key($back)->peer_addr(),
        };
    }
    $c->stash->{'backends'}           = \@possible_backends;
    $c->stash->{'backend_detail'}     = \%backend_detail;

    $c->stats->profile(end => "AddDefaults::before");
};

########################################
after 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    $c->stats->profile(begin => "AddDefaults::after");

    if(defined $c->{'cgi_cfg'}->{'refresh_rate'} and (!defined $c->stash->{'no_auto_reload'} or $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->{'cgi_cfg'}->{'refresh_rate'};
        $c->response->headers->header('refresh' => $c->{'cgi_cfg'}->{'refresh_rate'})
    }

    $c->stats->profile(end => "AddDefaults::after");
};

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
