use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;
use URI::Escape qw/uri_escape/;

use Thruk::Utils::IO ();

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 588;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::rest_v1' }

TestUtils::set_test_user_token();
my($host,$service) = TestUtils::get_test_service();

my $list_pages = [
    '/',
    '/v1/',
    '/index',
    '/sites',
    '/config/diff',
    '/config/precheck',
    '/config/files',
    '/config/objects',
    '/config/fullobjects',
    '/commands',
    '/comments',
    '/contactgroups',
    '/contacts',
    '/downtimes',
    '/hostgroups',
    '/hosts',
    '/hosts/availability',
    '/hosts/'.uri_escape($host),
    '/hosts/'.uri_escape($host).'/services',
    '/hosts/outages',
    '/hosts/'.uri_escape($host).'/outages',
    '/logs',
    '/alerts',
    '/notifications',
    '/processinfo',
    '/servicegroups',
    '/services',
    '/services/availability',
    '/services/outages',
    '/services/'.uri_escape($host).'/'.uri_escape($service),
    '/services/'.uri_escape($host).'/'.uri_escape($service).'/outages',
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
    '/thruk/users',
    '/thruk/api_keys',
    '/thruk/logcache/stats',
];

my $hash_pages = [
    '/checks/stats',
    '/hosts/stats',
    '/hosts/totals',
    '/hosts/'.uri_escape($host).'/availability',
    '/processinfo/stats',
    '/services/stats',
    '/services/totals',
    '/services/'.uri_escape($host).'/'.uri_escape($service).'/availability',
    '/thruk',
    '/thruk/config',
    '/thruk/stats',
    '/thruk/metrics',
    '/thruk/whoami',
];

# get config from rest endpoint
my $config = {};
{
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r/thruk/config',
        'content_type' => 'application/json; charset=utf-8',
    );
    $config = decode_json($page->{'content'});
}

for my $url (@{$list_pages}) {
    SKIP: {
        skip "skipped, logcache is disabled ", 8 if ($url =~ m/logcache/mx && !$config->{'logcache'});

        if($url =~ m/logs/mx) {
            $url = $url.'?limit=100';
        }

        my $page = TestUtils::test_page(
            'url'          => '/thruk/r'.$url,
            'content_type' => 'application/json; charset=utf-8',
        );
        my $data = decode_json($page->{'content'});
        is(ref $data, 'ARRAY', "json result is an array: ".$url);
    };
}

for my $url (@{$hash_pages}) {
    my $page = TestUtils::test_page(
        'url'          => '/thruk/r'.$url,
        'content_type' => 'application/json; charset=utf-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is a hash: ".$url);
}

################################################################################
my $content = Thruk::Utils::IO::read(__FILE__);
my($paths, $keys, $docs) = Thruk::Controller::rest_v1::get_rest_paths();
for my $p (sort keys %{$paths}) {
    if($paths->{$p}->{'GET'}) {
        next if $p =~ m%<%mx;
        next if $p =~ m%heartbeat%mx;
        next if $p =~ m%/editor%mx;
        next if $p =~ m%/nc/%mx;
        next if $p =~ m%/node-control/%mx;
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
    'content_type' => 'application/json; charset=utf-8',
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
                { 'host_name' => { '=' => 'test' } },
                { 'time' => { '>' => '1'    } },
                { 'time' => { '<' => '10'   } }
            ]
    }]];
    is_deeply($filter, $expect, "simple livestatus filter");

    _set_params($c, { q => '_CITY = "Munich" and rta > 1'});
    $filter = Thruk::Controller::rest_v1::_livestatus_filter($c);
    $expect = [[{
        '-and' => [
                { '_CITY' => { '=' => 'Munich' } },
                { 'rta'   => { '>' => '1' } },
            ]
    }]];
    is_deeply($filter, $expect, "simple livestatus filter");
};

################################################################################
# test query filter
{
    TestUtils::test_page(
        'url'          => '/thruk/r/logs?q=***host_name = "test" AND time > 1 AND time < 10***',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['\[\]'],
    );
};

################################################################################
# test query filter II
{
    TestUtils::test_page(
        'url'          => '/thruk/r/logs?q=***host_name = "test" AND (time > 1 AND time < 10)***',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['\[\]'],
    );
};

################################################################################
# test query filter when the filtered item is not in the columns list
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name&state[ne]=5',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['name'],
    );
};

################################################################################
# test query filter when the filtered item is not in the columns list II
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name&q=***state >= 0***',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['name'],
    );
};

################################################################################
# test query filter when the filtered item is not in the columns list III
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name&state[gte]=0',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['name'],
    );
};

################################################################################
# test sorting empty result set
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?q=***(groups>="does not exist")***&sort=_UNKNOWN_CUSTOM_VAR',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['\[\]'],
    );
};

################################################################################
# test columns when no column given
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?q=***(name != "does not exist")***',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['"state"'],
    );
};

################################################################################
# test count(*) with no matches
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?state=-1&columns=count(*)',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['count\(\*\)', '0'],
    );
};

################################################################################
# test aggregation with renamed labels
{
    TestUtils::test_page(
        'url'          => '/thruk/r/thruk/sessions?columns=count(*):renamed_label&active=-99',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['"renamed_label" : 0'],
    );
};

################################################################################
# normal query with renamed labels
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name:renamed_label&limit=1',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['"renamed_label"'],
    );
};

################################################################################
# normal query with unknown columns
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name,contacts,UNKNOWN',
        'content_type' => 'application/json; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['"contacts"', '"UNKNOWN"'],
        'unlike'       => ['"contacts" : null,'],
    );
};

################################################################################
# csv output
{
    TestUtils::test_page(
        'url'          => '/thruk/r/csv/hosts?columns=name,contacts',
        'content_type' => 'text/plain; charset=utf-8',
        'method'       => 'GET',
        'like'         => ['name;contacts'],
        'unlike'       => ['ARRAY'],
    );
};

################################################################################
# csv output
{
    TestUtils::test_page(
        'url'          => '/thruk/r/xls/hosts?columns=name,contacts',
        'content_type' => 'application/x-msexcel',
        'method'       => 'GET',
        'like'         => ['Arial1'],
        'unlike'       => ['ARRAY'],
    );
};

################################################################################
# peer_name / peer_key
{
    TestUtils::test_page(
        'url'          => '/thruk/r/hosts?columns=name,peer_name,peer_key&name='.$host,
        'method'       => 'GET',
        'like'         => [$host, 'peer_name', 'peer_key', 'name'],
        'unlike'       => ['ARRAY'],
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
