use strict;
use warnings;
use Test::More;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 1140;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::status' }

my($host,$service) = TestUtils::get_test_service();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();

my $pages = [
    '/thruk/cgi-bin/status.cgi',
    { url => '/thruk/cgi-bin/status.cgi', like => '<input\ type="text".*?value=".*\/thruk\/cgi\-bin\/status\.cgi"\ name="bookmark">' },  # test bookmarks

# Found 0 matching services, but there are x matching hosts
    { url => '/thruk/cgi-bin/status.cgi?style=detail&dfl_s0_type=host&dfl_s0_val_pre=&dfl_s0_op=%3D&dfl_s0_value='.$host.'&dfl_s0_value_sel=5&dfl_s0_type=service&dfl_s0_val_pre=&dfl_s0_op=~&dfl_s0_value=noserviceswiththisname', unlike => 'Found 0 matching services, but there\s+is \d matching host' },

# Host / Hostgroups
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=detail',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=summary',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=grid',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=overview',
    '/thruk/cgi-bin/status.cgi?hostgroup='.$hostgroup.'&style=hostdetail',
    '/thruk/cgi-bin/status.cgi?hostgroup='.$hostgroup.'&style=detail',
    '/thruk/cgi-bin/status.cgi?hostgroup='.$hostgroup.'&style=summary',
    '/thruk/cgi-bin/status.cgi?hostgroup='.$hostgroup.'&style=overview',
    '/thruk/cgi-bin/status.cgi?hostgroup='.$hostgroup.'&style=grid',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&sortoption=1&hostgroup=all&sorttype=1',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&sortoption=1&hostgroup=all&sorttype=2',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&sortoption=8&hostgroup=all&sorttype=1',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&sortoption=4&hostgroup=all&sorttype=1',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&sortoption=6&hostgroup=all&sorttype=1',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&dfl_columns=name%2Cstate%2Clast_check%2Cduration%2Cpeer_name%2Cplugin_output%2Clatency',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&dfl_columns=name%2Cstate%2Clast_check%2Cduration%2Cpeer_name%2Cplugin_output%2Ccomments',

    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostoverview',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostsummary',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostgrid',

# Services
    '/thruk/cgi-bin/status.cgi?host=all',
    '/thruk/cgi-bin/status.cgi?host=does_not_exist',
    { url => '/thruk/cgi-bin/status.cgi?host='.$host, like => ['Service Status Details For Host \''.$host.'\'', 'Current Network Status', 'Matching Service Entries Displayed'] },
    '/thruk/cgi-bin/status.cgi?sortoption=1&sorttype=1&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=1&sorttype=2&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=2&sorttype=1&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=2&sorttype=2&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=3&sorttype=1&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=4&sorttype=1&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=6&sorttype=1&host=all',
    '/thruk/cgi-bin/status.cgi?sortoption=5&sorttype=1&host=all',
    '/thruk/cgi-bin/status.cgi?host=all&dfl_columns=host_name%2Cdescription%2Cstate%2Clast_check%2Cduration%2Ccurrent_attempt%2Cpeer_name%2Cplugin_output%2Cexecution_time',
    '/thruk/cgi-bin/status.cgi?host=all&dfl_columns=host_name%2Cdescription%2Cstate%2Clast_check%2Cduration%2Ccurrent_attempt%2Cpeer_name%2Cplugin_output%2Ccomments',

# Servicegroups
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=detail',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=summary',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=grid',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=overview',
    '/thruk/cgi-bin/status.cgi?servicegroup='.$servicegroup.'&style=detail',
    '/thruk/cgi-bin/status.cgi?servicegroup='.$servicegroup.'&style=summary',
    '/thruk/cgi-bin/status.cgi?servicegroup='.$servicegroup.'&style=grid',
    '/thruk/cgi-bin/status.cgi?servicegroup='.$servicegroup.'&style=overview',

    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=serviceoverview',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=servicesummary',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=servicegrid',

# Problems
    '/thruk/cgi-bin/status.cgi?host=all&servicestatustypes=28',
    '/thruk/cgi-bin/status.cgi?host=all&type=detail&hoststatustypes=3&serviceprops=42&servicestatustypes=28',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=12',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=12&hostprops=42',
    '/thruk/cgi-bin/status.cgi?style=combined&hst_s0_hoststatustypes=4&hst_s0_servicestatustypes=31&hst_s0_hostprops=10&hst_s0_serviceprops=0&svc_s0_hoststatustypes=3&svc_s0_servicestatustypes=28&svc_s0_hostprops=10&svc_s0_serviceprops=10&svc_s0_hostprop=2&svc_s0_hostprop=8&title=All+Unhandled+Problems',
    '/thruk/cgi-bin/status.cgi?style=combined&hst_s0_hoststatustypes=4&hst_s0_servicestatustypes=31&hst_s0_hostprops=10&hst_s0_serviceprops=0&svc_s0_hoststatustypes=3&svc_s0_servicestatustypes=28&svc_s0_hostprops=10&svc_s0_serviceprops=10&svc_s0_hostprop=2&svc_s0_hostprop=8&title=All Unhandled Problems&hst_columns=name%2Cstate%2Clast_check%2Cduration%2Ccurrent_attempt%2Cpeer_name%2Cplugin_output%2Ccheck_period&hidesearch=1&svc_columns=host_name%2Cdescription%2Cstate%2Clast_check%2Cduration%2Ccurrent_attempt%2Cpeer_name%2Cplugin_output%2Cexecution_time',
    '/thruk/cgi-bin/status.cgi?style=combined&hst_s0_hoststatustypes=4&hst_s0_servicestatustypes=31&hst_s0_hostprops=10&hst_s0_serviceprops=0&svc_s0_hoststatustypes=3&svc_s0_servicestatustypes=28&svc_s0_hostprops=10&svc_s0_serviceprops=10&svc_s0_hostprop=2&svc_s0_hostprop=8&title=All Unhandled Problems&hst_columns=name%2Cstate%2Clast_check%2Cduration%2Ccurrent_attempt%2Cpeer_name%2Cplugin_output%2Ccheck_period&hidesearch=1&svc_columns=host_name%2Cdescription%2Cstate%2Clast_check%2Cduration%2Ccurrent_attempt%2Cpeer_name%2Cplugin_output%2Ccomments',
# Search
    '/thruk/cgi-bin/status.cgi?status.cgi?navbarsearch=1&host=*',
    '/thruk/cgi-bin/status.cgi?status.cgi?navbarsearch=1&host='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?status.cgi?navbarsearch=1&host='.$servicegroup,

# Styles
    '/thruk/cgi-bin/status.cgi?style=hostdetail&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=hostoverview&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=hostsummary&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=hostgrid&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=detail&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=serviceoverview&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=servicesummary&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,
    '/thruk/cgi-bin/status.cgi?style=servicegrid&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=hostgroup&dfl_s0_op=%3D&dfl_s0_value='.$hostgroup,

    '/thruk/cgi-bin/status.cgi?style=detail&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=serviceoverview&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=servicesummary&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=servicegrid&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=hostdetail&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=hostoverview&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=hostsummary&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,
    '/thruk/cgi-bin/status.cgi?style=hostgroup&dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value='.$host,

# Performance Map
    '/thruk/cgi-bin/status.cgi?style=perfmap&dfl_s0_type=service&dfl_s0_op=%3D&dfl_s0_value='.$service,

# Bugs
    # Paging all when nothing found -> div by zero
    '/thruk/cgi-bin/status.cgi?style=detail&nav=0&entries=all&hidesearch=2&hidetop=1&s0_hoststatustypes=15&s0_servicestatustypes=29&s0_hostprops=0&s0_serviceprops=8&update.x=4&update.y=9&s0_serviceprop=8&s0_type=service&s0_op=%3D&s0_value=nonexstiant_service_check',

    # internal server error on problems page
    '/thruk/cgi-bin/status.cgi?style=detail&hidesearch=1&s0_hoststatustypes=12&s0_servicestatustypes=31&s0_hostprops=10&s0_serviceprops=0&s1_hoststatustypes=15&s1_servicestatustypes=28&s1_hostprops=10&s1_serviceprops=10&s1_hostprop=2&s1_hostprop=8&title=All Unhandled Problems',

    # search for service named '+ping' leads to err 500
    '/thruk/cgi-bin/status.cgi?style=detail&nav=&hidesearch=2&hidetop=0&s0_hoststatustypes=15&s0_servicestatustypes=31&s0_hostprops=0&s0_serviceprops=0&update.x=0&update.y=0&s0_type=search&s0_op=~&s0_value=%2Bping',

    # internal error when searching for hostgroup/servicegroups
    '/thruk/cgi-bin/status.cgi?dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&style=detail&dfl_s0_type=hostgroup&dfl_s0_op=~&dfl_s0_value='.$hostgroup.'&dfl_s0_value_sel=5',
    '/thruk/cgi-bin/status.cgi?dfl_s0_hoststatustypes=15&dfl_s0_servicestatustypes=31&dfl_s0_hostprops=0&dfl_s0_serviceprops=0&style=detail&dfl_s0_type=hostgroup&dfl_s0_type=servicegroup&dfl_s0_op=~&dfl_s0_op=~&dfl_s0_value='.$hostgroup.'&dfl_s0_value='.$servicegroup.'&dfl_s0_value_sel=5',
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => [ 'Current Network Status', 'statusTitle' ]});
    TestUtils::test_page(%{$test});
}


$pages = [
# Excel Export
    '/thruk/cgi-bin/status.cgi?host=all&servicestatustypes=28&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?host=all&view_mode=xls&columns=1&columns=2&columns=3&columns=12',
    '/thruk/cgi-bin/status.cgi?host=all&view_mode=xls&columns=Hostname&columns=Service&columns=IP&columns=Status&columns=Host+Acknowledged',
    '/thruk/cgi-bin/status.cgi?host=all&type=detail&hoststatustypes=3&serviceprops=42&servicestatustypes=28&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&view_mode=xls&columns=1&columns=2&columns=3&columns=4&columns=5&columns=6&columns=7&columns=8&columns=9&columns=10&columns=11&columns=12',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&view_mode=xls&columns=IP&columns=Hostname&columns=Status',
    '/thruk/cgi-bin/status.cgi?style=combined&hst_s0_hoststatustypes=4&hst_s0_servicestatustypes=31&hst_s0_hostprops=10&hst_s0_serviceprops=0&svc_s0_hoststatustypes=3&svc_s0_servicestatustypes=28&svc_s0_hostprops=10&svc_s0_serviceprops=10&svc_s0_hostprop=2&svc_s0_hostprop=8&title=All+Unhandled+Problems&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?style=perfmap&dfl_s0_type=service&dfl_s0_op=%3D&dfl_s0_value='.$service.'&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?style=perfmap&dfl_s0_type=service&dfl_s0_op=%3D&dfl_s0_value='.$service.'&view_mode=xls&columns=1&columns=2&columns=3',
    '/thruk/cgi-bin/status.cgi?style=perfmap&dfl_s0_type=service&dfl_s0_op=%3D&dfl_s0_value='.$service.'&view_mode=xls&columns=Hostname&columns=Service&columns=Status',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/x-msexcel',
    );
}

$pages = [
# view_mode json export which result in an Array
    '/thruk/cgi-bin/status.cgi?host=all&view_mode=json',
    '/thruk/cgi-bin/status.cgi?host=all&servicestatustypes=28&view_mode=json',
    '/thruk/cgi-bin/status.cgi?host=all&view_mode=json&columns=host_name,description,state',
    '/thruk/cgi-bin/status.cgi?host=all&type=detail&hoststatustypes=3&serviceprops=42&servicestatustypes=28&view_mode=json',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&hostgroup=all&view_mode=json',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&hostgroup=all&view_mode=json&columns=state,name',
    '/thruk/cgi-bin/status.cgi?style=perfmap&dfl_s0_type=service&dfl_s0_op=%3D&dfl_s0_value='.$service.'&view_mode=json',
];

for my $url (@{$pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array");
}

$pages = [
# view_mode json export which result in a hash
    '/thruk/cgi-bin/status.cgi?style=combined&hst_s0_hoststatustypes=4&hst_s0_servicestatustypes=31&hst_s0_hostprops=10&hst_s0_serviceprops=0&svc_s0_hoststatustypes=3&svc_s0_servicestatustypes=28&svc_s0_hostprops=10&svc_s0_serviceprops=10&svc_s0_hostprop=2&svc_s0_hostprop=8&title=All+Unhandled+Problems&view_mode=json',
];

for my $url (@{$pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is a hash");
}


$pages = [
# json export
    '/thruk/cgi-bin/status.cgi?host=all&format=json',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&format=json',
    '/thruk/cgi-bin/status.cgi?host=all&format=json&column=name&column=state&limit=5',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&format=json&column=name',
    '/thruk/cgi-bin/status.cgi?format=search',
];

for my $url (@{$pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'ARRAY', "json result is an array");
    ok(scalar @{$data} > 0, "json result has content");
}
