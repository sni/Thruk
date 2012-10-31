use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
    plan tests => 4;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::PDF");

my($baseurl,$a,$b,$url,$d,$e) = ('http://test.local/thruk/cgi-bin/', '', '',  '', '', '');

$url = '#';
is(Thruk::Utils::PDF::_replace_link($baseurl,$a,$b,$url,$d,$e), "#", "_replace_link($url)");

$url = 'avail.cgi';
is(Thruk::Utils::PDF::_replace_link($baseurl,$a,$b,$url,$d,$e), "http://test.local/thruk/cgi-bin/avail.cgi", "_replace_link($url)");

$url = '/index.html';
is(Thruk::Utils::PDF::_replace_link($baseurl,$a,$b,$url,$d,$e), "http://test.local/index.html", "_replace_link($url)");

done_testing();
