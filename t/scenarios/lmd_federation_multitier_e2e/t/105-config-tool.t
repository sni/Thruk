use warnings;
use strict;
use Cpanel::JSON::XS;
use HTML::Entities;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 23;
}


BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###############################################################################
# federated config tool
TestUtils::test_page(
    'url'  => '/thruk/cgi-bin/conf.cgi',
    'like' => ['tier1a'],
);
TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/conf.cgi?sub=objects&action=browser',
    'like'   => ['commands.cfg'],
    'follow' => 1,
);

###############################################################################
