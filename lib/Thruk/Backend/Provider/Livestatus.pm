package Thruk::Backend::Provider::Livestatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Monitoring::Livestatus::Class;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::Livestatus - connection provider for livestatus connections

=head1 DESCRIPTION

connection provider for livestatus connections

=head1 METHODS

=cut
##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $config ) = @_;
    my $self = {
        'live' => Monitoring::Livestatus::Class->new($config),
    };
    bless $self, $class;

    return $self;
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my $self = shift;
    return $self->{'live'}->{'backend_obj'}->peer_key();
}


##########################################################

=head2 peer_addr

return the peers address

=cut
sub peer_addr {
    my $self = shift;
    return $self->{'live'}->{'backend_obj'}->peer_addr();
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my $self = shift;
    return $self->{'live'}->table('status')->columns(qw/livestatus_version
                                                            program_version
                                                            accept_passive_host_checks
                                                            accept_passive_service_checks
                                                            check_external_commands
                                                            check_host_freshness
                                                            check_service_freshness
                                                            enable_event_handlers
                                                            enable_flap_detection
                                                            enable_notifications
                                                            execute_host_checks
                                                            execute_service_checks
                                                            last_command_check
                                                            last_log_rotation
                                                            nagios_pid
                                                            obsess_over_hosts
                                                            obsess_over_services
                                                            process_performance_data
                                                            program_start
                                                            interval_length
                                                          /)->hashref_hash('peer_key');
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut
sub get_can_submit_commands {
    my $self = shift;
    my $user = shift;
    confess("no user") unless defined $user;
    return $self->{'live'}->table('contacts')->columns(qw/can_submit_commands alias/)->filter({ name => $user })->hashref_array();
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut
sub get_contactgroups_by_contact {
    my($self,$username) = @_;

    my $contactgroups = {};
    my $data = $self->{'live'}->table('contactgroups')->columns(qw/name/)->filter({ members => { '>=' => $username }})->hashref_array();
    for my $group (@{$data}) {
        $contactgroups->{$group->{'name'}} = 1;
    }

    return $contactgroups;
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
