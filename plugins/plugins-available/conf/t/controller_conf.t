use strict;
use warnings;
use Test::More tests => 51;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test modules
use_ok 'Thruk::Controller::conf';
use_ok 'Thruk::Utils::Conf::Defaults';
use_ok 'Thruk::Utils::Conf';

###########################################################
# test some functions
my $conf_in = "# blah comment
# blah comment 2

test = 1
# more comments
blub = 2
foo = 2


";
my $conf_exp = "# blah comment
# blah comment 2

test=10,1,5
# more comments
blub=5
foo = 2


";
my $data = { test => ["10","1","5"], blub => "5" };
my $got  = Thruk::Utils::Conf::merge_conf($conf_in, $data);
is($got, $conf_exp, "merge config");

###########################################################
# test some functions
$conf_in = "
test = 1
test = 2
test = 3
";
$conf_exp = "
test=1,4,5
blub=5
";
$data = { test => ["1","4","5"], blub => "5" };
$got  = Thruk::Utils::Conf::merge_conf($conf_in, $data);
is($got, $conf_exp, "merge config II");

###########################################################
# test some pages
my $pages = [
    '/conf',
    '/thruk/cgi-bin/conf.cgi',
    '/thruk/cgi-bin/conf.cgi?type=access',
    '/thruk/cgi-bin/conf.cgi?type=cgi',
    '/thruk/cgi-bin/conf.cgi?type=thruk',
];
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Config Tool',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
