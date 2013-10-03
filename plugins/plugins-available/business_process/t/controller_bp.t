use strict;
use warnings;
use Test::More;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 20;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test some pages
my $pages = [
    '/thruk/cgi-bin/bp.cgi',
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Business Process'});
    TestUtils::test_page(%{$test});
}

###########################################################
# test json some pages
my $json_pages = [
    '/thruk/cgi-bin/bp.cgi?action=templates',
];

for my $url (@{$json_pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array: ".$url);
}