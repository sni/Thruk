use strict;
use warnings;
use Test::More tests => 14;
use Data::Dumper;
use Log::Log4perl qw(:easy);

$Data::Dumper::Sortkeys = 1;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Model::Thruk' }
use Catalyst::Test 'Thruk';

################################################################################
# initialize backend manager
my $m;
$m = Thruk::Model::Thruk->new();
isa_ok($m, 'Thruk::Model::Thruk');
my $b = $m->{'obj'};
isa_ok($b, 'Thruk::Backend::Manager');

Log::Log4perl->easy_init($TRACE);
my $logger = Log::Log4perl->get_logger();
$b->init(
  'config'  => Thruk->config,
);

is($b->{'initialized'}, 1, 'Backend Manager Initialized') or BAIL_OUT('no need to run further tests without valid connection');

my $disabled_backends = $b->disable_hidden_backends();
$b->disable_backends($disabled_backends);

################################################################################
# set verbose mode
for my $backend ( @{$b->{'backends'}} ) {
    #$backend->{'class'}->{'live'}->{'backend_obj'}->{'verbose'} = 1;
    #$backend->{'class'}->{'live'}->{'backend_obj'}->{'logger'}  = $logger;
}

################################################################################
# get testdata
my($hostname,$servicename) = TestUtils::get_test_service();

################################################################################
# expand host command
my $hosts = $b->get_hosts( filter => [ { 'name' => $hostname } ] );
ok(scalar @{$hosts} > 0, 'got host data');

my $cmd = $b->expand_command(
    'host' => $hosts->[0],
);

isnt($cmd, undef, 'got expanded command for host');
isnt($cmd->{'line_expanded'}, undef, 'expanded command: '.$cmd->{'line_expanded'});

################################################################################
# expand service command
my $services = $b->get_services( filter => [ { 'host_name' => $hostname, 'description' => $servicename } ] );
ok(scalar @{$services} > 0, 'got service data');

$cmd = $b->expand_command(
    'host'    => $hosts->[0],
    'service' => $services->[0],
);

isnt($cmd, undef, 'got expanded command for service');
isnt($cmd->{'line_expanded'}, undef, 'expanded command: '.$cmd->{'line_expanded'});
