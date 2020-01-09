use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

$ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
###############################################################################
TestUtils::test_page(
    'url'     => '/thruk/r/sites?status=0&columns=count(*)',
    'waitfor' => '"count\(\*\)"\ :\ 2',
);

###############################################################################
# fetch backend ids
my $test = TestUtils::test_page(
    'url'    => '/thruk/r/sites',
    'like'   => [
                'addr',
                'id',
                'name',
            ],
);
my $procinfo = Cpanel::JSON::XS::decode_json($test->{'content'});
my $ids      = {map { $_->{'name'} => $_->{'id'} } @{$procinfo}};
is(scalar keys %{$ids}, 2, 'got backend ids') || die("all backends required");
ok(defined $ids->{'omd'}, 'got backend ids II');

###############################################################################
# force reschedule checks
for my $site (qw/local remote/) {
  for my $hst (qw/pnp grafana/) {
    TestUtils::test_page(
        'url'    => '/thruk/r/hosts/'.$site.'-'.$hst.'/cmd/schedule_forced_host_check',
        'method' => 'POST',
        'like'   => [ 'Command successfully submitted' ],
    );
    for my $svc (qw/Ping Load/) {
        TestUtils::test_page(
            'url'    => '/thruk/r/services/'.$site.'-'.$hst.'/'.$svc.'/cmd/schedule_forced_svc_check',
            'method' => 'POST',
            'like'   => [ 'Command successfully submitted' ],
        );
    }
  }
}

###############################################################################
# test graph export
#for my $site (qw/local remote/) {
for my $site (qw/local/) {
  for my $hst (qw/pnp grafana/) {
    TestUtils::test_page(
      'url'     => '/thruk/r/extinfo.cgi?type=grafana&host='.$site.'-'.$hst.'&service=Load',
      'waitfor' => 'PNG',
    );
  }
}

done_testing();
