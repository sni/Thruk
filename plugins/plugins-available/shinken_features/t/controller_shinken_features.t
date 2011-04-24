use strict;
use warnings;
use Data::Dumper;
use Test::More;
use Catalyst::Test 'Thruk';
$Data::Dumper::Sortkeys = 1;

my($res, $c) = ctx_request('/thruk/side.html');
if($c->stash->{'enable_shinken_features'}) {
    plan tests => 32;
} else {
    plan skip_all => 'pure shinken backend required'
}

use lib('t');
require TestUtils;
import TestUtils;

use_ok 'Thruk::Controller::shinken_features';

my $pages = [
    '/thruk/cgi-bin/outagespbimp.cgi',
];
my $problem_host;
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Problems and Impacts',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}


# get a problem host
my $hst_pbs = $c->{'db'}->get_hosts(filter => [ is_problem => 1 ]);
my $problem_host = $hst_pbs->[0]->{'name'};
my($host,$service) = TestUtils::get_test_service();
$pages = [
    '/thruk/cgi-bin/shinken_status.cgi?style=bothtypes&s0_type=impact&s0_op=%3D&s0_value='.$problem_host.'&title=Impacts of '.$problem_host,
    '/thruk/cgi-bin/shinken_status.cgi?style=bothtypes&s0_type=rootproblem&s0_op=%3D&s0_value='.$host.'/'.$service.'&title=Root%20problem%20of%20'.$host.'/'.$service,
];
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Current Network Status',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
