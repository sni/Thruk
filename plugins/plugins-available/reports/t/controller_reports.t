use strict;
use warnings;
use Test::More tests => 37;

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
    '/thruk/cgi-bin/reports.cgi',
    '/thruk/cgi-bin/reports.cgi?action=update&report=999&name=Service%20SLA%20Report%20for%20'.$hostname.'%20-%20'.$servicename.'&template=sla.tt&params.sla=95&params.timeperiod=today&params.host=child&params.service=random&params.breakdown=months',
    '/thruk/cgi-bin/reports.cgi?report=999',
    '/thruk/cgi-bin/reports.cgi?action=remove&report=999',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Reports',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
