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

$ENV{'THRUK_TEST_NO_LOG'} = "";

my($res, $c) = ctx_request('/thruk/side.html');

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/test.cgi',
    'like'    => 'Read what\'s new in Thruk',
);
# should not have leaks under normal conditions
unlike($ENV{'THRUK_TEST_NO_LOG'}, '/found leaks:/', 'got leak str');
unlike($ENV{'THRUK_TEST_NO_LOG'}, '/Thruk::Context=/', 'got leaks location');
$ENV{'THRUK_TEST_NO_LOG'} = "";

# test leak detection
Thruk::Utils::Log::reset_logging();
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/test.cgi?action=leak',
    'like'    => 'Read what\'s new in Thruk',
);

like($ENV{'THRUK_TEST_NO_LOG'}, '/found leaks:/', 'got leak str');
like($ENV{'THRUK_TEST_NO_LOG'}, '/Thruk::Context=/', 'got leaks location');

END {
    # restore env
    $ENV{'THRUK_MODE'} = 'TEST';
}
