use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 66;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::tac' }

for my $sitepanel (qw/off auto list compact collapsed/) {
    TestUtils::overrideConfig('sitepanel', $sitepanel);
    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/tac.cgi',
        'like'    => 'Tactical Monitoring Overview',
    );
}
