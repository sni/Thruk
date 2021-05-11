use warnings;
use strict;
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
my $files_created = 0;
my @ssis = qw/login-header.ssi login-header-foo.ssi login-footer.ssi login-footer-foo.ssi/;
for my $file (@ssis) {
    die("cannot test, ssi ssi/".$file." exists already") if -f 'ssi/'.$file;
}
$files_created = 1;
END {
    if($files_created) {
        for my $file (@ssis) {
            unlink("ssi/".$file);
        }
    }
}

my($res, $c) = ctx_request('/thruk/side.html');
my $rand = rand();

for my $place (qw/header footer/) {
    Thruk::Utils::IO::mkdir('ssi');

    Thruk::Utils::IO::write('ssi/login-'.$place.'.ssi', "test ssi string: ".$rand);
    $c->app->_set_ssi();
    TestUtils::test_page(url => '/thruk/cgi-bin/login.cgi', like => [ 'test ssi string', $rand ], code => 401 );

    Thruk::Utils::IO::write('ssi/login-'.$place.'-foo.ssi', "second ssi string");
    $c->app->_set_ssi();
    TestUtils::test_page(url => '/thruk/cgi-bin/login.cgi', like => [ 'test ssi string', $rand, 'second ssi string' ], code => 401 );

    unlink('ssi/login-'.$place.'.ssi');
    unlink('ssi/login-'.$place.'-foo.ssi');
}
