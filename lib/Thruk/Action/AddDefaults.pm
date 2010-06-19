package Thruk::Action::AddDefaults;

=head1 NAME

Thruk::Action::AddDefaults - Add Defaults to the context

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
use Data::Dumper;

extends 'Catalyst::Action';

########################################
before 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    $c->stats->profile(begin => "AddDefaults::before");

    ###############################
    $c->stash->{'version'} = Thruk->config->{'version'};

    ###############################
    # parse cgi.cfg
    Thruk::Utils::read_cgi_cfg($c);

    ###############################
    # Authentication
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
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    ###############################
    # get livesocket object
    my %disabled_backends;
    my $nr_disabled = 0;
    if(defined $c->request->cookie('thruk_backends')) {
        for my $val (@{$c->request->cookie('thruk_backends')->{'value'}}) {
            my($key, $value) = split/=/mx, $val;
            next unless defined $value;
            $disabled_backends{$key} = $value;
            $nr_disabled++ if $value == 2;
        }
    }
    elsif(defined $c->{'live'}) {
        my $livestatus_config = $c->{'live'}->get_livestatus_conf();
        $c->log->debug("livestatus config: ".Dumper($livestatus_config));
        for my $peer (@{$livestatus_config->{'peer'}}) {
            if(defined $peer->{'hidden'} and $peer->{'hidden'} == 1) {
                $disabled_backends{$peer->{'peer'}} = 2;
                $nr_disabled++;
            }
        }
    }

    ###############################
    # disable backends by groups
    if(defined $c->{'live'}) {
        my $contactgroups_by_contact = {};
        my $data = $c->{'live'}->selectall_arrayref("GET contactgroups\nColumns: name members", { Slice => 1 } );
        for my $group (@{$data}) {
            next unless defined $group->{'members'};
            for my $contact (split /,/mx, $group->{'members'}) {
                $contactgroups_by_contact->{$contact}->{$group->{'name'}} = 1;
            }
        }
        my $livestatus_config = $c->{'live'}->get_livestatus_conf();
        for my $peer (@{$livestatus_config->{'peer'}}) {
            if(defined $peer->{'groups'}) {
                $disabled_backends{$peer->{'peer'}} = 3;    # completly hidden
                $nr_disabled++;
                for my $group (split/\s*,\s*/mx, $peer->{'groups'}) {
                    if(defined $contactgroups_by_contact->{$c->user->get('username')}->{$group}) {
                        $c->log->debug("found contact ".$c->user->get('username')." in contactgroup ".$group);
                        delete $disabled_backends{$peer->{'peer'}};
                        $nr_disabled--;
                        last;
                    }
                }
            }
        }
    }

    if(defined $c->{'live'}) {
        $c->{'live'}->_disable_backends(\%disabled_backends);
    }
    my $backend  = $c->{'request'}->{'parameters'}->{'backend'};
    $c->stash->{'param_backend'}  = $backend;

    ###############################
    my @possible_backends = $c->{'live'}->peer_key();
    my %backend_detail;
    my @new_possible_backends;
    for my $back (@possible_backends) {
        if($disabled_backends{$back} != 3) {
            $backend_detail{$back} = {
                "name"     => $c->{'live'}->_get_peer_by_key($back)->peer_name(),
                "addr"     => $c->{'live'}->_get_peer_by_key($back)->peer_addr(),
                "disabled" => $disabled_backends{$back} || 0,
            };
            push @new_possible_backends, $back;
        }
    }
    $c->stash->{'backends'}           = \@new_possible_backends;
    $c->stash->{'backend_detail'}     = \%backend_detail;

    ###############################
    $c->stash->{'escape_html_tags'}   = $c->config->{'cgi_cfg'}->{'escape_html_tags'};
    $c->stash->{'show_context_help'}  = $c->config->{'cgi_cfg'}->{'show_context_help'};

    ###############################
    # add program status
    # this is also the first query on every page, so do the
    # backend availability checks here
    $c->stats->profile(begin => "AddDefaults::get_proc_info");
    eval {
        my $processinfo          = $c->{'live'}->selectall_hashref("GET status\n".Thruk::Utils::Auth::get_auth_filter($c, 'status')."\nColumns: livestatus_version program_version accept_passive_host_checks accept_passive_service_checks check_external_commands check_host_freshness check_service_freshness enable_event_handlers enable_flap_detection enable_notifications execute_host_checks execute_service_checks last_command_check last_log_rotation nagios_pid obsess_over_hosts obsess_over_services process_performance_data program_start interval_length", 'peer_key', { AddPeer => 1});
        my $overall_processinfo  = Thruk::Utils::calculate_overall_processinfo($processinfo);
        $c->stash->{'pi'}        = $overall_processinfo;
        $c->stash->{'pi_detail'} = $processinfo;

        # check our backends uptime
        if(defined $c->config->{'delay_pages_after_backend_reload'} and $c->config->{'delay_pages_after_backend_reload'} > 0) {
            my $delay_pages_after_backend_reload = $c->config->{'delay_pages_after_backend_reload'};
            for my $backend (keys %{$processinfo}) {
                my $delay = int($processinfo->{$backend}->{'program_start'} + $delay_pages_after_backend_reload - time());
                if($delay > 0) {
                    $c->log->debug("delaying page delivery by $delay seconds...");
                    sleep($delay);
                }
            }
        }
    };
    if($@) {
        $c->log->error("livestatus error: $@");
        $c->detach('/error/index/9');
    }
    if(!defined $c->stash->{'pi_detail'} and $nr_disabled < scalar @possible_backends) {
        $c->log->error("got no result from any enabled backend, please check backend connection and logfiles");
        $c->detach('/error/index/9');
    }
    $c->stats->profile(end => "AddDefaults::get_proc_info");

    ###############################
    # set some more roles
    Thruk::Utils::set_can_submit_commands($c);

    ###############################

    $c->stash->{'info_popup_event_type'} = $c->config->{'info_popup_event_type'} || 'onmouseover';

    ###############################
    $c->stats->profile(end => "AddDefaults::before");
};

########################################
after 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    $c->stats->profile(begin => "AddDefaults::after");

    if(defined $c->config->{'cgi_cfg'}->{'refresh_rate'} and (!defined $c->stash->{'no_auto_reload'} or $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->config->{'cgi_cfg'}->{'refresh_rate'};
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
