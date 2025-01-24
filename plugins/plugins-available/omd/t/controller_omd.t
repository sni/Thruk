use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan skip_all => 'internal test' if $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
plan skip_all => 'backends required' if !-s 'thruk_local.conf';
plan tests => 12;

###########################################################
# test modules

unshift @INC, 'plugins/plugins-available/omd/lib';
use_ok 'Thruk::Controller::omd';

###########################################################
# test main page
TestUtils::test_page(
    'url'             => '/thruk/cgi-bin/omd.cgi',
    'like'            => 'Top Statistics',
);
