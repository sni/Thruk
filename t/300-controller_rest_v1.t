use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;
use Cpanel::JSON::XS qw/decode_json/;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 407;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::rest_v1' }

my($host,$service) = TestUtils::get_test_service();

my $list_pages = [
    '/',
    '/v1/',
    '/index',
    '/sites',
    '/config/diff',
    '/config/files',
    '/config/objects',
    '/commands',
    '/comments',
    '/contactgroups',
    '/contacts',
    '/downtimes',
    '/hostgroups',
    '/hosts',
    '/hosts/'.$host,
    '/hosts/'.$host.'/services',
    '/logs',
    '/alerts',
    '/notifications',
    '/processinfo',
    '/servicegroups',
    '/services',
    '/timeperiods',
    '/lmd/sites',
    '/thruk/bp',
    '/thruk/cluster',
    '/thruk/recurring_downtimes',
    '/thruk/jobs',
    '/thruk/panorama',
    '/thruk/reports',
    '/thruk/broadcasts',
    '/thruk/sessions',
    '/thruk/api_keys',
];

my $hash_pages = [
    '/checks/stats',
    '/hosts/stats',
    '/hosts/totals',
    '/processinfo/stats',
    '/services/stats',
    '/services/totals',
    '/thruk',
    '/thruk/config',
];

for my $url (@{$list_pages}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r'.$url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array: ".$url);
}

for my $url (@{$hash_pages}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r'.$url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is a hash: ".$url);
}

################################################################################
my $content = read_file(__FILE__);
my($paths, $keys, $docs) = Thruk::Controller::rest_v1::get_rest_paths();
for my $p (sort keys %{$paths}) {
    if($paths->{$p}->{'GET'}) {
        next if $p =~ m%<%mx;
        next if $p =~ m%heartbeat%mx;
        if($content !~ m%$p%mx) {
            fail("missing test case for ".$p);
        }
    }
}

################################################################################
# check if there is a doc entry for every registered path and method
for my $registered (@{$Thruk::Controller::rest_v1::rest_paths}) {
    my($method, $regex) = @{$registered};
    my $found = 0;
    for my $p (sort keys %{$paths}) {
        my $available_methods = $paths->{$p};
        $p =~ s/<[^>]*>/0/gmx;
        if($p =~ $regex && $available_methods->{$method}) {
            $found = 1;
        }
    }
    if(!$found) {
        fail("missing documentation for $method $regex");
    }
}

################################################################################
# make sure PUT requests are handled like POST
TestUtils::test_page(
    'url'          => '/thruk/r/thruk/reports',
    'content_type' => 'application/json;charset=UTF-8',
    'method'       => 'PUT',
    'post'         => {},
    'like'         => ['invalid report template'],
    'fail'         => 1,
);

################################################################################
{
    my $c = TestUtils::get_c();
    _set_params($c, {'test' => 1});
    my $filter = Thruk::Controller::rest_v1::_livestatus_filter($c);
    my $expect = [{ 'test' => { '=' => 1 }}];
    is_deeply($filter, $expect, "simple livestatus filter");

    _set_params($c, { q => 'host = "test" and time > 1 and time < 10'});
    $filter = Thruk::Controller::rest_v1::_livestatus_filter($c);
    $expect = [[{
        '-and' => [
                { 'host' => { '=' => 'test' } },
                { 'time' => { '>' => '1'    } },
                { 'time' => { '<' => '10'   } }
            ]
    }]];
    is_deeply($filter, $expect, "simple livestatus filter");
};

################################################################################
# test query filter
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/logs?q=***host_name = "test" AND time > 1 AND time < 10***',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['\[\]'],
    );
};

################################################################################
# test query filter II
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/logs?q=***host_name = "test" AND (time > 1 AND time < 10)***',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['\[\]'],
    );
};

################################################################################
# test query filter when the filtered item is not in the columns list
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name&state[ne]=5',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['name'],
    );
};

################################################################################
# test query filter when the filtered item is not in the columns list II
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name&q=***state >= 0***',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['name'],
    );
};

################################################################################
# test query filter when the filtered item is not in the columns list III
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name&state[gte]=0',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['name'],
    );
};

################################################################################
# test sorting empty result set
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?q=***(groups>="does not exist")***&sort=_UNKNOWN_CUSTOM_VAR',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['\[\]'],
    );
};

################################################################################
# test columns when no column given
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?q=***(name != "does not exist")***',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['"state"'],
    );
};

################################################################################
# test count(*) with no matches
{
    local $ENV{'NO_POST_TOKEN'} = 1;
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?state=-1&columns=count(*)',
        'content_type' => 'application/json;charset=UTF-8',
        'method'       => 'GET',
        'like'         => ['count\(\*\)', '0'],
    );
};

################################################################################
sub _set_params {
    my($c, $params) = @_;
    for my $key (keys %{$c->req->parameters}) {
        delete $c->req->parameters->{$key};
    }
    for my $key (keys %{$params}) {
        $c->req->parameters->{$key} = $params->{$key};
    }
}
################################################################################
