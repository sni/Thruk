use strict;
use warnings;
use Test::More;
use JSON::XS;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 126;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
if(defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'}) {
    unshift @INC, 'plugins/plugins-available/reports2/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    use_ok 'Thruk::Controller::reports2';
};

TestUtils::set_test_user_token();
my($hostname,$servicename) = TestUtils::get_test_service();

my $pages = [
    { url => '/thruk/cgi-bin/reports2.cgi' },
    { url => '/thruk/cgi-bin/reports2.cgi', post => {'action'               => 'save',
                                                     'report'               => 999,
                                                     'name'                 => 'Service SLA Report for '.$hostname.' - '.$servicename,
                                                     'template'             => 'sla_service.tt',
                                                     'params.sla'           => 95,
                                                     'params.timeperiod'    => 'lastweek',
                                                     'params.host'          => $hostname,
                                                     'params.service'       => $servicename,
                                                     'params.breakdown'     => 'days',
                                                     'params.unavailable'   => 'critical',
                                                     'params.unavailable'   => 'unknown',
                                                     'params.decimals'      => 2,
                                                     'params.graph_min_sla' => 90
                                                    },
                                            'redirect' => 1, location => 'reports2.cgi', like => 'This item has moved' },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&action=update', 'redirect' => 1, location => 'reports2.cgi', like => 'This item has moved' },
    { url => '/thruk/cgi-bin/reports2.cgi', waitfor => 'reports2.cgi\?report=999\&amp;refresh=0', unlike => '<span[^>]*style="color:\ red;".*?\'([^\']*)\'' },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999', like => [ '%PDF-1.4', '%%EOF' ] },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&html=1', like => [ 'SLA Report' ], skip_js_check => 1, fail_message_ok => 1, unlike => [ 'internal server error', 'HASH' ] },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&action=edit' },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&action=email' },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&action=profile', like => ['Profile:','_dispatcher:', 'Utils::Reports::generate_report'], 'content_type' => 'application/json;charset=UTF-8', },
    { url => '/thruk/cgi-bin/reports2.cgi', post => { 'action' => 'remove', 'report' => 999 }, 'redirect' => 1, location => 'reports2.cgi', like => 'This item has moved' },
    { url => '/thruk/cgi-bin/reports2.cgi?action=edit&report=new', like => ['Create Report'] },
];

for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}

###########################################################
# test json some pages
my $json_hash_pages = [
    '/thruk/cgi-bin/reports2.cgi?action=check_affected_objects&host='.$hostname,
];

for my $url (@{$json_hash_pages}) {
    my $page = TestUtils::test_page(
        'url'          => $url,
        'content_type' => 'application/json;charset=UTF-8',
    );
    my $data = decode_json($page->{'content'});
    is(ref $data, 'HASH', "json result is an hash: ".$url);
}
