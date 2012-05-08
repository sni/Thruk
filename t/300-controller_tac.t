use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 13;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::tac' }

my $pages = [
    '/thruk/cgi-bin/tac.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Tactical Monitoring Overview',
    );
}
