use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 76;

    use lib('t');
    require TestUtils;
    import TestUtils;

    use IO::Socket::SSL;
    IO::Socket::SSL::set_ctx_defaults( SSL_verify_mode => 0 );
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = "0";
}

$ENV{'THRUK_TEST_AUTH_KEY'}  = "key_tier1a";
$ENV{'THRUK_TEST_AUTH_USER'} = "omdadmin";

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# make sure cron file is there
my $cronfile = 'etc/cron.d/thruk-plugin-node-control';
ok(-e $cronfile, $cronfile." does exist");
my $target = readlink($cronfile);
ok($target eq '../thruk/plugins-enabled/node-control/cron', 'cron points to correct location');

###########################################################
# update facts
for my $peer ('tier1a', 'tier2c', 'tier2e') {
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk nc facts '.$peer,
        errlike   => ['/'.$peer.' updated facts sucessfully: OK/'],
    });
}

###########################################################
TestUtils::test_page(
    url      => 'https://localhost/demo/thruk/cgi-bin/node_control.cgi',
    like     => ['6.66-test'],
);

TestUtils::test_page(
    url      => 'https://localhost/demo/thruk/cgi-bin/node_control.cgi',
    post     => { "action" => "save_options", "omd_default_version" => "6.66-test" },
    redirect => 1,
);

TestUtils::test_page(
    url      => 'https://localhost/demo/thruk/cgi-bin/node_control.cgi',
    post     => { "action" => "omd_restart", "peer" => "tier2c", "service" => "crontab" },
    like     => ['"success" : 1'],
);

TestUtils::test_command({
    cmd    => '/usr/bin/env thruk nc list',
    like   => ['/tier2c/', '/Rocky/', '/Ubuntu/', '/demo/', '/OK/'],
});

TestUtils::test_command({
    cmd    => '/usr/bin/env thruk nc setversion 6.66-test',
    like   => ['/default version successfully set/', '/6.66-test/'],
});

TestUtils::test_command({
    cmd     => '/usr/bin/env thruk nc cleanup tier2a',
    errlike => ['/tier2a cleanup sucessfully/'],
});

TestUtils::test_command({
    cmd     => '/usr/bin/env thruk nc install tier2c',
    errlike => ['/already installed/', '/tier2c install sucessfully/'],
});

# run update to test version
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk nc update tier2c',
    errlike => ['/updating demo on tier2c/', '/tier2c update sucessfully/', '/OMD_SITE=demo/', '/OMD_UPDATE=/'],
});

# and back...
my $omd_version = `omd version -b`; chomp($omd_version);
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk nc update tier2c --version='.$omd_version,
    errlike => ['/updating demo on tier2c/', '/tier2c update sucessfully/', '/OMD_SITE=demo/', '/OMD_UPDATE=/'],
});

TestUtils::test_command({
    cmd     => '/usr/bin/env thruk nc runtime tier3a',
    errlike => ['/tier3a updated runtime sucessfully: OK/'],
});
