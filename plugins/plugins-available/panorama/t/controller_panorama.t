use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/encode_json decode_json/;
use Encode qw/encode_utf8/;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 540;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    use_ok 'Thruk::Controller::panorama';
};

#################################################
# get test data
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();
my($host,$service) = TestUtils::get_test_service();

my $config   = Thruk::Config::get_config();
my $var_path = $config->{'var_path'};
my $etc_path = $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} ? '/etc/thruk' : $config->{'etc_path'};

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
my $test_dashboard_nr   = 0;
my $test_dashboard_name = 'Test Dashboard '.time();
$pages = [
    { url => '/thruk/cgi-bin/panorama.cgi?task=availability', post => {
          'avail' => '{"tabpan-tab_4_panlet_1":{"{\\"d\\":\\"60m\\"}":{"opts":{"d":"60m"}}}}',
          'types' => '{"filter":{},"hosts":{"'.encode_utf8($host).'":["tabpan-tab_4_panlet_1"]},"hostgroups":{},"services":{},"servicegroups":{}}',
          'force' => '1'
    }},
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_data', post => { nr => 'new', title => $test_dashboard_name }, callback => sub {
       if($_[0] =~ m|"newid"\s*:\s*"[^"0-9]*?(\d+)"|) { $test_dashboard_nr = $1; }
       isnt($test_dashboard_nr, 0, 'got a dashboard number: '.$test_dashboard_nr);
       ok(-e $etc_path.'/panorama/'.$test_dashboard_nr.'.tab', 'dashboard file exists: '.$etc_path.'/panorama/'.$test_dashboard_nr.'.tab');
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
    '/thruk/cgi-bin/panorama.cgi?task=grafana_graphs',
    '/thruk/cgi-bin/panorama.cgi?task=server_stats',
    { url => '/thruk/cgi-bin/panorama.cgi?task=service_detail', post => { host => $host, service => $service } },
    '/thruk/cgi-bin/panorama.cgi?task=service_list',
    '/thruk/cgi-bin/panorama.cgi?task=services',
    '/thruk/cgi-bin/panorama.cgi?task=servicesminemap',
    '/thruk/cgi-bin/panorama.cgi?task=services_pie',
    '/thruk/cgi-bin/panorama.cgi?task=servicetotals',
    '/thruk/cgi-bin/panorama.cgi?task=squares_data',
    '/thruk/cgi-bin/panorama.cgi?task=show_logs',
    '/thruk/cgi-bin/panorama.cgi?task=site_status',
    '/thruk/cgi-bin/panorama.cgi?task=stats_check_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=stats_core_metrics',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman',
    '/thruk/cgi-bin/panorama.cgi?task=stats_gearman_grid',
    '/thruk/cgi-bin/panorama.cgi?task=status',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_backgroundimages',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_iconsets',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_trendiconsets',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_images',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_shapes',
    '/thruk/cgi-bin/panorama.cgi?task=userdata_sounds',
    '/thruk/cgi-bin/panorama.cgi?task=wms_provider',
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboards_clean', like => '"num" : ' },
    { url => '/thruk/cgi-bin/panorama.cgi?task=timezones', like => 'Berlin' },
    { url => '/thruk/cgi-bin/panorama.cgi?task=timezones&query=Berl', like => 'Berlin' },
    { url => '/thruk/cgi-bin/panorama.cgi?task=serveraction', post => { dashboard => '__DASHBOARD__', link => 'server://test' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_restore_point', post => { nr => '__DASHBOARD__', mode => 'a' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_restore_list', post => { nr => '__DASHBOARD__' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_restore', post => { nr => '__DASHBOARD__', timestamp => '__TIMESTAMP__', mode => 'a' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_save_states', post => { nr => '__DASHBOARD__', states => '{}' } },
    { url => '/thruk/cgi-bin/panorama.cgi?task=upload', like => 'missing properties in fileupload.', content_type => "text/html; charset=utf-8", skip_html_lint => 1, skip_doctype => 1},
    { url => '/thruk/cgi-bin/panorama.cgi?task=uploadecho', like => 'missing file in fileupload.', content_type => "text/html; charset=utf-8", skip_html_lint => 1, skip_doctype => 1},
    { url => '/thruk/cgi-bin/panorama.cgi?task=save_dashboard&nr=__DASHBOARD__', like => ['Thruk Panorama Dashboard Export:','End Export'], content_type => "text/html; charset=utf-8", skip_html_lint => 1, skip_doctype => 1},
    { url => '/thruk/cgi-bin/panorama.cgi?task=load_dashboard', like => 'missing file in fileupload', content_type => "text/html; charset=utf-8", skip_html_lint => 1, skip_doctype => 1},
    { url => '/thruk/r/thruk/panorama/__DASHBOARD__', method => 'get' },
];

for my $url (@{$pages}) {
    _test_json_page($url);
}

# some more normal pages
$pages = [
    '/thruk/cgi-bin/panorama.cgi?map=__DASHBOARD__',
    '/thruk/cgi-bin/panorama.cgi?map=__DASHBOARDNAME__',
];
for my $url (@{$pages}) {
    if(!ref $url) {
        $url = { url => $url };
    }
    $url = _set_dynamic_url_parts($url);
    TestUtils::test_page(%{$url});
}

# finally remove our test dashboard
_test_json_page({ url => '/thruk/cgi-bin/panorama.cgi?task=dashboard_update', post => { nr => '__DASHBOARD__', action => 'remove' } });

#################################################
# some more availability
# single host
my $res = _test_json_page({
    url  => '/thruk/cgi-bin/panorama.cgi?task=availability',
    post => {
        'avail' => '{"tabpan-tab_4_panlet_1":{"{\\"d\\":\\"60m\\"}":{"opts":{"d":"60m"}}}}',
        'types' => '{"filter":{},"hosts":{"'.encode_utf8($host).'":["tabpan-tab_4_panlet_1"]},"hostgroups":{},"services":{},"servicegroups":{}}',
        'force' => '1'
    },
});
isnt($res->{'data'}->{'tabpan-tab_4_panlet_1'}->{'{\\"d\\":\\"60m\\"}'}, -1);

# filter
$res = _test_json_page({
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
# make sure all tasks are covered with tests
is(scalar keys %{$subs}, 0, 'all tasks tested') or diag("untested tasks:\n".join(",\n", keys %{$subs})."\n");
ok(!-e $etc_path.'/panorama/'.$test_dashboard_nr.'.tab', 'dashboard file removed: '.$etc_path.'/panorama/'.$test_dashboard_nr.'.tab');

#################################################
sub _test_json_page {
    my($url) = @_;
    if(!ref $url) {
        $url = { url => $url };
    }
    my $taskurl = $url->{'url'};
    $taskurl =~ s|task=([a-z_]+).*?$|task=$1|gmx;
    delete $subs->{$taskurl};
    $url->{'post'}         = {} unless $url->{'post'};
    $url->{'post'}         = undef if($url->{'method'} && lc($url->{'method'}) eq 'get');
    $url->{'content_type'} = 'application/json;charset=UTF-8' unless $url->{'content_type'};

    $url = _set_dynamic_url_parts($url);

    my $page = TestUtils::test_page(%{$url});
    my $data;
    eval {
        $data = decode_json($page->{'content'});
    };
    if($url->{'url'} =~ m|save_dashboard|gmx) {
        return($data);
    }
    is(ref $data, 'HASH', "json result is an array: ".$url->{'url'});
    if($url->{'url'} !~ m/gearman/mx) {
        ok(scalar keys %{$data} > 0, "json result has content: ".$url->{'url'});
    }
    return($data);
}

#################################################
sub _set_dynamic_url_parts {
    my($test) = @_;

    if($test->{'post'} && $test->{'post'}->{'nr'} && $test->{'post'}->{'nr'} eq '__DASHBOARD__') {
        $test->{'post'}->{'nr'} = $test_dashboard_nr;
    }
    $test->{'url'} =~ s|__DASHBOARD__|$test_dashboard_nr|gmx;
    $test->{'url'} =~ s|__DASHBOARDNAME__|$test_dashboard_name|gmx;
    if($test->{'post'} && $test->{'post'}->{'timestamp'} && $test->{'post'}->{'timestamp'} eq '__TIMESTAMP__') {
        my @files = glob($var_path.'/panorama/'.$test_dashboard_nr.'.tab.*.a');
        ok(scalar @files > 0, "got backup files");
        $files[0] =~ m/\.(\d+)\.a$/mx;
        ok($1, "got backup timestamp");
        $test->{'post'}->{'timestamp'} = $1;
    }

    return $test;
}
