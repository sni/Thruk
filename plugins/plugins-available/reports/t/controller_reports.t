use strict;
use warnings;
use Test::More tests => 44;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
if(defined $ENV{'CATALYST_SERVER'}) {
    unshift @INC, 'plugins/plugins-available/reports/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::reports';
};

my($hostname,$servicename) = TestUtils::get_test_service();

my $pages = [
    { url => '/thruk/cgi-bin/reports.cgi' },
    { url => '/thruk/cgi-bin/reports.cgi?action=update&report=999&name=Service%20SLA%20Report%20for%20'.$hostname.'%20-%20'.$servicename.'&template=sla.tt&params.sla=95&params.timeperiod=last12months&params.host='.$hostname.'&params.service='.$servicename.'&params.breakdown=months' },
    { url => '/thruk/cgi-bin/reports.cgi?report=999', like => [ '%PDF-1.4', '%%EOF' ] },
    { url => '/thruk/cgi-bin/reports.cgi?action=remove&report=999' },
];

for my $test (@{$pages}) {
    TestUtils::test_page(
        'url'     => $test->{'url'},
        'like'    => $test->{'like'} || 'Reports',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
