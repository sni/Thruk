use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 99;
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
TestUtils::test_page(url => '/thruk', redirect => 1, location => '/thruk/');

#####################################################################
my $pages = [
    '/thruk/',
    '/thruk/docs/index.html',
    '/thruk/index.html',
    '/thruk/main.html',
    '/thruk/side.html',
    '/thruk/startup.html',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url' => $url,
    );
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
