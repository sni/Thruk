package Thruk::Template::Context;
use base qw(Template::Context);

use strict;
use warnings;

my @stack;
my %totals;
my $profiles = [];

sub process {
  my($self, @args) = @_;

  my $template = $args[0];
  if(UNIVERSAL::isa($template, "Template::Document")) {
    $template = $template->name || $template;
  }

  push @stack, [time, times];

  my @return = wantarray ?
    $self->SUPER::process(@args) :
      scalar $self->SUPER::process(@args);

  my @delta_times = @{pop @stack};
  @delta_times = map { $_ - shift @delta_times } time, times;
  for(0..$#delta_times) {
    $totals{$template}[$_] += $delta_times[$_];
    for my $parent (@stack) {
      $parent->[$_] += $delta_times[$_] if @stack; # parent adjust
    }
  }
  # count of calls
  $totals{$template}[5] ++;

  unless(@stack) {
    my $out = "";
    ## top level again, time to display results
    $out .= "TT ".$template. ":\n";
    $out .= sprintf("%3s %6s %3s %6s %6s %6s %6s %s\n", qw(cnt percent clk user sys cuser csys template));
    my $total = 0;
    for my $template (keys %totals) { $total += $totals{$template}->[1]; }
    for my $template (sort { $totals{$b}->[1] <=> $totals{$a}->[1] } keys %totals) {
      my @values  = @{$totals{$template}};
      my $percent = $total > 0 ? $values[1]/$total*100 : 0;
      $out .= sprintf("%3d %5d %% %3d %6.2f %6.2f %6.2f %6.2f %s\n", $values[5], $percent , @values[0..4], $template);
    }
    if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 3) {
      print STDERR $out;
    }
    push @{$profiles}, $out;

    # clear out results
    %totals = ();
  }

  # return value from process:
  return wantarray ? @return : $return[0];
}

sub get_profiles {
  return($profiles);
}

sub reset_profiles {
  $profiles = [];
  return;
}

$Template::Config::CONTEXT = __PACKAGE__;

=head1 NAME

Thruk::Template::Context - Profiling TT Context

=head1 DESCRIPTION

Prints Template Toolkit profiling details

=head1 AUTHOR

  http://www.stonehenge.com/merlyn/LinuxMag/col75.html

=head1 METHODS

=head2 process

overridden process function which gathers statistics

=head2 get_profiles

return list of profiles

=head2 reset_profiles

reset saved profiles

=cut

1;
