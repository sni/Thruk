#!/bin/bash

# read rc files if exist
[ -e ~/.profile ] && . ~/.profile
[ -e ~/.thruk   ] && . ~/.thruk

BASEDIR=$(dirname $0)/..

# git version
if [ -d $BASEDIR/.git -a -e $BASEDIR/lib/Thruk.pm ]; then
  export PERL5LIB="$PERL5LIB:$BASEDIR/lib";
  if [ "$OMD_ROOT" != "" -a "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$OMD_ROOT/etc/thruk"; fi
  if [ "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$BASEDIR/"; fi

# omd
elif [ "$OMD_ROOT" != "" ]; then
  export PERL5LIB=$OMD_ROOT/share/thruk/lib:$PERL5LIB
  if [ "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG="$OMD_ROOT/etc/thruk"; fi

# pkg installation
else
  export PERL5LIB=$PERL5LIB:@DATADIR@/lib:@THRUKLIBS@;
  if [ "$THRUK_CONFIG" = "" ]; then export THRUK_CONFIG='@SYSCONFDIR@'; fi
fi

eval 'exec perl -x $0 ${1+"$@"} ;'
    if 0;

#! -*- perl -*-
# vim: expandtab:ts=4:sw=4:syntax=perl
#line 33

use strict;
use warnings;
use Pod::Usage;
use Thruk::Utils;
use Getopt::Long;
use POSIX qw(mktime);

my $options = {
    'verbose'  => 0,
};
Getopt::Long::Configure('no_ignore_case');
Getopt::Long::Configure('bundling');
Getopt::Long::GetOptions (
   "h|help"             => \$options->{'help'},
   "v|verbose"          => sub { $options->{'verbose'}++ },
   "s|start=s"          => \$options->{'start'},
   "e|end=s"            => \$options->{'end'},
   "n|name=s"           => \$options->{'name'},
   "t|time=s"           => \$options->{'time'},
   "d|days=s"           => \$options->{'days'},
     "human"            => \$options->{'human'},
) or do {
    print "usage: $0 [<options>]\n";
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
    exit 3;
};
if($options->{'help'}) {
    print "usage: $0 [<options>]\n";
    Pod::Usage::pod2usage( { -verbose => 2, -exit => 3 } );
}

if(!$options->{'start'}) { print "missing start date - see --help for full usage.\n\n"; exit 3; }
my $start = parse_date($options->{'start'});
if(!$start) { print "Could not parse start date - see --help for full usage.\n$@\n"; exit 3; }

if(!$options->{'end'}) { $options->{'end'} = 'now'; }
my $end = parse_date($options->{'end'});
if(!$end) { print "Could not parse end date - see --help for full usage.\n$@\n"; exit 3; }

if(!$options->{'name'}) { print "missing timeperiod name - see --help for full usage.\n\n"; exit 3; }
if(!$options->{'time'}) { print "missing time definition - see --help for full usage.\n\n"; exit 3; }
my @times;
for my $t (split/,/mx, $options->{'time'}) {
    my($on, $off) = split(/\-/mx, $t);
    my($h1, $m1) = split(/:/mx, $on);
    my($h2, $m2) = split(/:/mx, $off);
    push @times, { on => [$h1, $m1], off => [$h2, $m2] };
}

# swap start/end if neccessary
if($start > $end) { my $tmp = $start; $start = $end; $end = $tmp; }

# expand days
my $days = {};
if($options->{'days'}) {
    for my $d (split/,/mx, $options->{'days'}) {
        my($f,$e) = split(m/\-/mx, $d);
        if($e) {
            for my $tmp ($f..$e) { $days->{$tmp} = 1; }
        } else {
            $days->{$f} = 1;
        }
    }
}
$days = undef if scalar keys %{$days} == 0;

print STDERR "generating timeperiod transitions\n" if $options->{'verbose'};
print STDERR "from: ".(localtime $start)."\n" if $options->{'verbose'};
print STDERR "till: ".(localtime $end)."\n" if $options->{'verbose'};

##############################################
# iterate days
my $cur = $start;
# round to next 0:00
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($cur);
$cur = mktime(0, 0, 0, $mday, $mon, $year, $wday, $yday, $isdst);
my $result = {};
my $last_end;
while($cur < $end) {
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($cur);

    if(!$days or $days->{$wday}) {
        for my $t (@times) {
            my $on  = mktime(0, $t->{'on'}->[1],  $t->{'on'}->[0],  $mday, $mon, $year, $wday, $yday, $isdst);
            my $off = mktime(0, $t->{'off'}->[1], $t->{'off'}->[0], $mday, $mon, $year, $wday, $yday, $isdst);
            if($result->{$on} && $result->{$on} =~ m/;0$/mx) {
                delete $result->{$on};
            } else {
                print STDERR "on:  ".(localtime $on)."\n" if $options->{'verbose'};
                $result->{$on} = "[".($options->{'human'} ? scalar localtime $on : $on)."] TIMEPERIOD TRANSITION: ".$options->{'name'}.";0;1";
            }
            $last_end = $t->{'off'}->[0];

            print STDERR "off:  ".(localtime $off)."\n" if $options->{'verbose'};
            $result->{$off} = "[".($options->{'human'} ? scalar localtime $off : $off)."] TIMEPERIOD TRANSITION: ".$options->{'name'}.";1;0";
        }
    } else {
        print STDERR "skipping  ".(localtime $cur)."\n" if $options->{'verbose'};
    }

    $cur = mktime(0, 0, 0, $mday, $mon, $year, $wday, $yday, $isdst);
    $cur = $cur + 86400;
}

my @sorted_ts = sort keys %{$result};

# assume open end and remove the last off state if it ends on 24:00
if($last_end && $last_end == 24) { pop @sorted_ts; }

for my $ts (@sorted_ts) {
    print $result->{$ts},"\n";
}

##############################################
sub parse_date {
    my($string) = @_;
    # expand MM-DD-YYYY to MM-DD-YYYY 00:00
    if($string =~ m/^\d+\-\d+\-\d+$/mx) { $string .= " 00:00"; }
    my $timestamp;
    eval {
        $timestamp = Thruk::Utils::parse_date(undef, $string);
    };
    print STDERR $@ if $options->{'verbose'};
    return $timestamp;
}

1;
__END__
##############################################

=head1 NAME

generate_timeperiod_transitions - Command line utility to generate simple timeperiod transitions

=head1 SYNOPSIS

  Usage: generate_timeperiod_transitions [options]

  Options:
  -h, --help                    Show this help message and exit
  -v, --verbose                 Print verbose output

  -n, --name=<name>             Name of the timeperiod to print.

  -s, --start=<start date>      Start date to begin with the timeperiod transitions.
                                Supports the following formats, ex.:
                                1404852850 (unix timestamp)
                                YYYY-MM-DD HH:MM:SS
                                YYYY-MM-DD HH:MM
                                MM-DD-YYYY HH:MM:SS
                                MM-DD-YYYY
                                Today,Yesterday, Last Year, ...
  -e, --end=<end date>          End date which supports the same formats like the
                                start date.
  -t, --time=<time definition>  Time definition, HH::MM
  -d, --days=<days definition>  Day definition, ex.: 1-5 = Mon-Fri
      --human                   Display human readable timestamps

=head1 DESCRIPTION

This script provides a way to generate simple timeperiod transitions which
then can be used in reports. The resulting logs must either be merged with
the existing logfile archive or imported in the logcache db.

=head1 OPTIONS

script has the following arguments

=over 4

=item B<-h> , B<--help>

    print help and exit

=item B<-v> , B<--verbose>

    print verbose output too

=item B<-n> I<name>, B<--name>=I<name>

  Name of the timeperiod to print.

=item B<-s> I<start date>, B<--start>=I<start date>

    Start date to begin with the timeperiod transitions.
    Supports the following formats, ex.:
    1404852850 (unix timestamp)
    YYYY-MM-DD HH:MM:SS
    YYYY-MM-DD HH:MM
    MM-DD-YYYY HH:MM:SS
    MM-DD-YYYY
    Today,Yesterday, Last Year, ...

=item B<-e> I<end date>, B<--end>=I<end date>

  End date which supports the same formats like the start date.

=item B<-t> I<time definition>, B<--time>=I<time definition>

    Time definition in the following form:
    HH:MM-HH:MM

    multiple time definitions must be comma seperated
    HH:MM-HH:MM,HH:MM-HH:MM,...

=item B<-d> I<day definition>, B<--days>=I<day definition>

    Day definition in the following form:
    1-5
    for starting with 0 = Sunday

    or 0,6
    for the weekend

=back

=head1 RETURN VALUE

generate_timeperiod_transitions returns 0 on success and >= 1 otherwise

=head1 EXAMPLES

  %> generate_timeperiod_transitions.pl --name=5x8 --start="Last Year" --end="Today" --time="10:00-18:00" --days=1-5 > /tmp/timeperiods.log
  %> thruk -a logcacheupdate --local /tmp/timeperiods.log

Print timeperiod transitions of last year.

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=cut
