use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN {
    plan skip_all => 'backends required' if(!-f 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 14;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}


###########################################################
# check module
SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::mobile';
};

###########################################################
# initialize object config
TestUtils::test_page(
    'url'      => '/thruk/cgi-bin/mobile.cgi',
    'follow'   => 1,
    'like'     => 'Mobile Thruk',
);
