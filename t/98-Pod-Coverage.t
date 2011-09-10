#!/usr/bin/env perl
#
# $Id$
#
use strict;
use warnings;
use File::Spec;
use Test::More;
use English qw(-no_match_vars);
use lib glob("plugins/plugins-enabled/*/lib");

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

my @modules = all_modules('lib', glob("plugins/plugins-enabled/*/lib"));
for my $module (@modules) {

    $module =~ s/plugins::plugins\-enabled::\w+::lib:://gmx;

    # check module and skip UPPERCASE constants which are reported as fail
    if($module eq 'Thruk::Controller::summary' or $module eq 'Thruk::Controller::trends') {
        pod_coverage_ok( $module, { also_private => [ qr/^[A-Z_]+$/ ]} );
    } else {
        pod_coverage_ok( $module );
    }
}

done_testing;
