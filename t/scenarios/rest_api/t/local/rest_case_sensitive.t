use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 230;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
$ENV{'THRUK_TEST_AUTH_KEY'}  = "testkey";
$ENV{'THRUK_TEST_AUTH_USER'} = "omdadmin";

_set_lmd(0);
_run_tests();
_set_lmd(1);
_run_tests();
_set_lmd(0);

###########################################################
sub _run_tests {
    TestUtils::test_page(
        url  => 'http://localhost/demo/thruk/r/sites/ALL/hosts?columns=name,peer_name&name=UPPERCASE',
        like => ['"name" : "UPPERCASE"'],
    );

    my $regex = [
        '^UPPERCASE$',
        '^UPPERCASE.*',
        '^UPPERCASE.*$',
        '^UPPER.*$',
        '^uppercase$',
        '^uppercase.*',
        '^uppercase.*$',
        '^upper.*$',
    ];

    for my $re (@{$regex}) {
        TestUtils::test_command({
            cmd  => '/usr/bin/env thruk r \'/sites/ALL/hosts?columns=name,peer_name&name[regex]='.$re.'\'',
            like => ['/"name" : "UPPERCASE"/'],
        });
        TestUtils::test_page(
            url  => 'http://localhost/demo/thruk/r/sites/ALL/hosts?columns=name,peer_name&name[regex]='.$re,
            like => ['"name" : "UPPERCASE"'],
        );
    }
}

###########################################################
# enable lmd and try again
sub _set_lmd {
    my($state) = @_;

    if($state) {
        TestUtils::test_command({
            cmd  => '/usr/bin/env sed -i etc/thruk/thruk_local.d/lmd.conf -e s/\#use_lmd_core=.*/use_lmd_core=1/g',
            like => ['/^$/'],
        });
    } else {
        TestUtils::test_command({
            cmd  => '/usr/bin/env sed -i etc/thruk/thruk_local.d/lmd.conf -e s/^.*use_lmd_core=.*/#use_lmd_core=1/g',
            like => ['/^$/'],
        });
    }

    TestUtils::test_command({
        cmd  => '/usr/bin/env omd reload apache',
        like => ['/Reloading apache configuration.*OK/'],
    });
    # wait till page is back online
    TestUtils::test_page(
        url     => 'http://localhost/demo/thruk/r/csv/sites/ALL/sites?columns=status&headers=0',
        waitfor => '^0$',
        like    => ['^0$'],
    );
}

###########################################################
