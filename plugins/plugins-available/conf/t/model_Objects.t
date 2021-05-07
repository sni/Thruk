use warnings;
use strict;
use Test::More;

use lib 'plugins/plugins-available/conf/lib/';

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

use_ok 'Monitoring::Config::Multi';

done_testing();
