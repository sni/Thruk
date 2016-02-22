use strict;
use warnings;
use Test::More;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only'   if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};

    # enable plugin
    `cd plugins/plugins-enabled && ln -s ../plugins-available/core_scheduling .`;

    plan tests => 22;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
if(defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'}) {
    unshift @INC, 'plugins/plugins-available/core_scheduling/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    use_ok 'Thruk::Controller::core_scheduling';
};

my $pages = [
    { url => '/thruk/cgi-bin/core_scheduling.cgi', like => ['Checks per Second', 'Graph Options', ''] },
];

for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}

###########################################################
# test json some pages
my $json_hash_pages = [
    '/thruk/cgi-bin/core_scheduling.cgi?action=scheduling&json=true',
];

for my $url (@{$json_hash_pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an hash: ".$url);
}
