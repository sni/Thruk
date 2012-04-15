use strict;
use warnings;
use Test::More tests => 12;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
if(defined $ENV{'CATALYST_SERVER'}) {
    unshift @INC, 'plugins/plugins-available/reports/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::reports';
};

my $pages = [
    '/thruk/cgi-bin/reports.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Reports',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
