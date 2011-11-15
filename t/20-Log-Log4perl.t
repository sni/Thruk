use strict;
use warnings;
use Test::More;
use File::Copy;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use lib('t');

BEGIN {
    unless($ENV{TEST_AUTHOR}) {
        plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    }
    if(-e 'log4perl.conf') {
        plan skip_all => 'there is a log4perl.conf already, cannot test';
    }
}

# copy our test log4perl config
ok(copy('t/data/log4perl.conf', 'log4perl.conf'), 'copy test config') or BAIL_OUT("copy failed: $!");

require TestUtils;
import TestUtils;

# test some pages
my $pages = [
    '/thruk/cgi-bin/tac.cgi',
    '/thruk/side.html',
];
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

# do they exist all all?
is(-e '/tmp/thruk_test_error.log', 1, 'thruk_test_error.log exists');
is(-e '/tmp/thruk_test_debug.log', 1, 'thruk_test_debug.log exists');
is(-s '/tmp/thruk_test_error.log', 0, 'thruk_test_error.log is empty') or diag(qx|cat /tmp/thruk_test_error.log|);

ok(`grep '[DEBUG]' /tmp/thruk_test_debug.log | wc -l` > 0, 'debug log contains debug messages');

# clean up
ok(unlink('log4perl.conf'), 'unlink test config');
ok(unlink('/tmp/thruk_test_error.log'), 'unlink test logfile');
ok(unlink('/tmp/thruk_test_debug.log'), 'unlink test debug file');
done_testing();
