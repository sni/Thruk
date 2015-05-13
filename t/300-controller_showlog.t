use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 119;
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
    '/thruk/cgi-bin/showlog.cgi?start=2010-03-02+00%3A00%3A00&end=2010-03-03+00%3A00%3A00',
    '/thruk/cgi-bin/showlog.cgi?start=2010-03-02+00%3A00%3A00&end=2010-03-03+00%3A00%3A00&oldestfirst=on',
    '/thruk/cgi-bin/showlog.cgi?entries=100&pattern=test&exclude_pattern=&start=2013-03-05+00%3A00&end=2013-03-06+00%3A00&archive=',
    '/thruk/cgi-bin/showlog.cgi?entries=100&pattern=test&exclude_pattern=blub&start=2013-03-05+00%3A00&end=2013-03-06+00%3A00&archive=',
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
    '/thruk/cgi-bin/showlog.cgi?view_mode=xls',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/x-msexcel',
    );
}
