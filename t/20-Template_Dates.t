#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 4;
use Data::Dumper;

use_ok('Template::Plugin::Date');

my $date = new Template::Plugin::Date;

isa_ok($date, 'Template::Plugin::Date');

#########################
# checks against localtime will fail otherwise
$ENV{'TZ'} = "CET";

#########################
# do some test formations
my $t1 = $date->format('2010-06-03 10:03:42', '%s');
is($t1, 1275552222, 'time string to timestamp');

my $t2 = $date->format($t1, '%Y-%m-%d %H:%M:%S');
is($t2, '2010-06-03 10:03:42', 'timestamp to time string');