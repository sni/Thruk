use strict;
use warnings;
use Test::More;
use Config::General;
use Data::Dumper;
use Sys::Hostname;

my $core_conf = 't/selenium/server.conf';

#eval "use Test::More 0.92";
#plan skip_all => 'Test::More >= 0.92 required' if $@;

eval "use Test::WWW::Selenium";
plan skip_all => 'Test::WWW::Selenium required' if $@;
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Author test. Set $ENV{TEST_SELENIUM} to a true value to run.' unless $ENV{TEST_SELENIUM};

my $conf   = new Config::General(
                          -ConfigFile => $core_conf,
                 ) or die('cannot read '.$core_conf);
my %config = $conf->getall;
if(ref $config{'selenium_core'} ne 'ARRAY') {
   my $tmp = $config{'selenium_core'};
   $config{'selenium_core'} = [ $tmp ];
}

my @selenium_tests = glob('t/selenium/*.t');

plan tests => scalar @selenium_tests * scalar @{$config{'selenium_core'}};

TODO: {
local $TODO = "all selenium tests are not productive yet";
for my $test (@selenium_tests) {
    for my $core (@{$config{'selenium_core'}}) {
        $ENV{SELENIUM_TEST_URL}     = 'http://'.hostname.':3000';
        $ENV{SELENIUM_TEST_BROWSER} = $core->{'browser'};
        $ENV{SELENIUM_TEST_HOST}    = $core->{'host'};
        $ENV{SELENIUM_TEST_PORT}    = $core->{'post'};
        diag("checking ".$core->{'browser'}." on selenium server ".$core->{'host'}.':'.$core->{'port'});
        my $testname = $core->{'browser'}." on ".$core->{'host'}." file: ".$test;
        subtest $testname => sub {
            my $testcode = slurp($test);
            #my $rt       = eval $testcode;
            my $rt = 1;
            is($rt, 0, 'subtests');
        }
    }
}
};

sub slurp {
    my $file = shift;
    local( $/ );
    open( my $fh, $file ) or die "unable to read file $file: $!\n";
    my $text = <$fh>; 
    return $text;
}
