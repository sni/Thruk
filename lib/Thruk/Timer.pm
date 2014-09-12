package Thruk::Timer;

use warnings;
use strict;
use File::Slurp qw/read_file/;
use Time::HiRes qw/gettimeofday tv_interval/;
use Exporter 'import';
our @EXPORT_OK = qw(timing_breakpoint);

my $starttime   = [gettimeofday];
my $lasttime    = $starttime;
my $has_threads = 0;
my $has_memory  = 1;
sub timing_breakpoint {
    my($msg) = @_;
    my @caller = caller;
    my $tmp = [gettimeofday];
    my $elapsed;
    if($lasttime) {
        my $total  = tv_interval($starttime);
        $elapsed   = tv_interval($lasttime);
        my $status = read_file('/proc/'.$$.'/status');
        my $memory = '';
        if($has_memory) {
            $status =~ m/^VmRSS:\s*(\d+)\s+kB/smxo;
            $memory = $1;
        }
        my $thr    = 'global';
        if($has_threads) {
            $thr = (threads->tid()||'global');
        }
        printf(STDERR "%-8s  %6ss    %6ss    %6sMB     %-40s %s:%d\n",
                        $thr,
                        sprintf("%.3f", $total),
                        sprintf("%.3f", $elapsed),
                        sprintf("%.2f", $memory/1024),
                        $msg,
                        $caller[1],
                        $caller[2],
        );
    }
    $lasttime = $tmp;
    return $elapsed;
}

1;
__END__

=head1 NAME

Thruk::Timer - Helper class to debug timings and performance

=head1 SYNOPSIS

  use Thruk::Timer;

  timing_breakpoint($msg);
  ...
  timing_breakpoint($next_msg);

=head1 DESCRIPTION

C<Thruk::Timer> provides a simple timing function.

=head1 METHODS

=head2 timing_breakpoint

    timing_breakpoint($msg)

sets breakpoint with message

=cut

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
