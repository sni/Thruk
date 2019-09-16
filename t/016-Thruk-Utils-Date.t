#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 15;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk');
use_ok('Thruk::Utils');
use Date::Calc qw/Localtime Mktime/;

my $c = TestUtils::get_c();

#########################
# test timezone detection
my $tz = $c->app->_detect_timezone();
ok($tz, "got a timezone: ".($tz || '<none>'));

my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();

my $timepattern = [
   time()             => time(),
   (scalar localtime) => time(),
  "now"               => time(),
  "+60m"              => time() + 3600,
  "-60m"              => time() - 3600,
  "-3600"             => time() - 3600,
  "3600"              => time() + 3600,
  "now+3600"          => time() + 3600,
  "now + 3600"        => time() + 3600,
  "now + 2h"          => time() + 7200,
  "today"             => Mktime($year,$month,$day,  0,0,0),
  "today-7200"        => Mktime($year,$month,$day,  0,0,0) - 7200,
];

for(my $i = 0; $i < scalar @{$timepattern}; $i += 2) {
    my($pattern,$ts) = ($timepattern->[$i], $timepattern->[$i+1]);
    my $parsed = Thruk::Utils::_parse_date($c, $pattern);
    # round to 10 seconds to avoid failed tests on slow ci vms
    ok(abs($parsed - $ts) < 10, sprintf("_parse_date returns correct timestamp for '%s' -> %s vs. %s", $pattern, $ts, ($parsed//"undef")))
        || diag(sprintf("_parse_date returned:\n%s (expected)\n%s (got)\n", $ts, ($parsed//"undef")));
}
