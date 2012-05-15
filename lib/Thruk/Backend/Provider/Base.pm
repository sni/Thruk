package Thruk::Backend::Provider::Base;

use strict;
use warnings;
use Carp;

=head1 NAME

Thruk::Backend::Provider::Base - Base class for backend connection provider

=head1 DESCRIPTION

Base class for backend connection provider

=head1 METHODS

=cut

##########################################################

=head2 new

create new manager

=cut

sub new {
    my( $class, $c ) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

##########################################################

=head2 reconnect

recreate database connection

=cut
sub reconnect {
    my($self) = @_;
    confess("unimplemented");
    return;
}

##########################################################

=head2 peer_key

return the peers key

=cut

sub peer_key {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 peer_addr

return the peers address

=cut

sub peer_addr {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 peer_name

return the peers name

=cut

sub peer_name {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 send_command

sends a command

=cut

sub send_command {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_processinfo

return the process info

=cut

sub get_processinfo {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut

sub get_can_submit_commands {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut

sub get_contactgroups_by_contact {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut

sub get_commands {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut

sub get_comments {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut

sub get_contactgroups {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut

sub get_contacts {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut

sub get_contact_names {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut

sub get_downtimes {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut

sub get_hostgroups {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut

sub get_hostgroup_names {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut

sub get_hosts {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_hosts_by_servicequery

  get_hosts_by_servicequery

returns a list of host by a services query

=cut

sub get_hosts_by_servicequery {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut

sub get_host_names {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_scheduling_queue

  get_scheduling_queue

returns a list of queued checks

=cut

sub get_scheduling_queue {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut

sub get_servicegroups {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut

sub get_servicegroup_names {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut

sub get_services {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut

sub get_service_names {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut

sub get_timeperiods {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut

sub get_logs {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns a performance statistics

=cut

sub get_performance_stats {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_extra_perf_stats

  get_extra_perf_stats

returns extra performance statistics

=cut

sub get_extra_perf_stats {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_host_stats

  get_host_stats

returns hosts statistics used in the tac page

=cut

sub get_host_stats {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns service statistics used in the tac page

=cut

sub get_service_stats {
    my $self = shift;
    confess("unimplemented");
    return;
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut

sub set_verbose {
    my $self = shift;
    confess("unimplemented");
    return;
}


##########################################################

=head2 set_stash

  set_stash

make stash accessible for the backend

=cut
sub set_stash {
    my $self = shift;
    confess("unimplemented");
    return;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
