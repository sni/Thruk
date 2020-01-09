use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 70;
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
    { url => '/thruk/cgi-bin/bp.cgi?action=new&bp_label=New Test Business Process', follow => 1, like => 'New Test Business Process' },
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Business Process'});
    TestUtils::test_page(%{$test});
}

###########################################################
# test json some pages
my $json_pages = [
    '/thruk/cgi-bin/bp.cgi?action=templates',
    '/thruk/r/thruk/bp',
];

for my $url (@{$json_pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array: ".$url);
}

###########################################################
# test json some pages
my $json_hash_pages = [
    '/thruk/cgi-bin/bp.cgi?view_mode=json',
];

for my $url (@{$json_hash_pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an hash: ".$url);
}

###########################################################
# test excel export
my $xls_pages = [
    '/thruk/cgi-bin/bp.cgi?view_mode=xls',
];

for my $url (@{$xls_pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/x-msexcel',
    );
}

###########################################################
# clean up
my $page = TestUtils::test_page(
    'url'          => "/thruk/r/thruk/bp?name=New%20Test%20Business%20Process&columns=id",
    'content_type' => 'application/json;charset=UTF-8',
);
my $data = decode_json($page->{'content'});
is(ref $data, 'ARRAY', "json result is an array");

$page = TestUtils::test_page(
    'url'          => "/thruk/r/thruk/bp/".$data->[0]->{'id'},
    'method'       => "DELETE",
    'content_type' => 'application/json;charset=UTF-8',
    'like'         => ['business process sucessfully removed'],
);