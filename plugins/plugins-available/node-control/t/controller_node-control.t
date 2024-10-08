use warnings;
use strict;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only'   if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'test skipped'      if defined $ENV{'NO_DISABLED_PLUGINS_TEST'};

    plan tests => 12;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test modules
unshift @INC, 'plugins/plugins-available/node-control/lib';
use_ok 'Thruk::Controller::node_control';

###########################################################
# test main page
TestUtils::test_page(
    'url'             => '/thruk/cgi-bin/node_control.cgi',
    'like'            => 'Node Control',
);
