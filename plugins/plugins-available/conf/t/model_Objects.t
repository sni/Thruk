use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

use lib 'plugins/plugins-available/conf/lib/';
use_ok 'Monitoring::Config::Multi';

done_testing();
