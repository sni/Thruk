use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s ($ENV{'THRUK_CONFIG'} || '.').'/thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 124;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::showlog' }

my($host,$service) = TestUtils::get_test_service();

my $pages = [
    '/thruk/cgi-bin/showlog.cgi',
    '/thruk/cgi-bin/showlog.cgi?archive=-1',
    '/thruk/cgi-bin/showlog.cgi?archive=+1',
    '/thruk/cgi-bin/showlog.cgi?start=-1d&end=now',
    '/thruk/cgi-bin/showlog.cgi?start=-1d&end=now&oldestfirst=on',
    '/thruk/cgi-bin/showlog.cgi?entries=100&pattern=test&exclude_pattern=&start=-1d&end=now&archive=',
    '/thruk/cgi-bin/showlog.cgi?entries=100&pattern=test&exclude_pattern=blub&start=-1d&end=now&archive=',
    '/thruk/cgi-bin/showlog.cgi?host='.$host,
    '/thruk/cgi-bin/showlog.cgi?host='.$host.'&service='.$service,
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Event Log',
    );
}

$pages = [
# Excel Export
    '/thruk/cgi-bin/showlog.cgi?view_mode=xls', # all columns
    '/thruk/cgi-bin/showlog.cgi?view_mode=xls&columns=1&columns=2&columns=3&columns=7', # old style compat options
    '/thruk/cgi-bin/showlog.cgi?view_mode=xls&columns=Time&columns=Event&columns=Event+Detail',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/x-msexcel',
    );
}
