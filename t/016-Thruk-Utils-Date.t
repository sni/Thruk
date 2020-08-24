#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 28;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk');
use_ok('Thruk::Utils');
use_ok('Thruk::Utils::DateTime');
use Date::Calc qw/Localtime/;

my $c = TestUtils::get_c();

#########################
# test timezone detection
my $tz = $c->app->_detect_timezone();
ok($tz, "got a timezone: ".($tz || '<none>'));

# tests need a fixed timezone
$c->app->set_timezone("Europe/Berlin");

my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();

my $timepattern = [
   time()               => time(),
   (scalar localtime)   => time(),
  "now"                 => time(),
  "+60m"                => time() + 3600,
  "-60m"                => time() - 3600,
  "-3600"               => time() - 3600,
  "3600"                => time() + 3600,
  "now+3600"            => time() + 3600,
  "now + 3600"          => time() + 3600,
  "now + 2h"            => time() + 7200,
  "today"               => Thruk::Utils::DateTime::mktime($year,$month,$day,  0,0,0),
  "today-7200"          => Thruk::Utils::DateTime::mktime($year,$month,$day,  0,0,0) - 7200,
  "2019-09-17 00:25:02" => 1568672702,
  "2100-05-01 12:00:00" => 4112848800,
];

for(my $i = 0; $i < scalar @{$timepattern}; $i += 2) {
    my($pattern,$ts) = ($timepattern->[$i], $timepattern->[$i+1]);
    my $parsed = Thruk::Utils::parse_date(undef, $pattern);
    # round to 10 seconds to avoid failed tests on slow ci vms
    ok(abs($parsed - $ts) < 10, sprintf("parse_date returns correct timestamp for '%s' -> %s vs. %s", $pattern, $ts, ($parsed//"undef")))
        || diag(sprintf("parse_date returned:\n%s (expected)\n%s (got)\n", $ts, ($parsed//"undef")));
}

#########################
my $compare = [
    { date => [2020, 12, 1,  0, 0, 0], ts =>  1606777200 },
    { date => [2020, 12, 0, 24, 0, 0], ts =>  1606777200, skip_dc => 1 },
    { date => [1970,  1, 1,  1, 0, 1], ts =>  1          },
    { date => [1900,  1, 1,  0, 0, 0], ts => -2208992400, skip_dc => 1 },
    { date => [2038,  1, 1,  0, 0, 0], ts =>  2145913200 },
    { date => [2050,  1, 1,  0, 0, 0], ts =>  2524604400, skip_dc => 1 },
    { date => [2150,  1, 1,  0, 0, 0], ts =>  5680278000, skip_dc => 1 },
];
for my $comp (@{$compare}) {
    my $ts1 = Thruk::Utils::DateTime::mktime(@{$comp->{'date'}});
    is($ts1, $comp->{'ts'}, "Thruk::Utils::DateTime::mktime(".join(",", @{$comp->{'date'}}).")");

    unless($comp->{'skip_dc'}) {
        my $ts2 = Date::Calc::Mktime(@{$comp->{'date'}});
        is($ts1, $comp->{'ts'}, "Date::Calc::Mktime(".join(",", @{$comp->{'date'}}).")");
    }
}