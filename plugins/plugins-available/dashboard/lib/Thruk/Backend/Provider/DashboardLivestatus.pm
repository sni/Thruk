################################################################
#                     SIGMA Informatique
################################################################
#
# AUTEUR :    SIGMA INFORMATIQUE
#
# OBJET  :    Dashboard plugin
#
# DESC   :    Add news function for get hostgroups and servicegroups Stats
#
#
################################################################
# Copyright © 2011 Sigma Informatique. All rights reserved.
# Copyright © 2010 Thruk Developer Team.
# Copyright © 2009 Nagios Core Development Team and Community Contributors.
# Copyright © 1999-2009 Ethan Galstad.
################################################################

package Thruk::Backend::Provider::Livestatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Monitoring::Livestatus::Class;
use Thruk::Utils;
use Thruk::Backend::Provider::Livestatus;

=head1 NAME

Thruk::Backend::Provider::Livestatus - connection provider for livestatus connections

=head1 DESCRIPTION

connection provider for livestatus connections

=head1 METHODS

=cut
##########################################################


###############
# START SIGMA #
###############

=head2 get_host_stats_dashboard

  get_host_stats_dashboard

returns the host statistics for the dashboard page

=cut
sub get_host_stats_dashboard {
   my($self, %options) = @_;

 my $stats = [
        'total'                               => { -isa => { -and => [ 'has_been_checked' => 1 ]}},
        'scheduled'                           => { -isa => { -and => [ 'has_been_checked' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'acknowledged'                        => { -isa => { -and => [ 'has_been_checked' => 1, 'acknowledged' => 1 ]}},
        'flapping'                            => { -isa => { -and => [ 'has_been_checked' => 1, 'is_flapping' => 1 ]}},
        'up'                                  => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0 ]}},
        'up_and_scheduled'                    => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'down'                                => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1 ]}},
        'down_and_no_scheduled'               => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'scheduled_downtime_depth' => 0 ]}},
        'down_ack_and_no_scheduled'           => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0 ]}},
        'down_ack_and_scheduled'              => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'down_no_ack_and_no_scheduled'        => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
        'down_no_ack_and_scheduled'           => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'unreachable'                         => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2 ]}},
        'unreachable_and_no_scheduled'        => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'scheduled_downtime_depth' => 0 ]}},
        'unreachable_ack_and_no_scheduled'    => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0 ]}},
        'unreachable_ack_and_scheduled'       => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'unreachable_no_ack_and_no_scheduled' => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
        'unreachable_no_ack_and_scheduled'    => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'outages'                             => { -isa => { -and => [ 'state' => 1, 'childs' => {'!=' => undef } ]}},
    ];

    my $class = $self->_get_class('hosts', \%options);

    my $rows = $class->stats($stats)->hashref_array();

    unless(wantarray) {
        confess("get_host_stats() should not be called in scalar context");
    }
    return(\%{$rows->[0]}, 'SUM');
}

##########################################################

=head2 get_service_stats_dashboard

  get_service_stats_dashboard

returns the services statistics for the dashboard page

=cut
sub get_service_stats_dashboard {
    my($self, %options) = @_;

    my $stats = [
        'total'                                 => { -isa => { -and => [ 'has_been_checked' => 1 ]}},
        'scheduled'                             => { -isa => { -and => [ 'has_been_checked' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'acknowledged'                          => { -isa => { -and => [ 'has_been_checked' => 1, 'acknowledged' => 1 ]}},
        'ok'                                    => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0 ]}},
        'ok_no_scheduled_and_host_scheduled'    => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'ok_scheduled_and_host_no_scheduled'    => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0 }, 'host_scheduled_downtime_depth' => 0 ]}},
        'ok_scheduled'                          => { -isa => { -or  => [
                                                                          { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0}, 'host_scheduled_downtime_depth' => 0 ]},
                                                                          { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]},
                                                                       ]}},
        'warning'                                       => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1 ]}},
        'warning_no_scheduled_and_host_scheduled'       => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'w_ack_no_scheduled_and_host_no_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
        'w_ack_no_scheduled_and_host_scheduled'         => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'w_ack_and_scheduled'                           => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'w_no_ack_no_scheduled_and_host_no_scheduled'   => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
        'w_no_ack_no_scheduled_and_host_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'w_no_ack_and_scheduled'                        => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'warning_scheduled'                             => { -isa => { -or  => [
                                                                                  { -and => [ 'has_been_checked' => 1, 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0}, 'host_scheduled_downtime_depth' => 0 ]},
                                                                                  { -and => [ 'has_been_checked' => 1, 'state' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]},
                                                                               ]}},
        'critical'                                      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2 ]}},
        'critical_no_scheduled_and_host_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'c_ack_no_scheduled_and_host_no_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
        'c_ack_no_scheduled_and_host_scheduled'         => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'c_ack_and_scheduled'                           => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'c_no_ack_no_scheduled_and_host_no_scheduled'   => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
        'c_no_ack_no_scheduled_and_host_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'c_no_ack_and_scheduled'                        => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'critical_scheduled'                            => { -isa => { -or  => [
                                                                                  { -and => [ 'has_been_checked' => 1, 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0}, 'host_scheduled_downtime_depth' => 0 ]},
                                                                                  { -and => [ 'has_been_checked' => 1, 'state' => 2, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]},
                                                                               ]}},
        'unknown'                                       => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3 ]}},
        'unknown_no_scheduled_and_host_scheduled'       => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'u_ack_no_scheduled_and_host_no_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
        'u_ack_no_scheduled_and_host_scheduled'         => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'u_ack_and_no_scheduled'                        => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 1, 'scheduled_downtime_depth' => 0 ]}},
        'u_ack_and_scheduled'                           => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'u_no_ack_no_scheduled_and_host_no_scheduled'   => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
        'u_no_ack_no_scheduled_and_host_scheduled'      => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]}},
        'u_no_ack_and_scheduled'                        => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
        'unknown_scheduled'                             => { -isa => { -or  => [
                                                                                  { -and => [ 'has_been_checked' => 1, 'state' => 3, 'scheduled_downtime_depth' => { '>' => 0}, 'host_scheduled_downtime_depth' => 0 ]},
                                                                                  { -and => [ 'has_been_checked' => 1, 'state' => 3, 'scheduled_downtime_depth' => 0, 'host_scheduled_downtime_depth' => { '>' => 0 } ]},
                                                                               ]}},
    ];

    my $class = $self->_get_class('services', \%options);
    my $rows = $class->stats($stats)->hashref_array();

    unless(wantarray) {
        confess("get_service_stats() should not be called in scalar context");
    }
    return(\%{$rows->[0]}, 'SUM');
}

#############
# END SIGMA #
#############
##########################################################


1;
