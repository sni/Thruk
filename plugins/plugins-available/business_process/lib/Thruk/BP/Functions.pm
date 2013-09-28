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

my $tr_states = {
    '0' => 'OK',
    '1' => 'WARNING',
    '2' => 'CRITICAL',
    '3' => 'UNKNOWN',
    '4' => 'PENDING',
};

##########################################################

=head2 status

    status($c, $bp, $n, $hostname, [$service_description])

returns status based on real service or host

=cut
sub status {
    my($c, $bp, $n, $hostname, $description) = @_;
    if($description) {
        my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $description } ] );
        if(scalar @{$services} > 0) {
            return($services->[0]->{'state'}, $services->[0]->{'plugin_output'});
        }
        return(3, 'no such service');
    }

    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ] );
    if(scalar @{$hosts} > 0) {
        return($hosts->[0]->{'state'}, $hosts->[0]->{'plugin_output'});
    }
    return(3, 'no such host');
}

##########################################################

=head2 fixed

    fixed($c, $bp, $n, $status, [$text])

returns fixed status based input

=cut
sub fixed {
    my($c, $bp, $n, $status, $text) = @_;
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
    $state = 4 if $state == -1;
    return($state, 'worst of', $tr_states->{$state}.' - Worst state is '.$tr_states->{$state}.': '.Thruk::BP::Utils::join_labels($states->{$state}));
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
    $state = 4 if $state == -1;
    return($state, 'best of', $tr_states->{$state}.' - Best state is '.$tr_states->{$state}.': '.Thruk::BP::Utils::join_labels($states->{$state}));
}

##########################################################

=head2 at_least

    worst($c, $bp, $n, $critical)
    worst($c, $bp, $n, $warning, $critical)

returns state if thresholds are reached

=cut
sub at_least {
    my($c, $bp, $n, $warning, $critical) = @_;
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
    return($state, $desc, $tr_states->{$state}.' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 not_more

    worst($c, $bp, $n, $critical)
    worst($c, $bp, $n, $warning, $critical)

returns state if thresholds are reached

=cut
sub not_more {
    my($c, $bp, $n, $warning, $critical) = @_;
    $critical = $warning unless defined $critical;
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
    return($state, $desc, $tr_states->{$state}.' - '.$good.'/'.($good+$bad).' nodes are available');
}

##########################################################

=head2 equals

    equals($c, $bp, $n, $number)

returns number of good nodes matches the number

=cut
sub equals {
    my($c, $bp, $n, $number) = @_;
    my($good, $bad) = _count_good_bad($n->{'depends'});
    if($good == 0 and $bad == 0) {
        return(4, 'no dependent nodes');
    }
    my $state = 2;
    if($good == $number) {
        $state = 0;
    }
    return($state, '= '.$number, $tr_states->{$state}.' - '.$good.'/'.($good+$bad).' nodes are available');
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
