#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Long;
use POSIX qw/strftime mktime/;
use File::Slurp qw/read_file/;
use Term::ReadKey;
use lib $ENV{'OMD_ROOT'}.'/share/thruk/lib/';
use Thruk::Utils;

BEGIN {
    die("must be run inside OMD.") unless $ENV{'OMD_ROOT'};
}

END {
    ReadMode 0; # reset tty
}

my $options = {
  logs_per_day => 500000,
  input_source => $ENV{'OMD_ROOT'}.'/var/naemon/naemon.log',
  output_dir   => $ENV{'OMD_ROOT'}.'/var/naemon/archive',
  start        => "-7d",
  end          => "-1d",
};

Getopt::Long::GetOptions (
   "h|help"             => \$options->{'help'},
   "logs_per_day=i"     => \$options->{'logs_per_day'},
   "input_source=s"     => \$options->{'input_source'},
   "output_dir=s"       => \$options->{'output_dir'},
   "start=s"            => \$options->{'start'},
   "end=s"              => \$options->{'end'},
)  or do {
    print "usage: $0 [<options>]\nsee --help for detailed help.\n";
    exit 3;
};
if($options->{'help'}) {
    require Pod::Usage;
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
    exit(3);
}

# read input source
my $logs = [];
print "reading ".$options->{'input_source'}." ...";
for my $line (read_file($options->{'input_source'})) {
    $line =~ s/^\s*\[\d+\]\s*//gmx;
    push @{$logs}, $line;
}
my $length = scalar @{$logs};
print "done\n";

my $start = Thruk::Utils::parse_date(undef, $options->{'start'});
die("cannot parse start date") unless $start;
my $end = Thruk::Utils::parse_date(undef, $options->{'end'});
die("cannot parse end date") unless $end;

# confirm
my $file_num = int(($end - $start) / 86400);
my $input_size = (stat($options->{'input_source'}))[7];
printf("creating %d logfiles with %d entries each file.\n", $file_num, $options->{'logs_per_day'});
printf("this will result in roughly %.1f%s of logfiles.\n", Thruk::Utils::reduce_number($file_num * $options->{'logs_per_day'} * ($input_size / scalar @{$logs}), "B", 1024));
printf("press any key to continue or ctrl+c to abort.\n");
ReadMode('cbreak');
ReadKey(0);
ReadMode 0; # reset tty

while(1) {
  my $file = $options->{'output_dir'}.'/'.strftime("%d-%m-%Y", localtime($start)).".log";
  my $ts_daystart = Thruk::Utils::DateTime::mktime(strftime("%Y", localtime($start)), strftime("%m", localtime($start)), strftime("%d", localtime($start)), 0,0,0);
  my $ts_dayend   = $ts_daystart+(26*3600); # add 26 hours to compensate daylight saving timeshift
     $ts_dayend   = Thruk::Utils::DateTime::mktime(strftime("%Y", localtime($ts_dayend)), strftime("%m", localtime($ts_dayend)), strftime("%d", localtime($ts_dayend)), 0,0,0);
  my $daylength = $ts_dayend - $ts_daystart;
  my $step = $daylength / $options->{'logs_per_day'};
  printf("writing %s (daylength: %ds) ... ", $file, $daylength);
  open(my $fh, ">", $file) or die("cannot write to $file: $!");
  my $ts = $ts_daystart;
  for my $i (1..$options->{'logs_per_day'}) {
    my $line = $logs->[int(rand($length - 1))];
    printf($fh "[%d] %s", int($ts), $line);
    $ts += $step;
  }
  close($fh);
  print "done\n";
  $start = $ts_dayend;
  if($start > $end) { last; }
}

1;
__END__

=head1 NAME

fake_log_archive.pl - Create Random Logfile Archive

=head1 SYNOPSIS

  Usage: fake_log_archive.pl [options]

  Options:
    -h, --help                    Show this help message and exit

    --logs_per_day=<nr>           Set how many log entries per day should be created. Default: 500,000
    --input_source=<logfile>      Set source logfile.                                 Default: var/log/naemon.log
    --output_dir=<folder>         Set archive folder.                                 Default: var/naemon/archive/
    --start=<time definition>     Set start date.                                     Default: -7d
    --end=<time definition>       Set end date.                                       Default: -1d

=head1 DESCRIPTION

This script creates a random fake logfile archive by reading the input logfile and
writing random entries with new timestamps into the archive files.

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=cut
