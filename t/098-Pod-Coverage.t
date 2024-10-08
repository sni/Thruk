#!/usr/bin/env perl
#
# $Id$
#
use warnings;
use strict;
use English qw(-no_match_vars);
use File::Spec;
use Test::More;

use lib glob("plugins/plugins-available/*/lib");

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval { require Test::Pod::Coverage; };

if ( $EVAL_ERROR ) {
   my $msg = 'Test::Pod::Coverage required to criticise pod';
   plan( skip_all => $msg );
}

eval "use Test::Pod::Coverage 1.00";

my @modules = all_modules('lib', glob("plugins/plugins-available/*/lib"));
for my $module (sort @modules) {
    $module =~ s/plugins::plugins\-available::[a-z0-9_-]+::lib:://gmx;

    # check module and skip UPPERCASE constants which are reported as fail
    pod_coverage_ok($module, { also_private => [ qr/^[A-Z_]+$/ ]});
}

done_testing;
