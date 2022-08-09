use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 85;
}


BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###############################################################################
# fetch backend ids
my $test = TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/extinfo.cgi?type=0&view_mode=json',
    'like'   => [
                'peer_addr',
                'https://127.0.0.3:60443/demo/thruk/',
                'data_source_version',
            ],
);
my $procinfo = Cpanel::JSON::XS::decode_json($test->{'content'});
my $ids      = {map { $_->{'peer_name'} => $_->{'peer_key'} } values %{$procinfo}};
is(scalar keys %{$ids}, 11, 'got backend ids') || die("all backends required");
ok(defined $ids->{'tier1a'}, 'got backend ids II');

###############################################################################
# federated config tool
TestUtils::test_page(
    'url'  => '/thruk/cgi-bin/conf.cgi',
    'like' => ['tier1a'],
);
TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/conf.cgi?sub=objects&action=browser',
    'like'   => ['commands.cfg'],
    'follow' => 1,
);

###############################################################################
# create new object on tier3b and make sure its created on the correct backend
{
    my $peer_key = $ids->{'tier3b'};

    TestUtils::test_page(
        'url'           => '/thruk/r/config/objects?backend='.$peer_key,
        'post'          => {":FILE" => "105-test.cfg", ":TYPE" => "contact", "use" => "generic-contact", "contact_name" => "105-test-123"},
        'content_type'  => 'application/json; charset=utf-8',
        'like'          => ['created 1 objects successfully.', '105-test.cfg'],
    );

    TestUtils::test_page(
        'url'           => '/thruk/r/config/diff?backend='.$peer_key,
        'post'          => {},
        'content_type'  => 'application/json; charset=utf-8',
        'like'          => ['"peer_key" : "e984d"', '/omd/sites/demo/etc/naemon/conf.d/105-test.cfg'],
    );

    TestUtils::test_page(
        'url'           => '/thruk/r/config/save?backend='.$peer_key,
        'post'          => {},
        'content_type'  => 'application/json; charset=utf-8',
        'like'          => ['successfully saved changes for 1 site'],
    );

    TestUtils::test_page(
        'url'           => '/thruk/r/config/objects?contact_name=105-test-123',
        'content_type'  => 'application/json; charset=utf-8',
        'like'          => ['":PEER_KEY" : "e984d",', '":FILE" : "/omd/sites/demo/etc/naemon/conf.d/105-test.cfg:1"'],
    );

    TestUtils::test_page(
        'url'           => '/thruk/r/config/objects?contact_name=105-test-123',
        'method'        => 'DELETE',
        'content_type'  => 'application/json; charset=utf-8',
        'like'          => ['removed 1 objects successfully'],
    );

    TestUtils::test_page(
        'url'           => '/thruk/r/config/save?backend='.$peer_key,
        'post'          => {},
        'content_type'  => 'application/json; charset=utf-8',
        'like'          => ['successfully saved changes for 1 site'],
    );
};

###############################################################################
