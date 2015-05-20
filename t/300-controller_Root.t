use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 121;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::Root' }

#####################################################################
SKIP: {
    skip 'external tests', 10 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    TestUtils::test_page(url => '/', redirect => 1, location => '/thruk/');
}
my $product = 'thruk';
if($ENV{'PLACK_TEST_EXTERNALSERVER_URI'} && $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} =~ m|https?://[^/]+/(.*)$|) { $product = $1; }
if($ENV{'PLACK_TEST_EXTERNALSERVER_URI'} && $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} =~ m/naemon/) {
    # redirect happens during login with cookie auth
    TestUtils::test_page(url => '/thruk');
} else {
    SKIP: {
        skip 'its one test less with redirects', 1;
    }
    TestUtils::test_page(url => '/thruk', redirect => 1, location => '/'.$product .'/');
}
my $res = TestUtils::test_page(url => '/thruk/cgi-bin/blah.cgi', fail => 1, like => 'This page does not exist');
is($res->{'code'}, 404, 'got page not found');

#####################################################################
my $pages = [
    '/thruk/',
    '/thruk/docs/index.html',
    '/thruk/index.html',
   { url => '/thruk/main.html', like => ['Check for updates', 'Thruk Monitoring Webinterface', 'Thruk Developer Team'] },
   { url => '/thruk/side.html', like => ['Home', 'Documentation', 'Hosts', 'Availability', 'Problems'] },
    '/thruk/startup.html',
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {});
    TestUtils::test_page(%{$test});
}
SKIP: {
    skip 'external tests', 12 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    # test works local only because we modify the config here
    my($res, $c) = ctx_request('/thruk/side.html');

    $c->app->config->{'use_frames'} = 1;
    $c->app->config->{'User'}->{$c->stash->{'remote_user'}}->{'start_page'} = '/thruk/cgi-bin/status.cgi?blah';
    TestUtils::test_page(
        'url'      => '/thruk/',
        'like'     => 'status.cgi\?blah',
    );
};
