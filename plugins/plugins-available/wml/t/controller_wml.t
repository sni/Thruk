use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only'   if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};
    plan tests => 37;

    # enable plugin
    `cd plugins/plugins-enabled && ln -s ../plugins-available/wml .`;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    use_ok 'Thruk::Controller::wml';
};

my $pages = [
    '/thruk/cgi-bin/statuswml.cgi',
    '/thruk/cgi-bin/statuswml.cgi?style=uprobs',
    '/thruk/cgi-bin/statuswml.cgi?style=aprobs',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'            => $url,
        'like'           => [ 'WML Thruk' ],
    );
}

# restore default
`cd plugins/plugins-enabled && rm -f wml`;

