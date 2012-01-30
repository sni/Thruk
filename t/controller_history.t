use strict;
use warnings;
use Test::More tests => 130;

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
    '/thruk/cgi-bin/history.cgi?start=2010-03-02+00%3A00%3A00&end=2010-03-03+00%3A00%3A00',
    '/thruk/cgi-bin/history.cgi?start=2010-03-02+00%3A00%3A00&end=2010-03-03+00%3A00%3A00&oldestfirst=on',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Alert History',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

$pages = [
# Excel Export
    '/thruk/cgi-bin/history.cgi?view_mode=xls',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'unlike'       => [ 'internal server error', 'HASH', 'ARRAY' ],
        'content_type' => 'application/x-msexcel',
    );
}
