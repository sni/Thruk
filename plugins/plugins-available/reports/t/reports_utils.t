use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'local test only'   if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};
    plan tests => 4;

    # enable plugin
    `cd plugins/plugins-enabled && rm -f reports2`;
    `cd plugins/plugins-enabled && ln -s ../plugins-available/reports .`;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

END {
    # restore default
    `cd plugins/plugins-enabled && rm -f reports`;
    `cd plugins/plugins-enabled && ln -s ../plugins-available/reports2 .`;
    unlink('root/thruk/plugins/reports');
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
