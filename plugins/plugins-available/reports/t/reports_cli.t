use strict;
use warnings;
use Test::More;
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
my $test = { cmd  => $BIN.' -a listhosts' };
TestUtils::test_command($test);
my $host = (split(/\n/mx, $test->{'stdout'}))[0];
isnt($host, undef, 'got test hosts') or BAIL_OUT("need test host");

# get test hostgroup
$test = { cmd  => $BIN.' -a listhostgroups' };
TestUtils::test_command($test);
my $hostgroup = (split(/\n/mx, $test->{'stdout'}))[0];
isnt($hostgroup, undef, 'got test hostgroup') or BAIL_OUT("need test hostgroup");

my $test_pdf_reports = [
    {
        'name'                  => 'Host',
        'template'              => 'sla_host.tt',
        'params.sla'            => 95,
        'params.timeperiod'     => 'last12months',
        'params.host'           => $host,
        'params.breakdown'      => 'months',
        'params.unavailable'    => [ 'down', 'unreachable' ],
    },{
        'name'                  => 'Hostgroups by Day',
        'template'              => 'sla_hostgroup.tt',
        'params.timeperiod'     => 'last12months',
        'params.hostgroup'      => $hostgroup,
        'params.breakdown'      => 'days',
        'params.unavailable'    => [ 'down', 'unreachable' ],
    } ,{
        'name'                  => 'Day by Months',
        'template'              => 'sla_host.tt',
        'params.host'           => $host,
        'params.timeperiod'     => 'today',
        'params.breakdown'      => 'months',
        'params.unavailable'    => [ 'down', 'unreachable' ],
    },
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

    # generate report
    TestUtils::test_command({
        cmd  => $BIN.' -a report=9999 --local',
        like => [ '/%PDF\-1\.4/', '/%%EOF/' ],
    });
    TestUtils::test_command({
        cmd  => $BIN.' -a report=9999',
        like => [ '/%PDF\-1\.4/', '/%%EOF/' ],
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
