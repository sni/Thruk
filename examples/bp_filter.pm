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

    # replace acknowledged problems in all nodes
    for my $d (@{$args->{'node'}->depends($args->{'bp'})}) {
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

    # replace unknowns in all nodes
    for my $d (@{$args->{'node'}->depends($args->{'bp'})}) {
        $d->{'status'} = 0 if $d->{'status'} && $d->{'status'} == 3;
    }

    return;
}

# Output: Add problem drill down information
#
# This filter adds recursive drill down information for all failed
# nodes.
sub add_recursive_output_filter {
    my($c, $args) = @_;

    # this is a input filter only
    return unless $args->{'type'} eq 'output';

    my $text    = '';
    my $indent  = 0;
    my $parents = {};
    my $clean_status = sub {
        my($text) = @_;
        chomp($text);
        $text =~ s/\|.*$//gmx;
        return((split(/\n|\\+n/mx, $text, 2))[0] // "");
    };
    my $recurse;
    $recurse = sub {
        my($bp, $node, $indent) = @_;
        $parents->{$bp->{id}.'-'.$node->{'id'}} = 1;
        return if $indent > 20;
        for my $n (@{$node->depends($bp)}) {
            if($n->{'status'} != 0) {
                if(defined $parents->{$bp->{id}.'-'.$n->{'id'}}) {
                    $text .= (chr(8194) x ($indent*4)).'- ['.$n->{'label'}."] deep recursion...\n";
                    next;
                }
                $text .= (chr(8194) x ($indent*4)).'- ['.($n->{'label'} // "").'] '.(&{$clean_status}($n->{'status_text'} || $n->{'short_desc'}))."\n";
                &{$recurse}($bp, $n, $indent+1);
            }
        }
        if($node->{'bp_ref'} && $node->{'status'} != 0) {
            my $link_bp    = Thruk::BP::Utils::load_bp_data($c, $node->{'bp_ref'});
            if($link_bp->[0]) {
                my $first_node = $link_bp->[0]->{'nodes'}->[0];
                $text .= (chr(8194) x ($indent*4)).'- ['.$first_node->{'label'}.'] '.(&{$clean_status}($first_node->{'status_text'} || $first_node->{'short_desc'}))."\n";
                &{$recurse}($link_bp->[0], $first_node, $indent+1);
            }
        }
        delete $parents->{$bp->{id}.'-'.$node->{'id'}};
    };
    &{$recurse}($args->{'bp'}, $args->{'node'}, $indent);

    $text =~ s/\n\s*\n/\n/gmx;
    $text =~ s/\n+/\n/gmx;
    $args->{'extra'}->{'long_output'} = $text;

    return;
}
