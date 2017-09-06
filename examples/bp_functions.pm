use warnings;
no warnings 'redefine';
use strict;
use utf8;

# This function just echoes the
# provided text sample and optionally
# reverses the text.
#
# Arguments:
# arg1: Text;      text;     text that should be echoed
# arg2: Reverse;   checkbox; yes; no
# arg3: Uppercase; select;   yes; no
sub echo_function {
    my($c, $bp, $n, $args, $livedata) = @_;
    my($text, $reverse, $upper) = @{$args};
    $text = scalar reverse $text if $reverse eq 'yes';
    $text =             uc $text if $upper   eq 'yes';
    return(0, $text, $text, {});
}

# This function calculates weighted state based
# on the children node descriptions.
# Child node label may end with the numeric weight
# otherwise 1 is assumed.
# Thresholds will trigger if the availability is lower
# than the threshold.
#
# Arguments:
# arg1: Warning;   text;  warning if availability is lower than 5 or 50%
# arg2: Critical;  text;  critical if availability is lower than 3 or 30%
# arg3: Available; select; Ok; Ok / Warning; Ok / Warning / Unknown
sub weighted_state_function {
    my($c, $bp, $n, $args, $livedata) = @_;
    my($warn, $crit, $states) = @{$args};

    my($status, $output) = (0, "");
    my $total     = 0;
    my $available = 0;
    for my $child (@{$n->{'depends'}}) {
        my $weight = 1;
        if($child->{'label'} =~ m/(\d+)$/mx) {
            $weight = $1;
        }
        $total += $weight;

        if($child->{'status'} == 0) {
            $available += $weight;
        }
        elsif($child->{'status'} == 1 && $states =~ /warning/mxi) {
            $available += $weight;
        }
        elsif($child->{'status'} == 3 && $states =~ /unknown/mxi) {
            $available += $weight;
        }
    }

    if($status == 0 && $total == 0) {
        $status = 3;
        $output = "UNKNOWN - no children nodes defined";
    }

    if($warn =~ m/^(\d+)%$/mx) { $warn = $total / 100 * $1; }
    if($warn !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - warning threshold must be numeric"; }

    if($crit =~ m/^(\d+)%$/mx) { $crit = $total / 100 * $1; }
    if($crit !~ m/^(\d+|\d+\.\d+)$/mx) { $status = 3; $output = "UNKNOWN - critical threshold must be numeric"; }

    return($status, $output, $output, {}) if $status > 0;

    if($available <= $crit) {
        $status = 2;
    }
    elsif($available <= $warn) {
        $status = 1;
    }

    my $perfdata = sprintf('available=%.3f%%;%d:;%d:;0;100',
                            (($available/$total)*100),
                            (($warn/$total)*100),
                            (($crit/$total)*100),
                           );
    my $short = sprintf("%d%% available", (($available / $total)*100));
    $output = sprintf("%s - %s|%s",
                            Thruk::BP::Utils::state2text($status),
                            $short,
                            $perfdata);

    return($status, $short, $output);
}

################################################################################
# Add your own functions here:
# ...