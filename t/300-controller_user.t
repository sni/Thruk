use warnings;
use strict;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 26;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::user' }

my $pages = [
    { url => '/thruk/cgi-bin/user.cgi', like => ['Username', 'Change Password'] },
    { url => '/thruk/cgi-bin/user.cgi?clear_auth_cache=1', like => ['Username', 'Change Password'], follow => 1 },
];

for my $url (@{$pages}) {
    if(ref $url eq 'HASH') {
        TestUtils::test_page( %{$url} );
    } else {
        TestUtils::test_page( 'url' => $url );
    }
}
