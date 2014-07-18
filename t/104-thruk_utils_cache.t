use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw/tempfile/;

plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
plan tests => 11;

use_ok('Thruk::Utils::Cache');

my $testkeys = [
    'global',
    'filter',
    '[null,null,"[{\\"hoststatustypes\\":15,\\"hostprops\\":0,\\"servicestatustypes\\":31,\\"serviceprops\\":0}]"]',
    '{"d":"60m"}',
];
my($fh, $file) = tempfile();
unlink($file);
close($fh);

ok(!-f $file, "file does not exist yet: ".$file);
my $cache = Thruk::Utils::Cache->new($file);
ok(-f $file, "file does been created: ".$file);

###############################################################################
# no keys
my $data = $cache->get();
is_deeply($data, {}, 'get complete cache');

###############################################################################
# one key
$cache->set("test", "data");
$data = $cache->get("test");
is_deeply($data, "data", 'get cache data');

###############################################################################
# two keys
$cache->set("key1", "key2", "data");
$data = $cache->get("key1", "key2");
is_deeply($data, "data", 'get cache data with 2 keys');

###############################################################################
$data = $cache->get();
my $expected = {
          'test' => 'data',
          'key1' => { 'key2' => 'data' }
};
is_deeply($data, $expected, 'get complete cache now');

###############################################################################
# complex keys 1
$data = $cache->get(@{$testkeys});
is_deeply($data, undef, 'get complex cache 1');
$cache->set(@{$testkeys}, { test => "blah" });
$data = $cache->get(@{$testkeys});
is_deeply($data, { test => "blah" }, 'get complex cache 2');

###############################################################################
# complex keys 2
my @tmp = ($testkeys->[0]);
$data = $cache->get(@tmp, $testkeys->[1], $testkeys->[2], $testkeys->[3]);
is_deeply($data, { test => "blah" }, 'get complex cache 2');

###############################################################################
# cleanup
ok(unlink($file), 'remove tempfile');
