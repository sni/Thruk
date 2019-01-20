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

    my $text = _add_recursive_output_filter_recurse($c, "", $args->{'bp'}, $args->{'node'}, -1, {});
    $text    =~ s/\n\s*\n/\n/gmx;
    $text    =~ s/\n+/\n/gmx;
    # keep plugin output as is and replace long output with drill down
    $args->{'extra'}->{'long_output'} = $text;
    return;
}
sub _add_recursive_output_filter_clean_status {
    my($text, $keeplongoutput) = @_;
    chomp($text);
    $text =~ s/\|.*$//gmx;
    return($text // "") if $keeplongoutput;
    return((split(/\n|\\+n/mx, $text, 2))[0] // "");
}
sub _add_recursive_output_filter_indent {
    my($indent, $text) = @_;
    my $prefix = (chr(8194) x ($indent*3));
    my @lines = split(/\n|\\+n/mx, $text);
    return($prefix.join("\n".$prefix, @lines));
}
sub _add_recursive_output_filter_recurse {
    my($c, $text, $bp, $node, $indent, $parents) = @_;
    $parents->{$bp->{id}.'-'.$node->{'id'}} = 1;
    return $text if $indent > 20;
    return $text if $node->{'status'} == 0;

    # add node itself
    my @lines;
    if($indent >= 0) {
        @lines = split(/\n|\\+n/mx, '- ['.($node->{'label'} // '').'] '._add_recursive_output_filter_clean_status($node->{'status_text'} || $node->{'short_desc'}, 1));
        my $firstline = shift @lines;
        $text .= _add_recursive_output_filter_indent($indent, $firstline)."\n";
    }

    my $depends = $node->depends($bp);
    if(!$node->{'bp_ref'} && scalar @{$depends} == 0 && scalar @lines > 0 && $lines[0] =~ m|^\-|mx) {
        for my $line (@lines) {
            $text .= _add_recursive_output_filter_indent($indent+1, $line)."\n";
        }
    }

    for my $n (@{$depends}) {
        $text = _add_recursive_output_filter_recurse($c, $text, $bp, $n, $indent+1, $parents);
    }

    # recurse into other business process
    if($node->{'bp_ref'}) {
        my $link_bp = Thruk::BP::Utils::load_bp_data($c, $node->{'bp_ref'}, undef, undef, $node->{'bp_ref_peer'});
        if($link_bp->[0]) {
            # local bp
            my $first_node = $link_bp->[0]->{'nodes'}->[0];
            $text = _add_recursive_output_filter_recurse($c, $text, $link_bp->[0], $first_node, $indent+1, $parents);
        } else {
            # remote bp
            my @lines = split(/\n|\\+n/mx, _add_recursive_output_filter_clean_status($node->{'status_text'} || $node->{'short_desc'}, 1));
            shift @lines;
            for my $line (@lines) {
                $text .= _add_recursive_output_filter_indent($indent+1, $line)."\n";
            }
        }
    }

    delete $parents->{$bp->{id}.'-'.$node->{'id'}};
    return $text;
}