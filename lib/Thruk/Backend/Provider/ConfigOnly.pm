package Thruk::Backend::Provider::ConfigOnly;

use strict;
use warnings;
use Carp;

=head1 NAME

Thruk::Backend::Provider::ConfigOnly - ConfigOnly backend class

=head1 DESCRIPTION

ConfigOnly backend class

=head1 METHODS

=cut

##########################################################

=head2 new

create new manager

=cut

sub new {
    my( $class, $peer_config, $config, $log ) = @_;
    my $self = {
        'key'   => '',
        'name'  => $peer_config->{'name'},
        'addr'  => '',
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head2 peer_key

return the peers key

=cut

sub peer_key {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'key'} = $new_val;
    }
    return $self->{'key'};
}

##########################################################

=head2 peer_addr

return the peers address

=cut

sub peer_addr {
    my($self) = @_;
    return '';
}

##########################################################

=head2 peer_name

return the peers name

=cut

sub peer_name {
    my($self) = @_;
    return $self->{'name'};
}

##########################################################

=head2 reconnect

recreate database connection

=cut
sub reconnect {
    return;
}

##########################################################

=head2 send_command

sends a command

=cut

sub send_command {
    return;
}

##########################################################

=head2 get_processinfo

return the process info

=cut

sub get_processinfo {
    return;
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut

sub get_can_submit_commands {
    return;
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut

sub get_contactgroups_by_contact {
    return;
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut

sub get_commands {
    return;
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut

sub get_comments {
    return;
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut

sub get_contactgroups {
    return;
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut

sub get_contacts {
    return;
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut

sub get_contact_names {
    return;
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut

sub get_downtimes {
    return;
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut

sub get_hostgroups {
    return;
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut

sub get_hostgroup_names {
    return;
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut

sub get_hosts {
    return;
}

##########################################################

=head2 get_hosts_by_servicequery

  get_hosts_by_servicequery

returns a list of host by a services query

=cut

sub get_hosts_by_servicequery {
    return;
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut

sub get_host_names {
    return;
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut

sub get_servicegroups {
    return;
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut

sub get_servicegroup_names {
    return;
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut

sub get_services {
    return;
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut

sub get_service_names {
    return;
}

##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut

sub get_timeperiods {
    return;
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    return;
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut

sub get_logs {
    return;
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns a performance statistics

=cut

sub get_performance_stats {
    return;
}

##########################################################

=head2 get_extra_perf_stats

  get_extra_perf_stats

returns extra performance statistics

=cut

sub get_extra_perf_stats {
    return;
}

##########################################################

=head2 get_host_stats

  get_host_stats

returns hosts statistics used in the tac page

=cut

sub get_host_stats {
    return;
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns service statistics used in the tac page

=cut

sub get_service_stats {
    return;
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut

sub set_verbose {
    return;
}


##########################################################

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    return;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
