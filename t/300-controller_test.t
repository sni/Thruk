use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;

BEGIN {
    eval "use Devel::Cycle";
    plan skip_all => 'Devel::Cycle required' if $@;
    eval "use Devel::Gladiator";
    plan skip_all => 'Devel::Gladiator required' if $@;
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local tests only'  if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 27;
}

BEGIN {
    $ENV{'THRUK_LEAK_CHECK'} = '1';
    use lib('t');
    require TestUtils;
    import TestUtils;
}
END {
    delete $ENV{'THRUK_LEAK_CHECK'};
}
BEGIN { use_ok 'Thruk::Controller::test' }

# remove old leftovers
unlink('/tmp/thruk_test_error.log');
unlink('/tmp/thruk_test_debug.log');

my($res, $c) = ctx_request('/thruk/side.html');
$c->app->config->{'log4perl_conf'} = "t/data/log4perl.conf";
$c->app->init_logging();

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/test.cgi',
    'like'    => 'Read what\'s new in Thruk',
);
# should not have leaks under normal conditions
my $str = read_file('/tmp/thruk_test_error.log');
unlike($str, '/found leaks:/', 'got leak str');
unlike($str, '/Thruk::Context=/', 'got leaks location');
unlink('/tmp/thruk_test_error.log');
unlink('/tmp/thruk_test_debug.log');

# test leak detection
$c->app->init_logging();
$ENV{'THRUK_SRC'} = 'TEST_LEAK';
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/test.cgi?action=leak',
    'like'    => 'Read what\'s new in Thruk',
);

$str = read_file('/tmp/thruk_test_error.log');
like($str, '/found leaks:/', 'got leak str');
like($str, '/Thruk::Context=/', 'got leaks location');

END {
    # restore env
    $ENV{'THRUK_SRC'} = 'TEST';

    # remove old leftovers
    unlink('/tmp/thruk_test_error.log');
    unlink('/tmp/thruk_test_debug.log');
}
