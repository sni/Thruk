package Thruk::Template::Context;
use warnings;
use strict;
use Template::Config ();
use Time::HiRes qw/gettimeofday tv_interval/;

use base qw(Template::Context);

my $profiles = [];
my $totals   = {};
my @stack    = ();

sub process {
    my($self, @args) = @_;

    my $template = $args[0];
    if(UNIVERSAL::isa($template, "Template::Document")) {
        $template = $template->name || $template;
    }

    my $t1 = [gettimeofday];
    $totals->{$template}->[0]++;
    my $excl = $totals->{$template}->[2] // 0;
    $totals->{$template}->[2] = 0;
    push @stack, $totals->{$template};
    my @return = wantarray ? $self->SUPER::process(@args) : scalar $self->SUPER::process(@args);
    pop @stack;
    my $elapsed = tv_interval($t1);
    $totals->{$template}->[1] += $elapsed;
    $totals->{$template}->[2] += $elapsed;
    my $exclusive = $totals->{$template}->[2];
    for my $parent (@stack) {
        $parent->[2] -= $exclusive;
    }
    $excl = $totals->{$template}->[2] += $excl;

    # top level, create report
    if(scalar @stack == 0) {
        my $total_time = $totals->{$template}->[1];

        my $out  = sprintf("TT %s:\n", $template);
           $out .= sprintf("total time: %6.3fs\n", $total_time);
        my $html = "<table class='cellborder rounded overflow-hidden rowhover' style='width: 800px;'>";
           $html .= sprintf("<tr><td class='font-bold'>total time</td><td></td><td></td><td></td><td class='font-bold text-right'>%6.3fs</td></tr>\n", $total_time);
           $html .= "<tr><th>template</th><th class='text-right'>count</th><th class='text-right'>incl.</th><th class='text-right'>excl.</th><th></th></tr>\n";
        for my $template (sort { $totals->{$b}->[1] <=> $totals->{$a}->[1] } keys %{$totals}) {
            my($count, $cumulative, $exclusive) = @{$totals->{$template}};
            my $percent = $total_time > 0 ? $exclusive/$total_time : 0;
            $out  .= sprintf("%-3s %4d %% %6.3f %6.3f %s\n", $count, $percent, $cumulative, $exclusive, $template);
            $html .= sprintf("<tr><td>%s</td><td class='text-right'>%d</td><td class='text-right'>%6.3fs</td><td class='text-right'>%6.3fs</td>\n", $template, $count, $cumulative, $exclusive);
            $html .= "<td class='text-right relative' style='width: 50px'>";
            $html .= "<div style='width: ".sprintf("%.0f", 100*$percent)."%; height: 20px;' class='WARNING absolute top-0 right-0'></div>";
            $html .= "<span class='absolute top-0 right-0' style='margin-right: 3px;'>".sprintf("%.1f", $percent*100)."%</span>";
            $html .= "</td>\n";
            $html .= "</tr>\n";
        }
        $html .= "</table>";
        if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 3) {
            print STDERR $out;
        }
        push @{$profiles}, { name => "TT ".$template, time => time(), text => $out, html => $html };

        # clear out results
        reset_stack();
    }

    # return value from process:
    return wantarray ? @return : $return[0];
}

sub get_profiles {
    return($profiles);
}

sub reset_profiles {
    $profiles = [];
    reset_stack();
    return;
}

sub reset_stack {
    $totals   = {};
    @stack    = ();
    return;
}

$Template::Config::CONTEXT = __PACKAGE__;

=head1 NAME

Thruk::Template::Context - Profiling TT Context

=head1 DESCRIPTION

Prints Template Toolkit profiling details

=head1 AUTHOR

  based on
  http://www.stonehenge.com/merlyn/LinuxMag/col75.html

=head1 METHODS

=head2 process

overridden process function which gathers statistics

=head2 get_profiles

return list of profiles

=head2 reset_profiles

reset saved profiles

=head2 reset_stack

reset initial stack

=cut

1;
