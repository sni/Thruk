use warnings;
no warnings 'redefine';
use strict;
use utf8;

# Input: Set Downtime Problems to OK
#
# This filter sets hosts/services to ok which are
# currently in a scheduled downtime.
sub downtime_filter {
    my($c, $args) = @_;

    # this is a input filter only
    return unless $args->{'type'} eq 'input';

    # set all downtimes to ok in livestatus data
    if($args->{'livedata'}->{'hosts'}) {
        for my $name (keys %{$args->{'livedata'}->{'hosts'}}) {
            $args->{'livedata'}->{'hosts'}->{$name}->{'state'} = 0 if $args->{'livedata'}->{'hosts'}->{$name}->{'scheduled_downtime_depth'} > 0;
        }
    }
    if($args->{'livedata'}->{'services'}) {
        for my $name (keys %{$args->{'livedata'}->{'services'}}) {
            for my $description (keys %{$args->{'livedata'}->{'services'}->{$name}}) {
                $args->{'livedata'}->{'services'}->{$name}->{$description}->{'state'} = 0 if $args->{'livedata'}->{'services'}->{$name}->{$description}->{'scheduled_downtime_depth'} > 0;
            }
        }
    }

    # replace downtimes in all nodes,
    for my $d (@{$args->{'bp'}->{'nodes'}}) {
        $d->{'status'} = 0 if $d->{'scheduled_downtime_depth'} > 0;
    }

    return;
}

# Input: Set Acknowledged Problems to OK
#
# This filter sets hosts/services to ok which are
# currently acknowledged.
sub acknowledged_filter {
    my($c, $args) = @_;

    # this is a input filter only
    return unless $args->{'type'} eq 'input';

    # set all acknowledged problems to ok in livestatus data
    if($args->{'livedata'}->{'hosts'}) {
        for my $name (keys %{$args->{'livedata'}->{'hosts'}}) {
            $args->{'livedata'}->{'hosts'}->{$name}->{'state'} = 0 if $args->{'livedata'}->{'hosts'}->{$name}->{'acknowledged'} > 0;
        }
    }
    if($args->{'livedata'}->{'services'}) {
        for my $name (keys %{$args->{'livedata'}->{'services'}}) {
            for my $description (keys %{$args->{'livedata'}->{'services'}->{$name}}) {
                $args->{'livedata'}->{'services'}->{$name}->{$description}->{'state'} = 0 if $args->{'livedata'}->{'services'}->{$name}->{$description}->{'acknowledged'} > 0;
            }
        }
    }

    # replace acknowledged problems in all nodes,
    for my $d (@{$args->{'bp'}->{'nodes'}}) {
        $d->{'status'} = 0 if $d->{'acknowledged'} > 0;
    }

    return;
}

# Input: Set Unknown state to OK
#
# This filter sets services to ok which are
# currently in unknown state.
sub unknown_filter {
    my($c, $args) = @_;

    # this is a input filter only
    return unless $args->{'type'} eq 'input';

    # set all unknown to ok in livestatus data
    if($args->{'livedata'}->{'hosts'}) {
        for my $name (keys %{$args->{'livedata'}->{'hosts'}}) {
            $args->{'livedata'}->{'hosts'}->{$name}->{'state'} = 0 if $args->{'livedata'}->{'hosts'}->{$name}->{'state'} == 3;
        }
    }
    if($args->{'livedata'}->{'services'}) {
        for my $name (keys %{$args->{'livedata'}->{'services'}}) {
            for my $description (keys %{$args->{'livedata'}->{'services'}->{$name}}) {
                $args->{'livedata'}->{'services'}->{$name}->{$description}->{'state'} = 0 if $args->{'livedata'}->{'services'}->{$name}->{$description}->{'state'} == 3;
            }
        }
    }

    # replace unknowns in all nodes,
    for my $d (@{$args->{'bp'}->{'nodes'}}) {
        $d->{'status'} = 0 if $d->{'status'} && $d->{'status'} == 3;
    }
    return;
}
