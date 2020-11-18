use strict;
use warnings;
use Test::More;
use File::Copy;
use lib('t');

my $log4perl_created;
BEGIN {
    unless($ENV{TEST_AUTHOR}) {
        plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    }
    if(-e 'log4perl.conf') {
        `diff t/data/log4perl.conf log4perl.conf`;
        my $rc = $?>>8;
        plan skip_all => 'there is a log4perl.conf already, cannot test' if $rc != 0;
    }
    $ENV{'THRUK_MODE'} = 'TEST';
    $ENV{'THRUK_USE_LMD_FEDERATION_FAILED'} = 1; # prevent errors logged from old LMD versions which would break the test
}

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
plan skip_all => 'backends required' if !-s 'thruk_local.conf';

# remove old leftovers
unlink('/tmp/thruk_test_error.log');
unlink('/tmp/thruk_test_debug.log');

# copy our test log4perl config
ok(copy('t/data/log4perl.conf', 'log4perl.conf'), 'copy test config') or BAIL_OUT("$0: copy failed: $!");
is(-e 'log4perl.conf', 1, 'log4perl.conf exists');
$log4perl_created = 1;

require TestUtils;
import TestUtils;
TestUtils::get_c();

$ENV{'THRUK_VERBOSE'} = 1;
$ENV{'THRUK_MODE'}    = 'FASTCGI'; # otherwise logging is set to screen
Thruk::Utils::Log::reset_logging();

# test some pages
my $pages = [
    '/thruk/cgi-bin/tac.cgi',
    '/thruk/side.html',
];
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
    );
}

# do they exist all all?
is(-e '/tmp/thruk_test_error.log', 1, 'thruk_test_error.log exists') or BAIL_OUT("logfile does not exist at all");
is(-e '/tmp/thruk_test_debug.log', 1, 'thruk_test_debug.log exists');
is(-s '/tmp/thruk_test_error.log', 0, 'thruk_test_error.log is empty') or diag(qx|cat /tmp/thruk_test_error.log|);

ok(`grep '[DEBUG]' /tmp/thruk_test_debug.log | wc -l` > 0, 'debug log contains debug messages');

ok(unlink('log4perl.conf'), 'unlink test config');
ok(unlink('/tmp/thruk_test_error.log'), 'unlink test logfile');
ok(unlink('/tmp/thruk_test_debug.log'), 'unlink test debug file');

done_testing();

END {
    if($log4perl_created && !$ENV{'THRUK_JOB_ID'}) {
        unlink("log4perl.conf");
        unlink('/tmp/thruk_test_error.log');
        unlink('/tmp/thruk_test_debug.log');
    }
}
