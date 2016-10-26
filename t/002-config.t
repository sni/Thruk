use strict;
use warnings;
use Data::Dumper;
use Test::More;

use_ok("Thruk");
use_ok("Thruk::Config");
my $config = Thruk::Config::get_config();
is(ref Thruk->config, 'HASH', "got a config");
ok(defined Thruk->config->{'version'}, "got a version");
$config = Thruk::Config::get_config('t/data/test_c_style.conf');
is($config->{'Thruk::Backend'}->{'peer'}->{'configtool'}->{'obj_readonly'}, '^(?!.*/test)', 'parsing c style comments');

eval "use Config::General";
if(!$@) {
    for my $file (qw|thruk.conf thruk_local.conf cgi.cfg support/naglint.conf.example t/data/test_hash_comments.cfg|) {
        next unless -f $file;
        ok(1, "reading: ".$file);
        my %general_conf = Config::General::ParseConfig(-ConfigFile => $file,
                                                        -UTF8       => 1,
                                                        -CComments  => 0,
        );
        my $thruk_conf = Thruk::Config::read_config_file($file);
        is_deeply($thruk_conf, \%general_conf, "Thruk::Config returns the same as Config::General for ".$file) or diag(Dumper($thruk_conf, \%general_conf));
    }
}

####################################################
$ENV{'THRUK_CONFIG'} = 't/data/nested_config';
$config = Thruk::Config::get_config();
my $expected_backends = {
    'peer' => [{ 'name' => 'local1' },
                { 'name' => 'local2' },
                { 'name' => 'local3' },
                { 'name' => 'local4' }
]};
is_deeply($config->{'Thruk::Backend'}, $expected_backends, "parsing backends from thruk_local.d");
is_deeply($config->{'backend_debug'}, 1, "parsing scalars from thruk_local.d");

done_testing();
