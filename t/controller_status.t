use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 270;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::status' }

my $pages = [
    '/status',
    '/thruk/cgi-bin/status.cgi',

# Host / Hostgroups
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=detail',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=summary',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=grid',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=overview',
    '/thruk/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=hostdetail',
    '/thruk/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=detail',
    '/thruk/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=summary',
    '/thruk/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=overview',
    '/thruk/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=grid',
# Services
    '/thruk/cgi-bin/status.cgi?host=all',
    '/thruk/cgi-bin/status.cgi?host=test_host_00',
# Servicegroups
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=detail',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=summary',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=grid',
    '/thruk/cgi-bin/status.cgi?servicegroup=all&style=overview',
    '/thruk/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=detail',
    '/thruk/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=summary',
    '/thruk/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=grid',
    '/thruk/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=overview',
# Problems
    '/thruk/cgi-bin/status.cgi?host=all&servicestatustypes=28',
    '/thruk/cgi-bin/status.cgi?host=all&type=detail&hoststatustypes=3&serviceprops=42&servicestatustypes=28',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=12',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=12&hostprops=42',
# Search
    '/thruk/cgi-bin/status.cgi?status.cgi?navbarsearch=1&host=*',
    '/thruk/cgi-bin/status.cgi?status.cgi?navbarsearch=1&host=hostgroup_01',
    '/thruk/cgi-bin/status.cgi?status.cgi?navbarsearch=1&host=servicegroup_01',

# Bugs
    # Paging all when nothing found -> div by zero
    '/thruk/cgi-bin/status.cgi?style=detail&nav=0&entries=all&hidesearch=2&hidetop=1&s0_hoststatustypes=15&s0_servicestatustypes=29&s0_hostprops=0&s0_serviceprops=8&update.x=4&update.y=9&s0_serviceprop=8&s0_type=service&s0_op=%3D&s0_value=nonexstiant_service_check',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => [ 'Current Network Status', 'statusTitle' ],
        'unlike'  => 'internal server error',
    );
}


$pages = [
# Excel Export
    '/thruk/cgi-bin/status.cgi?host=all&servicestatustypes=28&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?host=all&type=detail&hoststatustypes=3&serviceprops=42&servicestatustypes=28&view_mode=xls',
    '/thruk/cgi-bin/status.cgi?style=hostdetail&hostgroup=all&view_mode=xls',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'unlike'       => 'internal server error',
        'content_type' => 'application/x-msexcel',
    );
}

$pages = [
# json export
    '/thruk/cgi-bin/status.cgi?host=all&format=json',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&format=json',
    '/thruk/cgi-bin/status.cgi?host=all&format=json&column=host_name&column=description&limit=5',
    '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&format=json&column=name',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'          => $url,
        'unlike'       => 'internal server error',
        'content_type' => 'application/json; charset=utf-8',
    );
}
