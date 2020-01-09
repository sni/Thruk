use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 140;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::history' }

my $pages = [
    '/thruk/cgi-bin/history.cgi',
    '/thruk/cgi-bin/history.cgi?host=all',
    '/thruk/cgi-bin/history.cgi?host=unknownhost',
    '/thruk/cgi-bin/history.cgi?host=unknownhost&service=unknownservice',
    '/thruk/cgi-bin/history.cgi?archive=1&host=all&noflapping=0&nodowntime=0&nosystem=0&type=0&statetype=0',
    '/thruk/cgi-bin/history.cgi?archive=1&host=all&noflapping=1&nodowntime=0&nosystem=0&type=0&statetype=0',
    '/thruk/cgi-bin/history.cgi?archive=1&host=all&noflapping=0&nodowntime=1&nosystem=0&type=0&statetype=0',
    '/thruk/cgi-bin/history.cgi?archive=1&host=all&noflapping=0&nodowntime=0&nosystem=1&type=0&statetype=0',
    '/thruk/cgi-bin/history.cgi?archive=1&host=all&noflapping=0&nodowntime=0&nosystem=0&type=0&statetype=1',
    '/thruk/cgi-bin/history.cgi?start=-1d&end=now',
    '/thruk/cgi-bin/history.cgi?start=-1d&end=now&oldestfirst=on',
    '/thruk/cgi-bin/history.cgi?entries=100&start=-1d&end=now&archive=&host=all&statetype=0&type=4',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Alert History',
    );
}

$pages = [
# Excel Export
    '/thruk/cgi-bin/history.cgi?view_mode=xls',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/x-msexcel',
    );
}
