use warnings;
use strict;
use Data::Dumper;
use Test::More;

use Thruk::Backend::Manager ();

BEGIN {
    plan skip_all => 'backends required' if(!-s ($ENV{'THRUK_CONFIG'} || '.').'/thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::notifications' }

my $c = TestUtils::get_c();
# wait till our backend is up and has logs
for my $x (1..90)  {
    my $peer = $c->{'db'}->get_peers(1)->[0];
    my $res = [Thruk::Backend::Manager::get_logs_start_end_no_filter($peer->{'class'})];
    if($res->[0] && $res->[0] > 0) {
        ok(1, "got log start/end at retry: ".$x);
        last;
    }
    ok(1, "log start/end retry: $x");
    sleep(1);
}

# import logs
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi?logcache_update=1',
    'like'    => [],
    'follow'  => 1,
    'waitfor' => 'LOG\ VERSION',
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi',
    'follow'  => 1,
    'like'    => [],
);
TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/showlog.cgi',
    'like'   => ["Event Log", "LOG VERSION: 2.0", "Local time is"],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/extinfo.cgi?type=4&logcachedetails=abcd',
    'follow'  => 1,
    'like'    => ['Logcache Details for Backend', 'Log Entries by Type', 'untyped', 'timeperiod transition'],
);

################################################################################
# check common import issues
my $peer   = $c->{'db'}->get_peers(1)->[0]->{'class'}->{'_peer'};
my $prefix = $peer->{'key'};
my $dbh    = $peer->logcache()->_dbh();
{
    my @data   = @{$dbh->selectall_arrayref('SELECT * FROM `'.$prefix.'_log` l WHERE l.state_type IS NULL AND l.type = "SERVICE ALERT" LIMIT 10', { Slice => {} })};
    is(scalar @data, 0, "all service alerts have a state_type set") or diag(Dumper(\@data));
};

# cannot determine fixed number of tests, number depends on wether initial import redirects or not,
# which depends on machine load and speed (initial import redirects after 10 seconds)
done_testing();
