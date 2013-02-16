use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 94;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# test modules
if(defined $ENV{'CATALYST_SERVER'}) {
    unshift @INC, 'plugins/plugins-available/reports2/lib';
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::reports2';
};

my($hostname,$servicename) = TestUtils::get_test_service();

my $pages = [
    { url => '/thruk/cgi-bin/reports2.cgi' },
    { url => '/thruk/cgi-bin/reports2.cgi?action=save&report=999&name=Service%20SLA%20Report%20for%20'.$hostname.'%20-%20'.$servicename.'&template=sla_service.tt&params.sla=95&params.timeperiod=last12months&params.host='.$hostname.'&params.service='.$servicename.'&params.breakdown=months&params.unavailable=critical&params.unavailable=unknown&params.decimals=2&params.graph_min_sla=90', 'redirect' => 1, location => 'reports2.cgi', like => 'This item has moved' },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&action=update', 'redirect' => 1, location => 'reports2.cgi', like => 'This item has moved', sleep => 10 },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999', like => [ '%PDF-1.4', '%%EOF' ] },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&html=1', like => [ 'SLA Report' ] },
    { url => '/thruk/cgi-bin/reports2.cgi?report=999&action=edit' },
    { url => '/thruk/cgi-bin/reports2.cgi?action=remove&report=999', 'redirect' => 1, location => 'reports2.cgi', like => 'This item has moved' },
    { url => '/thruk/cgi-bin/reports2.cgi?action=edit&report=new', like => ['Create Report'] },
];

for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}
