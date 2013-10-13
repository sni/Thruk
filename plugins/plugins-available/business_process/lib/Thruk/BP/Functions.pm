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

    status($c, $bp, $n, [$args: $hostname, $description], [$hostdata], [$servicedata])

returns status based on real service or host

=cut
sub status {
    my($c, $bp, $n, $args, $hostdata, $servicedata) = @_;
    my($hostname, $description) = @{$args};
    my $data;
    if($hostname and $description) {
        if(defined $servicedata->{$hostname}->{$description}) {
            $data = $servicedata->{$hostname}->{$description};
        } else {
            my $services = $c->{'db'}->get_services( filter => [{ 'description' => $description }], extra_columns => [qw/last_hard_state last_hard_state_change/]);
            if(scalar @{$services} > 0) {
                $data = $services->[0];
            }
        }
    }
    elsif($hostname) {
        if(defined $hostdata->{$hostname}) {
            $data = $hostdata->{$hostname};
        } else {
            my $hosts = $c->{'db'}->get_hosts( filter => [{ 'name' => $hostname } ], extra_columns => [qw/last_hard_state last_hard_state_change/] );
            if(scalar @{$hosts} > 0) {
                $data = $hosts->[0];
            }
        }
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

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
