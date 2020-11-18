package Thruk::BP::Functions;

use strict;
use warnings;
use Thruk::Utils::Log qw/:all/;

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
    my($hostname, $description, $op) = @{$args};
    my $data;

    confess("no status data supplied") unless defined $livedata;

    if($hostname && $description) {
        $data = $livedata->{'services'}->{$hostname}->{$description};
        if($op ne '=') {
            my $function = 'worst';
            if($description =~ m/^(b|w):(.*)$/mx) {
                if($1 eq 'b') { $function = 'best' }
                $description = $2;
            }
            if($op eq '~' || $op eq '!~') {
                $description = Thruk::Utils::convert_wildcards_to_regex($description);
            }

            # create hash which can be used by internal calculation function
            my $depends = [];
            for my $sname (keys %{$livedata->{'services'}->{$hostname}}) {
                if(   ($op eq '!~' && $sname !~ m/$description/mxi)
                   || ($op eq  '~' && $sname =~ m/$description/mxi)
                   || ($op eq '!=' && $sname ne $description)) {
                    my $s = $livedata->{'services'}->{$hostname}->{$sname};
                    push @{$depends}, {
                        label                    => $sname,
                        status                   => ($bp->{'state_type'} eq 'hard' && $s->{'state_type'} != 1) ? $s->{'last_hard_state'} : $s->{'state'},
                        status_text              => $s->{'plugin_output'},
                        acknowledged             => $s->{'acknowledged'},
                        scheduled_downtime_depth => $s->{'scheduled_downtime_depth'} ? 1 : 0,
                        last_state_change        => ($bp->{'state_type'} eq 'hard' && $s->{'state_type'} != 1) ? $s->{'last_hard_state_change'} : $s->{'last_state_change'},
                    };
                }
            }

            my @res;
            if(scalar @{$depends} == 0) {
                return(3, 'no matching hosts/services found');
            }
            elsif($function eq 'worst') {
                @res = worst($c, $bp, { depends => $depends });
            } else {
                @res = best($c, $bp, { depends => $depends });
            }
            my $display_op = '';
            if($op ne '=') {
                $display_op = ' '.$op.' ';
            }
            $res[1] = $function.' of '.$hostname.':'.$display_op.$description;
            return(@res);
        }
    }
    elsif($hostname) {
        $data = $livedata->{'hosts'}->{$hostname};
        # translate host downs to critical
        $data->{'state'}           = 2 if (defined $data->{'state'}           && $data->{'state'} == 1);
        $data->{'last_hard_state'} = 2 if (defined $data->{'last_hard_state'} && $data->{'last_hard_state'} == 1);
    }

    # only hard states?
    if($data && $bp->{'state_type'} eq 'hard' && defined $data->{'last_hard_state'} && (defined $data->{'state_type'} && $data->{'state_type'} != 1)) {
        return($data->{'last_hard_state'},
               ($n->{'status_text'} || 'no plugin output yet'), # return last status text
               undef,
               {'last_state_change' => $data->{'last_hard_state_change'}},
        );
    }

    if($data && defined $data->{'state'}) {
        return($data->{'state'}, $data->{'plugin_output'}."\n".$data->{'long_plugin_output'}, undef, $data);
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

    confess("no status data supplied") unless defined $livedata;

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
                            Thruk::Utils::Filter::state2text($status),
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
    my $depends = ref $n eq 'HASH' ? $n->{'depends'} : $n->depends($bp);
    my($state, $nodes, $extra) = Thruk::BP::Utils::get_nodes_grouped_by_state($c, $depends, $bp, "worst");
    if(!$nodes || scalar @{$nodes} == 0) {
        return(3, 'no dependent nodes');
    }
    return($state,
           'worst of',
            Thruk::Utils::Filter::state2text($state).' - Worst state is '.Thruk::Utils::Filter::state2text($state).': '.Thruk::BP::Utils::join_labels($nodes, $state),
           $extra,
    );
}

##########################################################

=head2 best

    best($c, $bp, $n)

returns best state of all dependent nodes

=cut
sub best {
    my($c, $bp, $n) = @_;
    my $depends = ref $n eq 'HASH' ? $n->{'depends'} : $n->depends($bp);
    my($state, $nodes, $extra) = Thruk::BP::Utils::get_nodes_grouped_by_state($c, $depends, $bp, "best");
    if(!$nodes || scalar @{$nodes} == 0) {
        return(3, 'no dependent nodes');
    }
    return($state,
           'best of',
            Thruk::Utils::Filter::state2text($state).' - Best state is '.Thruk::Utils::Filter::state2text($state).': '.Thruk::BP::Utils::join_labels($nodes, $state),
           $extra,
    );
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
    my($good, $bad) = _count_good_bad($n->depends($bp));
    my $state = 0;
    if($warning !~ m/^\-?\d+$/mx) {
        return(3, 'warning threshold must be numeric');
    }
    if($critical !~ m/^\-?\d+$/mx) {
        return(3, 'critical threshold must be numeric');
    }
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
    return($state, $desc, Thruk::Utils::Filter::state2text($state).' - '.$good.'/'.($good+$bad).' nodes are available');
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
    my($good, $bad) = _count_good_bad($n->depends($bp));
    if($warning !~ m/^\-?\d+$/mx) {
        return(3, 'warning threshold must be numeric');
    }
    if($critical !~ m/^\-?\d+$/mx) {
        return(3, 'critical threshold must be numeric');
    }
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
    return($state, $desc, Thruk::Utils::Filter::state2text($state).' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 equals

    equals($c, $bp, $n, [$args: $number])

returns number of good nodes matches the number

=cut
sub equals {
    my($c, $bp, $n, $args) = @_;
    my($number) = @{$args};
    my($good, $bad) = _count_good_bad($n->depends($bp));
    if($number !~ m/^\-?\d+$/mx) {
        return(3, 'threshold must be numeric');
    }
    if($good == 0 and $bad == 0) {
        return(3, 'no dependent nodes');
    }
    my $state = 2;
    if($good == $number) {
        $state = 0;
    }
    return($state, '= '.$number, Thruk::Utils::Filter::state2text($state).' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 random

    random($c, $bp, $n)

returns random state

=cut
sub random {
    my($c, $bp, $n) = @_;
    my $state = int(rand(4));
    return($state, 'random', Thruk::Utils::Filter::state2text($state).' - Random state is '.Thruk::Utils::Filter::state2text($state));
}

##########################################################

=head2 statusfilter

    statusfilter($c, $bp, $n)

returns state based on livestatus filter

=cut
sub statusfilter {
    my($c, $bp, $n, $args) = @_;
    my($aggregation, $type, $filter, $hostwarn, $hostcrit, $servicewarn, $servicecrit) = @{$args};

    $c->stash->{'minimal'} = 1; # do not fill totals boxes
    my($searches, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter) = Thruk::Utils::Status::do_search($c, $filter, '');

    my $node_filter = Thruk::Utils::array_uniq([@{$n->{'filter'}}, @{$bp->{'filter'}}]);
    my($ack_filter, $downtime_filter, $unknown_filter, $extra) = (0,0,0, {});
    for my $f (@{$node_filter}) {
        $ack_filter      = 1 if $f eq 'acknowledged_filter';
        $downtime_filter = 1 if $f eq 'downtime_filter';
        $unknown_filter  = 1 if $f eq 'unknown_filter';
    }

    my($worst_host, $total_hosts, $good_hosts, $down_hosts) = (0,0,0,0);
    my $best_host = -1;
    if($type eq 'hosts' || $type eq 'both') {
        my $data = $c->{'db'}->get_host_stats( filter => [ $hostfilter ]);
        $data    = _statusfilter_apply_filter("host", $data, $ack_filter, $downtime_filter, $unknown_filter);
        $total_hosts = $data->{'total'};
        $good_hosts  = $data->{'up'} + $data->{'pending'};
        $down_hosts  = $data->{'down'} + $data->{'unreachable'};
        if(   $data->{'unreachable'}) { ($best_host, $worst_host) = _set_best_worst(2, $best_host, $worst_host); }
        elsif($data->{'down'})        { ($best_host, $worst_host) = _set_best_worst(1, $best_host, $worst_host); }
        elsif($data->{'up'})          { ($best_host, $worst_host) = _set_best_worst(0, $best_host, $worst_host); }
        $extra->{acknowledged} = 0;
        my $acknowledged = $data->{'down_and_ack'} + $data->{'unreachable_and_ack'};
        if($down_hosts <= $acknowledged && $acknowledged > 0) {
            $extra->{acknowledged} = 1;
        }
        $extra->{scheduled_downtime_depth} = 0;
        my $scheduled = $data->{'down_and_scheduled'} + $data->{'unreachable_and_scheduled'};
        if($down_hosts <= $scheduled && $scheduled > 0) {
            $extra->{scheduled_downtime_depth} = 1;
        }
    }

    my $best_service = -1;
    my($worst_service, $total_services, $good_services, $down_services) = (0,0,0,0);
    if($type eq 'services' || $type eq 'both') {
        my $data = $c->{'db'}->get_service_stats( filter => [ $servicefilter ]);
        $data    = _statusfilter_apply_filter("service", $data, $ack_filter, $downtime_filter, $unknown_filter);
        $total_services = $data->{'total'};
        $good_services  = $data->{'ok'}   + $data->{'pending'} + $data->{'warning'};
        $down_services  = $data->{'critical'} + $data->{'unknown'};
        if(   $data->{'unknown'})  { ($best_service, $worst_service) = _set_best_worst(3, $best_service, $worst_service); }
        elsif($data->{'critical'}) { ($best_service, $worst_service) = _set_best_worst(2, $best_service, $worst_service); }
        elsif($data->{'warning'})  { ($best_service, $worst_service) = _set_best_worst(1, $best_service, $worst_service); }
        elsif($data->{'ok'})       { ($best_service, $worst_service) = _set_best_worst(0, $best_service, $worst_service); }
        if($type eq 'services' || $extra->{acknowledged} == 1) {
            $extra->{acknowledged} = 0;
            my $acknowledged = $data->{'critical_and_ack'} + $data->{'unknown_and_ack'};
            if($down_services <= $acknowledged && $acknowledged > 0) {
                $extra->{acknowledged} = 1;
            }
        }
        if($type eq 'services' || $extra->{scheduled_downtime_depth} == 1) {
            $extra->{scheduled_downtime_depth} = 0;
            my $scheduled = $data->{'critical_and_scheduled'} + $data->{'unknown_and_scheduled'};
            if($down_services <= $scheduled && $scheduled > 0) {
                $extra->{scheduled_downtime_depth} = 1;
            }
        }
    }

    my $status = 0;
    my $output = "";
    if($type eq 'hosts' || $type eq 'both') {
        if(defined $hostwarn and $hostwarn ne '') {
            if($hostwarn =~ m/^(\d+)%$/mx) { $hostwarn = $total_hosts / 100 * $1; }
            if($hostwarn !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - host warning threshold must be numeric"; }
            if($down_hosts >= $hostwarn) {
                $status = 1;
            }
        }
        if(defined $hostcrit and $hostcrit ne '') {
            if($hostcrit =~ m/^(\d+)%$/mx) { $hostcrit = $total_hosts / 100 * $1; }
            if($hostcrit !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - host critical threshold must be numeric"; }
            if($down_hosts >= $hostcrit) {
                $status = 2;
            }
        }
    }
    if($type eq 'services' || $type eq 'both') {
        if(defined $servicewarn and $servicewarn ne '') {
            if($servicewarn =~ m/^(\d+)%$/mx) { $servicewarn = $total_services / 100 * $1; }
            if($servicewarn !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - service warning threshold must be numeric"; }
            if($down_services >= $servicewarn) {
                $status = 1 unless $status > 1;
            }
        }
        if(defined $servicecrit and $servicecrit ne '') {
            if($servicecrit =~ m/^(\d+)%$/mx) { $servicecrit = $total_services / 100 * $1; }
            if($servicecrit !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - service critical threshold must be numeric"; }
            if($down_services >= $servicecrit) {
                $status = 2;
            }
        }
    }
    if($aggregation eq 'worst') {
        $status = $worst_service;
        # map host state to service state
        if($worst_host) { $status = 2; }
    }
    elsif($aggregation eq 'best') {
        $status = $best_host;
        $status = $best_service if $best_service < $best_host;
    }

    my $perfdata   = '';
    my $thresholdoutput = [];
    if($type eq 'hosts' || $type eq 'both') {
        push @{$thresholdoutput}, sprintf("%d/%d hosts up", $good_hosts, $total_hosts);
        $perfdata .= 'hosts_up='.$good_hosts.' hosts_down='.$down_hosts;
    }
    if($type eq 'services' || $type eq 'both') {
        push @{$thresholdoutput}, sprintf("%d/%d services up", $good_services, $total_services);
        $perfdata .= 'services_up='.$good_services.' services_down='.$down_services;
    }

    $output = sprintf("%s - %s|%s",
                            Thruk::Utils::Filter::state2text($status),
                            join(', ', @{$thresholdoutput}),
                            $perfdata) unless $output;

    my $shortname = "";
    for my $search (@{$searches}) {
        for my $f (@{$search->{'text_filter'}}) {
            $shortname .= " & " if $shortname;
            $shortname .= $f->{'type'}.$f->{'op'}.$f->{'value'};
        }
    }
    $shortname = "filer" unless $shortname;

    # append issues to output
    if($status > 0) {
        my $maximum_output = 10;
        my $num = 0;
        if($worst_host > 0) {
            my $data = $c->{'db'}->get_hosts( filter => [ $hostfilter, { state => { '>' => 0 }} ], columns => [qw/name state plugin_output scheduled_downtime_depth acknowledged/]);
            for my $h (@{$data}) {
                next if($ack_filter      && $h->{'acknowledged'});
                next if($downtime_filter && $h->{'scheduled_downtime_depth'} > 0);
                $output .= sprintf("\n[%s] %s - %s", Thruk::Utils::Filter::hoststate2text($h->{'state'}), $h->{'name'}, substr($h->{'plugin_output'}, 0, 50)) if $num < $maximum_output;
                $num++;
            }
        }
        if($worst_service > 0) {
            my $data = $c->{'db'}->get_services( filter => [ $servicefilter, { state => { '>' => 0 }} ], columns => [qw/host_name description state plugin_output scheduled_downtime_depth acknowledged/]);
            for my $s (@{$data}) {
                next if($ack_filter      && $s->{'acknowledged'});
                next if($downtime_filter && $s->{'scheduled_downtime_depth'} > 0);
                next if($unknown_filter  && $s->{'state'} == 3);
                $output .= sprintf("\n[%s] %s - %s - %s", Thruk::Utils::Filter::state2text($s->{'state'}), $s->{'host_name'}, $s->{'description'}, substr($s->{'plugin_output'}, 0, 50)) if $num < $maximum_output;
                $num++;
            }
        }
        if($num > $maximum_output) {
            $output .= sprintf("\nfound %d more issues...", $num - $maximum_output);
        }
    }

    return($status, $shortname, $output, $extra);
}

##########################################################
sub _set_best_worst {
    my($state, $best, $worst) = @_;
    if($best == -1 || $state < $best) {
        $best = $state;
    }
    if($state > $worst) {
        $worst = $state;
    }
    return($best, $worst);
}

##########################################################
# kind of a hack, but there is no easy way to apply filter to any filter
# so we just assume the function from the name of the filter which is ok,
# since these are shiped filters, so we know what they do and try to
# rebuild their functionality here
sub _statusfilter_apply_filter {
    my($type, $data, $ack_filter, $downtime_filter, $unknown_filter) = @_;

    # if both filter (ack and downtime) should be applied, we substract plain_down from down which
    # because that is the number of downs which are not in downtime or acknowledged
    if($ack_filter && $downtime_filter) {
        if($type eq 'host') {
            for my $state (qw/down unreachable/) {
                $data->{'up'}  += ($data->{$state} - $data->{'plain_'.$state});
                $data->{$state} = $data->{'plain_'.$state};
            }
        }
        if($type eq 'service') {
            for my $state (qw/warning critical unknown/) {
                $data->{'ok'}  += ($data->{$state} - $data->{'plain_'.$state});
                $data->{$state} = $data->{'plain_'.$state};
            }
        }
    }
    elsif($ack_filter) {
        if($type eq 'host') {
            for my $state (qw/down unreachable/) {
                $data->{'up'}   += $data->{$state.'_and_ack'};
                $data->{$state} -= $data->{$state.'_and_ack'};
            }
        }
        if($type eq 'service') {
            for my $state (qw/warning critical unknown/) {
                $data->{'ok'}   += $data->{$state.'_and_ack'};
                $data->{$state} -= $data->{$state.'_and_ack'};
            }
        }
    }
    elsif($downtime_filter) {
        if($type eq 'host') {
            for my $state (qw/down unreachable/) {
                $data->{'up'}   += $data->{$state.'_and_scheduled'};
                $data->{$state} -= $data->{$state.'_and_scheduled'};
            }
        }
        if($type eq 'service') {
            for my $state (qw/warning critical unknown/) {
                $data->{'ok'}   += $data->{$state.'_and_scheduled'};
                $data->{$state} -= $data->{$state.'_and_scheduled'};
            }
        }
    }

    if($unknown_filter && $type eq 'service') {
        $data->{'ok'}     += $data->{'unknown'};
        $data->{'unknown'} = 0;
    }
    return($data);
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
    my $fname = $args->[0];
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
    my $last = scalar @{$args} -1;
    my $real_args = [@{$args}[1..$last]];
    eval {
        do($f->{'file'});
        if($@) {
            _info("internal error while loading filter file ".$f->{'file'}.": ".$@);
        }
        ## no critic
        eval('($status, $short_desc, $status_text, $extra) = '."$fname".'($c, $bp, $n, $real_args, $livedata);');
        ## use critic
        if($@) {
            $status      = 3;
            $short_desc  = "UNKNOWN";
            $status_text = $@;
            _info("internal error in custom function $fname: $@");
        }
    };
    if($@) {
        $status      = 3;
        $short_desc  = "UNKNOWN";
        $status_text = $@;
        _info("internal error in custom function $fname: $@");
    }
    $short_desc  = '(no output)' unless $short_desc;
    $status_text = '(no output)' unless $status_text;
    return($status, $short_desc, $status_text, $extra);
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
# get extra attributes from nodes list
sub _get_nodes_extra {
    my($nodes, $aggregation) = @_;
    my $extra = {
        'acknowledged'             => undef,
        'scheduled_downtime_depth' => undef,
    };
    for my $node (@{$nodes}) {
        for my $key (qw/acknowledged scheduled_downtime_depth/) {
            if(!defined $extra->{$key}) {
                $extra->{$key} = $node->{$key};
            }
            elsif($aggregation eq 'worst') {
                if(!$node->{$key}) {
                    $extra->{$key} = 0;
                }
            }
            elsif($aggregation eq 'best') {
                if($node->{$key}) {
                    $extra->{$key} = 1;
                }
            }
        }
    }
    if($extra->{'scheduled_downtime_depth'}) {
        $extra->{'scheduled_downtime_depth'} = 1;
    }
    return($extra);
}

##########################################################

1;
