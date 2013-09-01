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
        `diff t/data/log4perl.conf log4perl.conf`;
        my $rc = $?>>8;
        plan skip_all => 'there is a log4perl.conf already, cannot test' if $rc != 0;
    }
    $ENV{'THRUK_SRC'} = 'TEST';
}

plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};

# copy our test log4perl config
ok(copy('t/data/log4perl.conf', 'log4perl.conf'), 'copy test config') or BAIL_OUT("$0: copy failed: $!");

if(defined $ENV{'CATALYST_SERVER'}) {
    move('/etc/thruk/log4perl.conf', '/etc/thruk/log4perl.conf.orig');
    move('log4perl.conf', '/etc/thruk/log4perl.conf');
}

require TestUtils;
import TestUtils;

# reload apache
if(defined $ENV{'CATALYST_SERVER'}) {
    -e '/etc/init.d/httpd'  && print `/etc/init.d/httpd reload`;
    -e '/etc/init.d/apache' && print `/etc/init.d/apache reload`;
}

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
is(-e '/tmp/thruk_test_error.log', 1, 'thruk_test_error.log exists');
is(-e '/tmp/thruk_test_debug.log', 1, 'thruk_test_debug.log exists');
is(-s '/tmp/thruk_test_error.log', 0, 'thruk_test_error.log is empty') or diag(qx|cat /tmp/thruk_test_error.log|);

ok(`grep '[DEBUG]' /tmp/thruk_test_debug.log | wc -l` > 0, 'debug log contains debug messages');

# clean up
if(defined $ENV{'CATALYST_SERVER'}) {
    unlink('/etc/thruk/log4perl.conf');
    ok(move('/etc/thruk/log4perl.conf.orig', '/etc/thruk/log4perl.conf'), 'restore test config');
} else {
    ok(unlink('log4perl.conf'), 'unlink test config');
}
ok(unlink('/tmp/thruk_test_error.log'), 'unlink test logfile');
ok(unlink('/tmp/thruk_test_debug.log'), 'unlink test debug file');

# reload apache again
if(defined $ENV{'CATALYST_SERVER'}) {
    -e '/etc/init.d/httpd'  && print `/etc/init.d/httpd reload`;
    -e '/etc/init.d/apache' && print `/etc/init.d/apache reload`;
}

done_testing();
