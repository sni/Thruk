use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 5;

use_ok("Thruk");
use_ok("Thruk::Config");
my $config = Thruk::Config::get_config();
is(ref Thruk->config, 'HASH', "got a config");
ok(defined Thruk->config->{'version'}, "got a version");
$config = Thruk::Config::get_config('t/data/test_c_style.conf');
is($config->{'Thruk::Backend'}->{'peer'}->{'configtool'}->{'obj_readonly'}, '^(?!.*/test)', 'parsing c style comments');
