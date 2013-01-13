use strict;
use warnings;
use Test::More tests => 37;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan skip_all => 'local test only'   if defined $ENV{'CATALYST_SERVER'};

    # enable plugin
    `cd plugins/plugins-enabled && ln -s ../plugins-available/wml .`;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

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

