
use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 51;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::set_test_user_token();
use_ok 'Thruk::Controller::rest_v1';
my($host,$service) = ('localhost', 'Users');
my $original_bp;

################################################################################
test_page({
    url     => 'GET /thruk/bp',
    like    => ['"name" : "Test Business Process"', '"id" : "1",', '"state_type" : "both",'],
});

################################################################################
# update business process
test_page({
    url     => 'PATCH /thruk/bp/1',
    post    => {"state_type" => "hard", "nodes" => [{"function" => "best()"}] },
    like    => ['business process sucessfully updated'],
});
test_page({
    url     => 'GET /thruk/bp/1',
    like    => ['"name" : "Test Business Process"', '"id" : "1",', '"state_type" : "hard",', 'best()', 'worst()'],
});

################################################################################
# revert back to normal
test_page({
    url     => 'POST /thruk/bp/1',
    post    => \$original_bp,
    like    => ['business process sucessfully updated'],
});
test_page({
    url     => 'GET /thruk/bp/1',
    like    => ['"name" : "Test Business Process"', '"id" : "1",', '"state_type" : "both",'],
});



################################################################################
sub test_page {
    my($test) = @_;
    my($method, $url) = split(/\s+/mx, $test->{'url'}, 2);
    $test->{'url'}          = '/thruk/r'.$url;
    $test->{'method'}       = $method;
    $test->{'content_type'} = 'application/json;charset=UTF-8';
    my $page = TestUtils::test_page(%{$test});
    if(!defined $original_bp) {
        my $data = decode_json($page->{'content'});
        $original_bp = $data->[0];
    }
}
