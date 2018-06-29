use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s ($ENV{'THRUK_CONFIG'} || '.').'/thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    `psql -V >/dev/null 2>&1`;
    plan skip_all => 'psql required' if $? != 0;
}

plan tests => 5;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

# fetch logs from mysql
TestUtils::test_command({
    cmd  => './support/icinga2_ido_fetchlogs.sh postgres',
    like => ['/SERVICE ALERT:/', '/HOST ALERT:/'],
    env  => {
      IDO_DB_USER => "icinga",
      IDO_DB_HOST => "127.0.0.1",
      IDO_DB_PORT => "60432",
      IDO_DB_PW   => "icinga",
      IDO_DB_NAME => "icinga",
    },
});
