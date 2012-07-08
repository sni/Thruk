use strict;
use warnings;
use Test::More;
use URI::Escape;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'CATALYST_SERVER'};
$BIN    = $BIN.' --remote-url="'.$ENV{'CATALYST_SERVER'}.'"' if defined $ENV{'CATALYST_SERVER'};

# get test host
my $test = { cmd  => $BIN.' -a listhosts -v', errlike => '/HTTP::Response/' };
TestUtils::test_command($test);
my $host = (split(/\n/mx, $test->{'stdout'}))[0];
isnt($host, undef, 'got test hosts') or BAIL_OUT("need test host:\n".Dumper($test));

# get test hostgroup
$test = { cmd  => $BIN.' -a listhostgroups' };
TestUtils::test_command($test);
my $hostgroup = (split(/\n/mx, $test->{'stdout'}))[0];
isnt($hostgroup, undef, 'got test hostgroup') or BAIL_OUT("need test hostgroup");

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
    }) or BAIL_OUT("failed");
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

done_testing();
