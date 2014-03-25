package Thruk::BP::Functions;

use strict;
use warnings;

use Carp;

=head1 NAME

Thruk::BP::Functions - functions used to calculate business processes

=head1 DESCRIPTION

functions used to calculate business processes

=head1 METHODS

=cut

##########################################################

=head2 status

    status($c, $bp, $n, \@($hostname, $description), \%livedata)

returns status based on real service or host

=cut
sub status {
    my($c, $bp, $n, $args, $livedata) = @_;
    my($hostname, $description) = @{$args};
    my $data;

    $livedata = $bp->bulk_fetch_live_data($c) unless defined $livedata;

    if($hostname and $description) {
        $data = $livedata->{'services'}->{$hostname}->{$description};
    }
    elsif($hostname) {
        $data = $livedata->{'hosts'}->{$hostname};
    }

    # only hard states?
    if($data and $bp->{'state_type'} eq 'hard' and $data->{'state_type'} != 1) {
        return($data->{'last_hard_state'},
               ($n->{'status_text'} || 'no plugin output yet'), # return last status text
               undef,
               {'last_state_change' => $data->{'last_hard_state_change'}}
        );
    }

    if($data) {
        return($data->{'state'}, $data->{'plugin_output'}, undef, $data);
    }
    if($description) {
        return(3, 'no such service');
    }
    return(3, 'no such host');
}

##########################################################

=head2 groupstatus

    groupstatus($c, $bp, $n, [$args: $hostgroup, $servicegroup], [$hostgroupdata], [$servicegroupdata])

returns status based on real service or host

=cut
sub groupstatus {
    my($c, $bp, $n, $args, $livedata) = @_;
    my($grouptype, $groupname, $hostwarn, $hostcrit, $servicewarn, $servicecrit) = @{$args};
    $livedata = $bp->bulk_fetch_live_data($c) unless defined $livedata;

    my $data;
    if(lc($grouptype) eq 'hostgroup') {
        $data = $livedata->{'hostgroups'}->{$groupname};
    } else {
        $data = $livedata->{'servicegroups'}->{$groupname};
    }
    return(3, 'no such '.$grouptype) unless $data;

    my($total_hosts, $good_hosts, $down_hosts) = (0,0,0);
    if(lc($grouptype) eq 'hostgroup') {
        $total_hosts = $data->{'num_hosts'};
        $good_hosts  = $data->{'num_hosts_up'}   + $data->{'num_hosts_pending'};
        $down_hosts  = $data->{'num_hosts_down'} + $data->{'num_hosts_unreach'};
    }

    my($total_services, $good_services, $down_services) = ($data->{'num_services'},0,0);
    $good_services  = $data->{'num_services_ok'}   + $data->{'num_services_pending'} + $data->{'num_services_warn'};
    $down_services  = $data->{'num_services_crit'} + $data->{'num_services_unknown'};

    my $perfdata = 'services_up='.$good_services.' services_down='.$down_services;
    if(lc($grouptype) eq 'hostgroup') {
        $perfdata = 'hosts_up='.$good_hosts.' hosts_down='.$down_hosts.' '.$perfdata;
    }

    my $status = 0;
    my $output = "";
    my $have_threshold = 0;
    if(lc($grouptype) eq 'hostgroup') {
        if(defined $hostwarn and $hostwarn ne '') {
            $have_threshold = 1;
            if($hostwarn =~ m/^(\d+)%$/mx) { $hostwarn = $total_hosts / 100 * $1; }
            if($hostwarn !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - host warning threshold must be numeric"; }
            if($down_hosts >= $hostwarn) {
                $status = 1;
            }
        }
        if(defined $hostcrit and $hostcrit ne '') {
            $have_threshold = 1;
            if($hostcrit =~ m/^(\d+)%$/mx) { $hostcrit = $total_hosts / 100 * $1; }
            if($hostcrit !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - host critical threshold must be numeric"; }
            if($down_hosts >= $hostcrit) {
                $status = 2;
            }
        }
    }
    if(defined $servicewarn and $servicewarn ne '') {
        $have_threshold = 1;
        if($servicewarn =~ m/^(\d+)%$/mx) { $servicewarn = $total_services / 100 * $1; }
        if($servicewarn !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - service warning threshold must be numeric"; }
        if($down_services >= $servicewarn) {
            $status = 1 unless $status > 1;
        }
    }
    if(defined $servicecrit and $servicecrit ne '') {
        $have_threshold = 1;
        if($servicecrit =~ m/^(\d+)%$/mx) { $servicecrit = $total_services / 100 * $1; }
        if($servicecrit !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - service critical threshold must be numeric"; }
        if($down_services >= $servicecrit) {
            $status = 2;
        }
    }
    if(!$have_threshold) {
        if(lc($grouptype) eq 'hostgroup') {
            $status = 2 if $data->{'worst_host_state'} > 0;
        }
        $status = $data->{'worst_service_state'} if $status < $data->{'worst_service_state'};
    }

    my $hostoutput = "";
    if(lc($grouptype) eq 'hostgroup') {
        $hostoutput = sprintf("%d/%d hosts up, ", $good_hosts, $total_hosts);
    }

    $output = sprintf("%s - %s%d/%d services up|%s",
                            Thruk::BP::Utils::state2text($status),
                            $hostoutput,
                            $good_services, $total_services,
                            $perfdata) unless $output;

    return($status, $groupname.' ('.$grouptype.')', $output);
}

##########################################################

=head2 fixed

    fixed($c, $bp, $n, [$args: $status, [$text]])

returns fixed status based input

=cut
sub fixed {
    my($c, $bp, $n, $args) = @_;
    my($status, $text) = @{$args};
    $status = lc $status;
    if($status eq '2' or $status eq 'critical' or $status eq 'down') {
        return(2, 'fixed', $text || 'CRITICAL');
    }
    if($status eq '1' or $status eq 'warning') {
        return(1, 'fixed', $text || 'WARNING');
    }
    if($status eq '0' or $status eq 'ok') {
        return(0, 'fixed', $text || 'OK');
    }
    return(3, 'fixed', $text || 'UNKNOWN');
}

##########################################################

=head2 worst

    worst($c, $bp, $n)

returns worst state of all dependent nodes

=cut
sub worst {
    my($c, $bp, $n) = @_;
    my $states = _get_nodes_grouped_by_state($n, $bp);
    if(scalar keys %{$states} == 0) {
        return(3, 'no dependent nodes');
    }
    my @sorted = reverse sort keys %{$states};
    my $state = $sorted[0];
    $state = 0 if $state == -1;
    return($state, 'worst of', Thruk::BP::Utils::state2text($state).' - Worst state is '.Thruk::BP::Utils::state2text($state).': '.Thruk::BP::Utils::join_labels($states->{$state}));
}

##########################################################

=head2 best

    best($c, $bp, $n)

returns best state of all dependent nodes

=cut
sub best {
    my($c, $bp, $n) = @_;
    my $states = _get_nodes_grouped_by_state($n, $bp);
    if(scalar keys %{$states} == 0) {
        return(3, 'no dependent nodes');
    }
    my @sorted = sort keys %{$states};
    my $state = $sorted[0];
    $state = 0 if $state == -1;
    return($state, 'best of', Thruk::BP::Utils::state2text($state).' - Best state is '.Thruk::BP::Utils::state2text($state).': '.Thruk::BP::Utils::join_labels($states->{$state}));
}

##########################################################

=head2 at_least

    at_least($c, $bp, $n, [$args: $critical])
    at_least($c, $bp, $n, [$args: $warning, $critical])

returns state if thresholds are reached

=cut
sub at_least {
    my($c, $bp, $n, $args) = @_;
    my($warning, $critical) = @{$args};
    $critical = $warning unless defined $critical;
    my($good, $bad) = _count_good_bad($n->{'depends'});
    my $state = 0;
    if($good <= $critical) {
        $state = 2;
    }
    elsif($good <= $warning) {
        $state = 1;
    }
    my $desc = '>= '.$warning.','.$critical;
    if($warning == $critical) {
        $desc = '>= '.$critical;
    }
    return($state, $desc, Thruk::BP::Utils::state2text($state).' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 not_more

    not_more($c, $bp, $n, [$args: $critical])
    not_more($c, $bp, $n, [$args: $warning, $critical])

returns state if thresholds are reached

=cut
sub not_more {
    my($c, $bp, $n, $args) = @_;
    my($warning, $critical) = @{$args};
    my($good, $bad) = _count_good_bad($n->{'depends'});
    my $state = 0;
    if($good > $critical) {
        $state = 2;
    }
    elsif($good > $warning) {
        $state = 1;
    }

    my $desc = '<= '.$warning.','.$critical;
    if($warning == $critical) {
        $desc = '<= '.$critical;
    }
    return($state, $desc, Thruk::BP::Utils::state2text($state).' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 equals

    equals($c, $bp, $n, [$args: $number])

returns number of good nodes matches the number

=cut
sub equals {
    my($c, $bp, $n, $args) = @_;
    my($number) = @{$args};
    my($good, $bad) = _count_good_bad($n->{'depends'});
    if($good == 0 and $bad == 0) {
        return(3, 'no dependent nodes');
    }
    my $state = 2;
    if($good == $number) {
        $state = 0;
    }
    return($state, '= '.$number, Thruk::BP::Utils::state2text($state).' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 random

    random($c, $bp, $n)

returns random state

=cut
sub random {
    my($c, $bp, $n) = @_;
    my $state = int(rand(4));
    return($state, 'random', Thruk::BP::Utils::state2text($state).' - Random state is '.Thruk::BP::Utils::state2text($state));
}

##########################################################

=head2 custom

    custom($c, $bp, $n, $args, \%livedata)

returns data from custom functions

=cut
sub custom {
    my($c, $bp, $n, $args, $livedata) = @_;
    my($status, $short_desc, $status_text, $extra) = (0, 'short desc', 'status text', {});
    $c->stash->{'bp_custom_functions'} = Thruk::BP::Utils::get_custom_functions($c) unless defined $c->stash->{'bp_custom_functions'};
    my($fname, $arg) = @{$args};
    my $f;
    for my $tmp (@{$c->stash->{'bp_custom_functions'}}) {
        if($tmp->{'function'} eq $fname) {
            $f = $tmp;
            last;
        }
    }
    if(!$f) {
        return(3, "UNKNOWN", "no file found for custom function: $fname");
    }
    eval {
        do($f->{'file'});
        ## no critic
        eval('($status, $short_desc, $status_text, $extra) = '."$fname".'($c, $bp, $n, $arg, $livedata);');
        ## use critic
        if($@) {
            $status      = 3;
            $short_desc  = "UNKNOWN";
            $status_text = $@;
            $c->log->info("internal error in custum function $fname: $@");
        }
    };
    if($@) {
        $status      = 3;
        $short_desc  = "UNKNOWN";
        $status_text = $@;
        $c->log->info("internal error in custum function $fname: $@");
    }
    return($status, $short_desc, $status_text, $extra);
}

##########################################################
sub _get_nodes_grouped_by_state {
    my($n, $bp) = @_;
    my $states = {};
    for my $d (@{$n->{'depends'}}) {
        my $state = defined $d->{'status'} ? $d->{'status'} : 4;
        $state = -1 if $state == 4; # make sorting easier
        $states->{$state} = [] unless defined $states->{$state};
        push @{$states->{$state}}, $d;
    }
    return($states);
}

##########################################################
sub _count_good_bad {
    my($depends) = @_;
    my($good, $bad) = (0,0);
    for my $d (@{$depends}) {
        if($d->{'status'} == 0 or $d->{'status'} == 4) {
            $good++;
        } else {
            $bad++;
        }
    }
    return($good, $bad);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
