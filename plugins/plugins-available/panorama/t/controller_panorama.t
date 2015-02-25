use strict;
use warnings;
use Test::More;
use JSON::XS;
use Encode qw/encode_utf8/;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 367;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::panorama';
};

#################################################
# get test data
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();
my($host,$service) = TestUtils::get_test_service();

my $config   = Thruk::Backend::Pool::get_config();
my $var_path = $config->{'var_path'};

#################################################
my $raw  = `grep task_ plugins/plugins-available/panorama/lib/Thruk/Controller/panorama.pm | grep ^sub | sort | awk '{ print \$2}'`;
my $subs = {};
for my $sub (split/\n/mx, $raw) {
    $sub =~ s|_task_|/thruk/cgi-bin/panorama.cgi?task=|mx;
    $subs->{$sub} = 1;
}

#################################################
# normal pages
my $pages = [
    { url => '/thruk/cgi-bin/panorama.cgi', like => 'Thruk Panorama' },
    { url => '/thruk/cgi-bin/panorama.cgi?readonly=1', like => 'Thruk Panorama' },
    { url => '/thruk/usercontent/backgrounds/world.png', like => 'PNG' },
    { url => '/thruk/cgi-bin/panorama.cgi?task=textsave', post => { 'text' => 'test' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=redirect_status', post => { 'filter' => '[{"type":"Host","val_pre":"","op":"=","value":"'.encode_utf8($host).'"}]' }, follow => 1 },
];

for my $page (@{$pages}) {
    delete $subs->{$page->{'url'}};
    TestUtils::test_page(%{$page});
}

#################################################
# json pages
my $test_dashboard_nr = 0;
$pages = [
    { url => '/thruk/cgi-bin/panorama.cgi?task=availability', post => {
          'avail' => '{"tabpan-tab_4_panlet_1":{"{\\"d\\":\\"60m\\"}":{"opts":{"d":"60m"}}}}',
          'types' => '{"filter":{},"hosts":{"'.encode_utf8($host).'":["tabpan-tab_4_panlet_1"]},"hostgroups":{},"services":{},"servicegroups":{}}',
          'force' => '1'
    }},
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_data', post => { nr => 'new' }, callback => sub {
       if($_[0] =~ m|"newid"\s*:\s*"[^"0-9]*?(\d+)"|) { $test_dashboard_nr = $1; }
       isnt($test_dashboard_nr, 0, 'got a dashboard number: '.$test_dashboard_nr);
       ok(-e $var_path.'/panorama/'.$test_dashboard_nr.'.tab', 'dashboard file exists: '.$var_path.'/panorama/'.$test_dashboard_nr.'.tab');
    }},
    '/thruk/cgi-bin/panorama.cgi?task=dashboard_list',
    '/thruk/cgi-bin/panorama.cgi?task=dashboard_list&list=my',
    '/thruk/cgi-bin/panorama.cgi?task=dashboard_list&list=public',
    { url => '/thruk/cgi-bin/panorama.cgi?task=host_detail', post => { host => $host } },
    '/thruk/cgi-bin/panorama.cgi?task=host_list',
    '/thruk/cgi-bin/panorama.cgi?task=hosts',
    '/thruk/cgi-bin/panorama.cgi?task=hosts_pie',
    '/thruk/cgi-bin/panorama.cgi?task=hosttotals',
    '/thruk/cgi-bin/panorama.cgi?task=pnp_graphs',
    '/thruk/cgi-bin/panorama.cgi?task=server_stats',
    { url => '/thruk/cgi-bin/panorama.cgi?task=service_detail', post => { host => $host, service => $service } },
    '/thruk/cgi-bin/panorama.cgi?task=service_list',
    '/thruk/cgi-bin/panorama.cgi?task=services',
    '/thruk/cgi-bin/panorama.cgi?task=servicesminemap',
    '/thruk/cgi-bin/panorama.cgi?task=services_pie',
    '/thruk/cgi-bin/panorama.cgi?task=servicetotals',
    '/thruk/cgi-bin/panorama.cgi?task=show_logs',
    '/thruk/cgi-bin/panorama.cgi?task=site_status',
    '/thruk/cgi-bin/panorama.cgi?task=stats_check_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=stats_core_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman_grid',
    '/thruk/cgi-bin/panorama.cgi?task=status',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_backgroundimages',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_iconsets',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_images',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_shapes',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_sounds',
    { url => '/thruk/cgi-bin/panorama.cgi?task=serveraction', post => { dashboard => '__DASHBOARD__', link => 'server://test' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_update', post => { nr => '__DASHBOARD__', action => 'remove' } },
];

for my $url (@{$pages}) {
    test_json_page($url);
}
is(scalar keys %{$subs}, 0, 'all tasks tested') or diag("untested tasks:\n".join(",\n", keys %{$subs})."\n");
ok(!-e $var_path.'/panorama/'.$test_dashboard_nr.'.tab', 'dashboard file removed: '.$var_path.'/panorama/'.$test_dashboard_nr.'.tab');

#################################################
# some more availability
# single host
my $res = test_json_page({
    url  => '/thruk/cgi-bin/panorama.cgi?task=availability',
    post => {
        'avail' => '{"tabpan-tab_4_panlet_1":{"{\\"d\\":\\"60m\\"}":{"opts":{"d":"60m"}}}}',
        'types' => '{"filter":{},"hosts":{"'.encode_utf8($host).'":["tabpan-tab_4_panlet_1"]},"hostgroups":{},"services":{},"servicegroups":{}}',
        'force' => '1'
    },
});
isnt($res->{'data'}->{'tabpan-tab_4_panlet_1'}->{'{\\"d\\":\\"60m\\"}'}, -1);

# filter
$res = test_json_page({
    url  => '/thruk/cgi-bin/panorama.cgi?task=availability',
    post => {
        'avail' => encode_json({
                'tabpan-tab_12_panlet_22' => {
                    '{"d":"31d","incl_hst":1,"incl_svc":1}' => {
                        'active'       => 1,
                        'last'         => -1,
                        'last_refresh' => 1410810185,
                        'opts'         => { 'd' => '31d', 'incl_hst' => 1, 'incl_svc' => 1 }
                    }
                },
        }),
        'types' => encode_json({
                'filter' => {
                    '["on","on","[{\\"hoststatustypes\\":15,\\"hostprops\\":0,\\"servicestatustypes\\":31,\\"serviceprops\\":0,\\"type\\":\\"Host\\",\\"val_pre\\":\\"\\",\\"op\\":\\"=\\",\\"value\\":\\"'.encode_utf8($host).'\\",\\"value_date\\":\\"2014-09-12T13:22:33\\",\\"displayfield-1671-inputEl\\":\\"\\"}]",null]' => [ 'tabpan-tab_12_panlet_22' ],
                },
                'hostgroups' => {},
                'hosts' => {},
                'servicegroups' => {},
                'services' => {}
        }),
        'force' => '1'
    }
});
isnt($res->{'data'}->{'tabpan-tab_12_panlet_22'}->{'{\\"d\\":\\"31d\\",\\"incl_hst\\":1,\\"incl_svc\\":1}'}, -1);

#################################################
sub test_json_page {
    my($url) = @_;
    if(!ref $url) {
        $url = { url => $url };
    }
    delete $subs->{$url->{'url'}};
    $url->{'post'}         = {} unless $url->{'post'};
    $url->{'content_type'} = 'application/json; charset=utf-8' unless $url->{'content_type'};

    if($url->{'post'}->{'nr'} && $url->{'post'}->{'nr'} eq '__DASHBOARD__') {
        $url->{'post'}->{'nr'} = $test_dashboard_nr;
    }

    my $page = TestUtils::test_page(%{$url});
    my $data;
    eval {
        $data = decode_json($page->{'content'});
    };
    is(ref $data, 'HASH', "json result is an array: ".$url->{'url'});
    if($url->{'url'} !~ m/gearman/mx) {
        ok(scalar keys %{$data} > 0, "json result has content: ".$url->{'url'});
    }
    return($data);
}
