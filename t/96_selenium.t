use strict;
use warnings;
use Test::More;

eval "use Test::WWW::Selenium";
plan skip_all => 'Test::WWW::Selenium required' if $@;
plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

#my @test_browser   = qw/*firefox *opera/;
my @test_browser   = qw/*opera/;
my @selenium_tests = glob('t/selenium/*.t');

plan tests => scalar @selenium_tests * scalar @test_browser;

$ENV{SELENIUM_TEST_URL} = 'http://localhost:3000';

for my $test (@selenium_tests) {
    for my $browser (@test_browser) {
        subtest $test => sub {
            $ENV{SELENIUM_TEST_BROWSER} = $browser;
            require_ok($test);
        }
    }
}
