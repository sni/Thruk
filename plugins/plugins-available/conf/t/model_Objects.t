use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};

use lib 'plugins/plugins-available/conf/lib/';
use_ok 'Monitoring::Config::Multi';

done_testing();
