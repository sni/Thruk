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

my $BIN = defined $ENV{'CATALYST_SERVER'} ? '/usr/bin/thruk' : './script/thruk';

my $oldextsrv = $ENV{'CATALYST_SERVER'};
delete $ENV{'CATALYST_SERVER'};

my($hostname,$servicename) = TestUtils::get_test_service();

my $pages = [
    { url => '/thruk/cgi-bin/reports.cgi?action=save&report=999&name=Service%20SLA%20Report%20for%20'.$hostname.'%20-%20'.$servicename.'&template=sla_service.tt&params.sla=95&params.timeperiod=last12months&params.host='.$hostname.'&params.service='.$servicename.'&params.breakdown=months&params.unavailable=critical&params.unavailable=unknown', 'redirect' => 1, location => 'reports.cgi', like => 'This item has moved' },
];

for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}

# generate report
TestUtils::test_command({
    cmd  => $BIN.' -a report=999',
    like => [ '/%PDF\-1\.4/', '/%%EOF/' ],
});

$pages = [
    { url => '/thruk/cgi-bin/reports.cgi?action=remove&report=999', 'redirect' => 1, location => 'reports.cgi', like => 'This item has moved' },
];
for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}


# restore env
defined $oldextsrv ? $ENV{'CATALYST_SERVER'} = $oldextsrv : delete $ENV{'CATALYST_SERVER'};
done_testing();
