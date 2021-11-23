#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Long;
use POSIX qw/strftime mktime/;
use Term::ReadKey;

BEGIN {
    die("must be run inside OMD.") unless $ENV{'OMD_ROOT'};
    push @INC, $ENV{'OMD_ROOT'}.'/share/thruk/lib/';
}

use Thruk::Utils ();
use Thruk::Utils::DateTime ();

END {
    ReadMode 0; # reset tty
}

my $options = {
  logs_per_day => 500000,
  input_source => $ENV{'OMD_ROOT'}.'/var/naemon/naemon.log',
  output_dir   => $ENV{'OMD_ROOT'}.'/var/naemon/archive',
  start        => "-7d",
  end          => "-1d",
  force        => 0,
};

Getopt::Long::GetOptions (
   "h|help"             => \$options->{'help'},
   "logs_per_day=i"     => \$options->{'logs_per_day'},
   "input_source=s"     => \$options->{'input_source'},
   "output_dir=s"       => \$options->{'output_dir'},
   "start=s"            => \$options->{'start'},
   "end=s"              => \$options->{'end'},
   "f|force"            => \$options->{'force'},
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
for my $line (Thruk::Utils::IO::read_as_list($options->{'input_source'})) {
    $line =~ s/^\s*\[\d+\]\s*//gmx;
    chomp($line);
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
if(!$options->{'force'}) {
    printf("press any key to continue or ctrl+c to abort.\n");
    ReadMode('cbreak');
    ReadKey(0);
    ReadMode 0; # reset tty
}

while(1) {
  my $file = $options->{'output_dir'}.'/'.strftime("%d-%m-%Y", localtime($start)).".log";
  my $ts_daystart = Thruk::Utils::DateTime::start_of_day($start);
  my $ts_dayend   = Thruk::Utils::DateTime::start_of_day($ts_daystart+(26*3600)); # add 26 hours to compensate daylight saving timeshift
  my $daylength = $ts_dayend - $ts_daystart;
  my $step = $daylength / $options->{'logs_per_day'};
  printf("writing %s (daylength: %ds) ... ", $file, $daylength);
  open(my $fh, ">", $file) or die("cannot write to $file: $!");
  my $ts = $ts_daystart;
  for my $i (1..$options->{'logs_per_day'}) {
    my $line = $logs->[int(rand($length - 1))];
    printf($fh "[%d] %s\n", int($ts), $line);
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
    --force                       Don't ask for user confirmation

=head1 DESCRIPTION

This script creates a random fake logfile archive by reading the input logfile and
writing random entries with new timestamps into the archive files.

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=cut
