package Thruk::Backend::Provider::Base;

use warnings;
use strict;
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
    my( $class ) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

########################################

=head2 can_use_logcache

  can_use_logcache()

returns true if query can use the logcache

=cut
sub can_use_logcache {
    my($provider, $options) = @_;
    return if $ENV{'THRUK_NOLOGCACHE'};
    return if $options->{'nocache'};
    return if !defined $provider->{'_peer'}->{'logcache'};
    my $c = $Thruk::Globals::c;
    if($c) {
        my $bypass = $c->config->{'logcache_auto_bypass'} // 0;
        if($bypass == 0) {
            return 1;
        }
        require Thruk::Utils;
        my $cleaned = Thruk::Utils::get_expanded_start_date($c, $c->config->{'logcache_clean_duration'});
        my($start, $end) = Thruk::Utils::extract_time_filter($options->{'filter'});
        return 1 if (!defined $start && !defined $end);
        if($bypass == 1) {
            if(($end//$start) >= $cleaned) {
                return 1;
            }
            return;
        }
        if($bypass == 2) {
            if(($start//$end) >= $cleaned) {
                return 1;
            }
            return;
        }
    }
    return 1;
}

##########################################################

=head2 get_logs_start_end_no_filter

  get_logs_start_end_no_filter($peer)

returns date of first and last log entry

=cut
sub get_logs_start_end_no_filter {
    my($peer, $start_at) = @_;
    my($start, $end);

    my @steps = (86400*365, 86400*30, 86400*7, 86400);

    my $time = time();
    for my $step (reverse @steps) {
        (undef, $end) = @{$peer->get_logs_start_end(nocache => 1, filter => [{ time => {'>=' => time() - $step }}])};
        last if $end;
    }

    # fetching logs without any filter is a terrible bad idea
    # try to determine start date, simply requesting min/max without filter parses all logfiles
    # so we try a very early date, since requests with an non-existing timerange are super fast
    # (livestatus has an index on all files with start and end timestamp and only parses the file if it matches)

    $time = $start_at // time() - 86400 * 365 * 10; # assume 10 years as earliest date we want to import, can be overridden by specifing a forcestart anyway
    for my $step (@steps) {
        while($time <= time()) {
            my($data) = $peer->get_logs(nocache => 1, filter => [{ time => { '<=' => $time }}], columns => [qw/time/], options => { limit => 1 });
            if($data && $data->[0]) {
                $time  = $time - $step;
                last;
            }
            $time = $time + $step;
        }
        if($time > time()) {
            $time  = $time - $step;
        }
        $start = $time;
    }
    my($lstart, undef) = @{$peer->get_logs_start_end(nocache => 1, filter => [{ time => {'>=' => $start - 86400 }}, { time => {'<=' => $start + 86400 }}])};
    $start = $lstart if $lstart;

    return($start, $end);
}

##########################################################

=head2 reconnect

recreate database connection

=cut
sub reconnect {
    my($self) = @_;
    confess("unimplemented");
}

##########################################################

=head2 peer_key

return the peers key

=cut

sub peer_key {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 peer_addr

return the peers address

=cut

sub peer_addr {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 peer_name

return the peers name

=cut

sub peer_name {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 send_command

sends a command

=cut

sub send_command {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_processinfo

return the process info

=cut

sub get_processinfo {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_sites

  get_sites

returns a list of lmd sites

=cut

sub get_sites {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut

sub get_can_submit_commands {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut

sub get_contactgroups_by_contact {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut

sub get_commands {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut

sub get_comments {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut

sub get_contactgroups {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut

sub get_contacts {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut

sub get_contact_names {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut

sub get_downtimes {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut

sub get_hostgroups {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut

sub get_hostgroup_names {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut

sub get_hosts {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_hosts_by_servicequery

  get_hosts_by_servicequery

returns a list of host by a services query

=cut

sub get_hosts_by_servicequery {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut

sub get_host_names {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut

sub get_servicegroups {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut

sub get_servicegroup_names {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut

sub get_services {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut

sub get_service_names {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut

sub get_timeperiods {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut

sub get_logs {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns a performance statistics

=cut

sub get_performance_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_extra_perf_stats

  get_extra_perf_stats

returns extra performance statistics

=cut

sub get_extra_perf_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_host_stats

  get_host_stats

returns hosts statistics used in the tac page

=cut

sub get_host_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_host_totals_stats

  get_host_totals_stats

returns the host statistics used on the service/host details page

=cut

sub get_host_totals_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_host_less_stats

  get_host_less_stats

same as get_host_stats but less numbers and therefore faster

=cut
sub get_host_less_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns service statistics used in the tac page

=cut

sub get_service_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_service_totals_stats

  get_service_totals_stats

returns the services statistics used on the service/host details page

=cut

sub get_service_totals_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_service_less_stats

  get_service_less_stats

same as get_service_stats but less numbers and therefore faster

=cut
sub get_service_less_stats {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut

sub set_verbose {
    my $self = shift;
    confess("unimplemented");
}


##########################################################

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    my $self = shift;
    confess("unimplemented");
}

##########################################################

=head2 get_logs_start_end

  get_logs_start_end

returns first and last logfile entry

=cut
sub get_logs_start_end {
    my $self = shift;
    confess("unimplemented");
}

1;
