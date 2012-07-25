=head1 NAME

Thruk::Utils::PanoramaCpuStats - Collect linux cpu statistics.

=head1 DESCRIPTION

see Sys::Statistics::Linux::CpuStats for details

=head1 AUTHOR

Jonny Schulz <jschulz.cpan(at)bloonix.de>.

=head1 COPYRIGHT

Copyright (c) 2006, 2007 by Jonny Schulz. All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

package Thruk::Utils::PanoramaCpuStats;

use strict;
use warnings;
use Carp qw(croak);
use Thruk::Utils::IO;

=head1 METHODS

=head2 new

create new object

=cut

sub new {
    my $class = shift;
    my $self  = shift || {};
    return bless $self, $class;
}

=head2 init

init reference values

=cut

sub init {
    my $self = shift;
    $self->{init} = $self->_load;
    return;
}

=head2 get

return stats

=cut
sub get {
    my $self  = shift;
    if(!defined $self->{init}) {
        $self->init;
        sleep($self->{'sleep'});
    }
    $self->{stats} = $self->_load;
    $self->_deltas;
    return $self->{stats};
}

sub _load {
    my $self  = shift;
    my $class = ref $self;
    my $file  = $self->{files};
    my (%stats, $iowait, $irq, $softirq, $steal);

    my $filename = '/proc/stat';
    open my $fh, '<', $filename or croak "$class: unable to open $filename ($!)";

    while (my $line = <$fh>) {
        if ($line =~ /^(cpu.*?)\s+(.*)$/mx) {
            my $cpu = \%{$stats{$1}};
            (@{$cpu}{qw(user nice system idle)},
                $iowait, $irq, $softirq, $steal) = split /\s+/mx, $2;
            # iowait, irq and softirq are only set
            # by kernel versions higher than 2.4.
            # steal is available since 2.6.11.
            $cpu->{iowait}  = $iowait  if defined $iowait;
            $cpu->{irq}     = $irq     if defined $irq;
            $cpu->{softirq} = $softirq if defined $softirq;
            $cpu->{steal}   = $steal   if defined $steal;
        }
    }

    CORE::close($fh);
    return \%stats;
}

sub _deltas {
    my $self  = shift;
    my $class = ref $self;
    my $istat = $self->{init};
    my $lstat = $self->{stats};

    foreach my $cpu (keys %{$lstat}) {
        my $icpu = $istat->{$cpu};
        my $dcpu = $lstat->{$cpu};
        my $uptime;

        while (my ($k, $v) = each %{$dcpu}) {
            if (!defined $icpu->{$k}) {
                croak "$class: not defined key found '$k'";
            }

            if ($v !~ /^\d+\z/mx || $dcpu->{$k} !~ /^\d+\z/mx) {
                croak "$class: invalid value for key '$k'";
            }

            $dcpu->{$k} -= $icpu->{$k};
            $icpu->{$k}  = $v;
            $uptime += $dcpu->{$k};
        }

        foreach my $k (keys %{$dcpu}) {
            if ($dcpu->{$k} > 0) {
                $dcpu->{$k} = sprintf('%.2f', 100 * $dcpu->{$k} / $uptime);
            } elsif ($dcpu->{$k} < 0) {
                $dcpu->{$k} = sprintf('%.2f', 0);
            } else {
                $dcpu->{$k} = sprintf('%.2f', $dcpu->{$k});
            }
        }

        $dcpu->{total} = sprintf('%.2f', 100 - $dcpu->{idle});
    }
    return;
}

1;
