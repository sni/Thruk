use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 51;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils::IO');
die("cannot test, ssi file exists already") if -f 'ssi/login-header.ssi';
die("cannot test, ssi file exists already") if -f 'ssi/login-header-foo.ssi';
die("cannot test, ssi file exists already") if -f 'ssi/login-footer.ssi';
die("cannot test, ssi file exists already") if -f 'ssi/login-footer-foo.ssi';

my($res, $c) = ctx_request('/thruk/side.html');
my $rand = rand();

for my $place (qw/header footer/) {
    Thruk::Utils::IO::mkdir('ssi');

    Thruk::Utils::IO::write('ssi/login-'.$place.'.ssi', "test ssi string: ".$rand);
    $c->app->_set_ssi();
    TestUtils::test_page(url => '/thruk/cgi-bin/login.cgi', like => [ 'test ssi string', $rand ] );

    Thruk::Utils::IO::write('ssi/login-'.$place.'-foo.ssi', "second ssi string");
    $c->app->_set_ssi();
    TestUtils::test_page(url => '/thruk/cgi-bin/login.cgi', like => [ 'test ssi string', $rand, 'second ssi string' ] );

    unlink('ssi/login-'.$place.'.ssi');
    unlink('ssi/login-'.$place.'-foo.ssi');
}
