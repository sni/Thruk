use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 133;
}


BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###############################################################################
# fetch backend ids
my $test = TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/extinfo.cgi?type=0&view_mode=json',
    'like'   => [
                'peer_addr',
                'https://127.0.0.3:60443/demo/thruk/',
                'data_source_version',
            ],
);
my $procinfo = Cpanel::JSON::XS::decode_json($test->{'content'});
my $ids      = {map { $_->{'peer_name'} => $_->{'peer_key'} } values %{$procinfo}};
is(scalar keys %{$ids}, 12, 'got backend ids') || die("all backends required");
ok(defined $ids->{'tier1a'}, 'got backend ids II');

###############################################################################
# federated business processes
TestUtils::test_page(
    'url'  => '/thruk/cgi-bin/bp.cgi?type=all',
    'like' => ['tier1a bp', 'tier2a bp', 'tier3a bp', 'tier3b bp'],
);
for my $name (qw/tier1a tier2a tier3a tier3b/) {
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/bp.cgi?action=details&bp='.$ids->{$name}.':1',
        'like'   => [$name.' bp', 'Refresh Status'],
        'follow' => 1,
    );
}
# set some services to broken
for my $hst (qw/tier3a tier3b/) {
    for my $svc (qw/Ping Load/) {
        TestUtils::test_page(
            'url'    => '/thruk/r/services/'.$hst.'/'.$svc.'/cmd/disable_svc_check',
            'method' => 'POST',
            'like'   => [ 'Command successfully submitted' ],
        );
        TestUtils::test_page(
            'url'    => '/thruk/r/services/'.$hst.'/'.$svc.'/cmd/process_service_check_result',
            'method' => 'POST',
            'post'   => { plugin_state => 2, plugin_output => "broken" },
            'like'   => [ 'Command successfully submitted' ],
        );
    }
}

###############################################################################
