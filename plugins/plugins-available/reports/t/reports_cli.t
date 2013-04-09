use strict;
use warnings;
use Test::More;
use URI::Escape;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan skip_all => 'local test only'   if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};

    # enable plugin
    `cd plugins/plugins-enabled && rm -f reports2`;
    `cd plugins/plugins-enabled && ln -s ../plugins-available/reports .`;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'CATALYST_SERVER'};
$BIN    = $BIN.' --remote-url="'.$ENV{'CATALYST_SERVER'}.'"' if defined $ENV{'CATALYST_SERVER'};

# get test host / hostgroup
my $host      = TestUtils::get_test_host_cli($BIN);
my $hostgroup = TestUtils::get_test_hostgroup_cli($BIN);

my $test_pdf_reports = [{
        'name'                  => 'Host',
        'template'              => 'sla_host.tt',
        'params.sla'            => 95,
        'params.timeperiod'     => 'last12months',
        'params.host'           => $host,
        'params.breakdown'      => 'months',
        'params.unavailable'    => [ 'down', 'unreachable' ],
    }, {
        'name'                  => 'Hostgroups by Day',
        'template'              => 'sla_hostgroup.tt',
        'params.timeperiod'     => 'last12months',
        'params.sla'            => 95,
        'params.hostgroup'      => $hostgroup,
        'params.breakdown'      => 'days',
        'params.unavailable'    => [ 'down', 'unreachable' ],
    }, {
        'name'                  => 'Day by Months',
        'template'              => 'sla_host.tt',
        'params.host'           => $host,
        'params.sla'            => 95,
        'params.timeperiod'     => 'today',
        'params.breakdown'      => 'months',
        'params.unavailable'    => [ 'down', 'unreachable' ],
    }, {
        'name'                  => 'Excel Report',
        'type'                  => 'xls',
        'template'              => 'report_from_url.tt',
        'params.url'            => uri_escape('status.cgi?style=hostdetail&hostgroup=all&view_mode=xls'),
    }, {
        'name'                  => 'HTML Report',
        'type'                  => 'hmtl',
        'template'              => 'report_from_url.tt',
        'params.url'            => uri_escape('status.cgi?host=all'),
        'params.minimal'        => 'yes',
        'params.js'             => 'no',
        'params.css'            => 'yes',
        'params.theme'          => 'Thruk',
    }, {
        'name'                  => 'Event Report',
        'template'              => 'eventlog.tt',
        'params.timeperiod'     => 'last24hours',
        'params.pattern'        => '',
        'params.exclude_pattern'=> '',
    }
];

for my $report (@{$test_pdf_reports}) {
    # create report
    my $args = [];
    for my $key (keys %{$report}) {
        for my $val (ref $report->{$key} eq 'ARRAY' ? @{$report->{$key}} : $report->{$key}) {
            push @{$args}, $key.'='.$val;
        }
    }
    TestUtils::test_command({
        cmd  => $BIN.' "/thruk/cgi-bin/reports.cgi?action=save&report=9999&'.join('&', @{$args}).'"',
        like => ['/^OK - report updated$/'],
    });

    my $like = [];
    if(!defined $report->{'type'} or $report->{'type'} eq 'pdf') {
        $like = [ '/%PDF\-1\.4/', '/%%EOF/' ];
    }
    elsif($report->{'type'} eq 'xls') {
        $like = [ '/Arial1/', '/Tahoma1/' ];
    }
    elsif($report->{'type'} eq 'html') {
        $like = [ '/<html/' ];
    }

    # generate report
    TestUtils::test_command({
        cmd  => $BIN.' -a report=9999 --local',
        like => $like,
    });
    TestUtils::test_command({
        cmd  => $BIN.' -a report=9999',
        like => $like,
    });

    # update report
    TestUtils::test_command({
        cmd  => $BIN.' "/thruk/cgi-bin/reports.cgi?action=update&report=9999"',
        like => ['/^OK - report scheduled for update$/'],
    });
}

# remove report
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/reports.cgi?action=remove&report=9999"',
    like => ['/^OK - report removed$/'],
});

# restore default
`cd plugins/plugins-enabled && rm -f reports`;
`cd plugins/plugins-enabled && ln -s ../plugins-available/reports2 .`;
unlink('root/thruk/plugins/reports');

done_testing();
