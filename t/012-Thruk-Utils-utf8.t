#!/usr/bin/env perl

use warnings;
use strict;
use utf8;
use Test::More;
use Encode qw/encode_utf8/;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 4;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils');

#########################
# encoding
for my $str ('abc', 'öäüß', 'test€') {
  my $test = $str;
  $test = Thruk::Utils::decode_any($test);
  is($str, $test, 'decode_any '.encode_utf8($test));
}

#########################
