package Thruk::Timer;

use warnings;
use strict;
use Exporter 'import';
use POSIX ();
use Time::HiRes qw/gettimeofday tv_interval/;
use threads ();

our @EXPORT_OK = qw(timing_breakpoint);

my $starttime   = [gettimeofday];
my $lasttime    = $starttime;
my $lastmemory  = 0;
my $has_threads = 0;
my $has_memory  = 1;
my $header_once = 0;
require Thruk::Utils::IO;

sub _print_header_once {
    return if $header_once;
    $header_once = 1;
    # do not print column header during tests
    if(!$INC{'Test/More.pm'} && !$ENV{'THRUK_STRACE_DEBUG'}) {
        printf(STDERR "%-8s  %7s    %7s    %7s   %8s    %-50s %s\n",
                    "thread", "ttime", "Δtime", "tmem", "Δmem", "message", "caller");
        printf(STDERR ("-"x140)."\n");
    }
    return;
}

sub timing_breakpoint {
    my($msg, $reset, $lvl) = @_;
    return unless $ENV{'THRUK_TIMER'};
    my @caller  = caller($lvl || 0);

    &_print_header_once();

    my $tmp     = [gettimeofday];

    if($reset) { $lasttime = $tmp; }
    my $total    = tv_interval($starttime);
    my $elapsed  = tv_interval($lasttime);
    my $memory   = '';
    my $deltamem = '';
    if($has_memory) {
        my $status   = Thruk::Utils::IO::read('/proc/'.$$.'/status');
        if($status     =~ m/^VmRSS:\s*(\d+)\s+kB/smxo) {
            $memory     = $1;
            $deltamem   = $memory - $lastmemory;
            $lastmemory = $memory;
        } else {
            die("no VmRSS found in:\n".$status);
        }
    }
    my $thr    = 'global';
    if($has_threads) {
        $thr = (threads->tid()||'global');
    }
    my $callfile = $caller[1];
    $callfile =~ s|^.*lib/||mxo;
    my $info = sprintf("%-8s  %7s    %7s    %7s   %8s    %-50s %s:%d",
                    $thr,
                    $elapsed > 0.001 ? sprintf("%.2fs", $total)        : '------',
                    $elapsed > 0.001 ? sprintf("%.3fs", $elapsed)      : '------',
                    ($deltamem > 10 || $deltamem < -10) ? sprintf("%.1fMB", $memory/1024)   : '------',
                    ($deltamem > 10 || $deltamem < -10) ? sprintf("%.2fMB", $deltamem/1024) : '------',
                    $msg,
                    $callfile,
                    $caller[2],
    );
    if($ENV{'THRUK_STRACE_DEBUG'}) {
        $info = "THRUK-DEBUG: ".$info;
        POSIX::write(666, $info, length($info));
    } else {
        print STDERR $info,"\n";
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
