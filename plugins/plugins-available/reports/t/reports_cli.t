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

# create report
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/reports.cgi?action=save&report=999&name=Service%20SLA%20Report%20for%20'.$host.'&template=sla_host.tt&params.sla=95&params.timeperiod=last12months&params.host='.$host.'&params.breakdown=months&params.unavailable=critical&params.unavailable=unknown"',
    like => ['/^OK - report updated$/'],
});

# generate report
TestUtils::test_command({
    cmd  => $BIN.' -a report=999 --local',
    like => [ '/%PDF\-1\.4/', '/%%EOF/' ],
});
TestUtils::test_command({
    cmd  => $BIN.' -a report=999',
    like => [ '/%PDF\-1\.4/', '/%%EOF/' ],
});

# update report
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/reports.cgi?action=update&report=999"',
    like => ['/^OK - report scheduled for update$/'],
});

# remove report
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/reports.cgi?action=remove&report=999"',
    like => ['/^OK - report removed$/'],
});

done_testing();
