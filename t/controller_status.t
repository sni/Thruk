use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 100;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::status' }

ok( request('/status')->is_success, 'Status Request should succeed' );
ok( request('/nagios/cgi-bin/status.cgi')->is_success, 'Status Request should succeed' );

my $pages = [
# Host / Hostgroups
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=detail',
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=summary',
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=grid',
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=overview',
    '/nagios/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=hostdetail',
    '/nagios/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=detail',
    '/nagios/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=summary',
    '/nagios/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=overview',
    '/nagios/cgi-bin/status.cgi?hostgroup=hostgroup_01&style=grid',
# Services
    '/nagios/cgi-bin/status.cgi?host=all',
    '/nagios/cgi-bin/status.cgi?host=test_host_00',
# Servicegroups
    '/nagios/cgi-bin/status.cgi?servicegroup=all&style=detail',
    '/nagios/cgi-bin/status.cgi?servicegroup=all&style=summary',
    '/nagios/cgi-bin/status.cgi?servicegroup=all&style=grid',
    '/nagios/cgi-bin/status.cgi?servicegroup=all&style=overview',
    '/nagios/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=detail',
    '/nagios/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=summary',
    '/nagios/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=grid',
    '/nagios/cgi-bin/status.cgi?servicegroup=servicegroup_01&style=overview',
# Problems
    '/nagios/cgi-bin/status.cgi?host=all&servicestatustypes=28',
    '/nagios/cgi-bin/status.cgi?host=all&type=detail&hoststatustypes=3&serviceprops=42&servicestatustypes=28',
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=12',
    '/nagios/cgi-bin/status.cgi?hostgroup=all&style=hostdetail&hoststatustypes=12&hostprops=42',
];

for my $url (@{$pages}) {
    my $request = request($url);
    ok( $request->is_success, 'Request '.$url.' should succeed' );
    my $content = $request->content;
    like($content, qr/statusTitle/mx, "Content contains: statusTitle");
    like($content, qr/Current Network Status/, "Content contains: Current Network Status");
    unlike($content, qr/errorMessage/, "Content doesnt contains: errorMessage");
}