use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    my $tests = 258;
    $tests = $tests - 32 if $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => $tests;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    use_ok 'Thruk::Controller::mobile';
};

my($host,$service) = TestUtils::get_test_service();

my $choose_pages = [
    '/thruk',
    '/thruk/',
    '/thruk/index.html',
];
for my $url (@{$choose_pages}) {
    next if $url eq '/thruk' and $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    TestUtils::set_cookie( 'thruk_mobile', 0, -1);
    TestUtils::test_page(
        'url'      => $url,
        'like'     => 'Do you want to use the mobile version',
        'agent'    => 'iPhone',
        'follow'   => 1,
    );
    TestUtils::set_cookie( 'thruk_mobile', 0, 120);
    TestUtils::test_page(
        'url'      => $url,
        'unlike'   => 'Do you want to use the mobile version',
        'like'     => '<head>',
        'agent'    => 'iPhone',
        'follow'   => 1,
    );
    TestUtils::set_cookie( 'thruk_mobile', 1, 120);
    TestUtils::test_page(
        'url'      => $url,
        'unlike'   => 'Do you want to use the mobile version',
        'like'     => 'ThrukMobile',
        'agent'    => 'iPhone',
        'follow'   => 1,
    );
    TestUtils::set_cookie( 'thruk_mobile', 0, -1);
}

my $pages = [
    '/thruk/cgi-bin/mobile.cgi',
    '/thruk/cgi-bin/mobile.cgi#problems',
    '/thruk/cgi-bin/mobile.cgi#options',
    '/thruk/cgi-bin/mobile.cgi#hosts',
    '/thruk/cgi-bin/mobile.cgi#hosts_list?hoststatustypes=2',
    '/thruk/cgi-bin/mobile.cgi#host?host='.$host,
    '/thruk/cgi-bin/mobile.cgi#services',
    '/thruk/cgi-bin/mobile.cgi#service?host='.$host.'&service='.$service,
    '/thruk/cgi-bin/mobile.cgi#alerts',
    '/thruk/cgi-bin/mobile.cgi#notifications',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Mobile Thruk',
    );
}

my $jsonpages = [
    '/thruk/cgi-bin/mobile.cgi?data=alerts',
    '/thruk/cgi-bin/mobile.cgi?data=notifications',
    '/thruk/cgi-bin/mobile.cgi?data=host_stats',
    '/thruk/cgi-bin/mobile.cgi?data=service_stats',
    '/thruk/cgi-bin/mobile.cgi?data=hosts',
    '/thruk/cgi-bin/mobile.cgi?data=services',
];

for my $url (@{$jsonpages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an array");
}
