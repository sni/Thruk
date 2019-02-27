#!/usr/bin/env perl

use warnings;
use strict;
use utf8;
use Test::More;
use Encode qw/encode_utf8/;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 17;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils');
use_ok('Thruk::Utils::IO');

my $c = TestUtils::get_c();

#########################
# encoding
for my $str ('abc', 'öäüß', 'test€') {
  my $orig = $str;
  my $test = $orig;
  $test = Thruk::Utils::decode_any($test);
  is($test, $orig, 'decode_any '.encode_utf8($test));

  $test = $orig;
  my($rc, $output) = Thruk::Utils::IO::cmd($c, ["/usr/bin/printf", "%s", $test]);
  is($rc, 0, "printf got rc 0");
  is($output, $orig, "got correct string");

  $test = $orig;
  ($rc, $output) = Thruk::Utils::IO::cmd($c, '/usr/bin/printf "%s" "'.$test.'"');
  is($rc, 0, "printf got rc 0");
  is($output, $orig, "got correct string");
}

#########################
