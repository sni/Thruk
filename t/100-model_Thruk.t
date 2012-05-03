use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Log::Log4perl qw(:easy);

$Data::Dumper::Sortkeys = 1;

plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
plan tests => 26;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
use_ok 'Thruk::Model::Thruk';
use Catalyst::Test 'Thruk';

################################################################################
# initialize backend manager
my $m;
$m = Thruk::Model::Thruk->new();
isa_ok($m, 'Thruk::Model::Thruk');
my $b = $m->{'obj'};
isa_ok($b, 'Thruk::Backend::Manager');

Log::Log4perl->easy_init($INFO);
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
unlike($cmd->{'line_expanded'}, qr/HOSTNAME/, 'expanded command line must not contain HOSTNAME');
unlike($cmd->{'line_expanded'}, qr/HOSTALIAS/, 'expanded command line must not contain HOSTALIAS');
unlike($cmd->{'line_expanded'}, qr/HOSTADDRESS/, 'expanded command line must not contain HOSTADDRESS');

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
unlike($cmd->{'line_expanded'}, qr/HOSTNAME/, 'expanded command line must not contain HOSTNAME');
unlike($cmd->{'line_expanded'}, qr/HOSTALIAS/, 'expanded command line must not contain HOSTALIAS');
unlike($cmd->{'line_expanded'}, qr/HOSTADDRESS/, 'expanded command line must not contain HOSTADDRESS');
unlike($cmd->{'line_expanded'}, qr/SERVICEDESC/, 'expanded command line must not contain SERVICEDESC');

################################################################################
# now set a ressource file
$b->{'config'}->{'resource_file'} = 't/data/resource.cfg';
$cmd = $b->expand_command(
    'host'    => $hosts->[0],
    'command' => {
        'name' => 'check_test',
        'line' => '$USER1$/check_test -H $HOSTNAME$'
    },
);
is($cmd->{'line_expanded'}, '/tmp/check_test -H '.$hosts->[0]->{'name'}, 'expanded command: '.$cmd->{'line_expanded'});
is($cmd->{'line'}, $hosts->[0]->{'check_command'}, 'host command is: '.$hosts->[0]->{'check_command'});
is($cmd->{'note'}, '', 'note should be empty');


################################################################################
$cmd = $b->expand_command(
    'host'    => {
        'state'         => 0,
        'check_command' => 'check_test!',
    },
    'command' => {
        'name' => 'check_test',
        'line' => '$USER1$/check_test $ARG1$'
    },
);
is($cmd->{'line_expanded'}, '/tmp/check_test ', 'expanded command: '.$cmd->{'line_expanded'});
is($cmd->{'note'}, '', 'note should be empty');

################################################################################
my $res1 = $b->_read_resource_file('t/data/resource.cfg');
my $res2 = $b->_read_resource_file('t/data/resource2.cfg');
is_deeply($res1, $res2, 'parsing resource.cfg');
