use strict;
use warnings;
use Time::HiRes qw(sleep);
use Test::WWW::Selenium;
use Test::More "no_plan";
use Test::Exception;

my $url     = $ENV{SELENIUM_TEST_URL}     || "http://localhost:3000/";
my $browser = $ENV{SELENIUM_TEST_BROWSER} || "*firefox";
my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => $browser,
                                    browser_url => $url
                                  );

$sel->open_ok("/thruk/cgi-bin/status.cgi?hidesearch=2&s0_op=~&s0_type=search&s0_value=n1_test_host_000");
$sel->title_is("Current Network Status");
$sel->click_ok("link=Hosts");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->click_ok("//tr[\@id='r1']/td[3]");
$sel->value_is("multi_cmd_submit_button", "submit command for 1 host");
$sel->click_ok("//tr[\@id='r2']/td[3]");
$sel->value_is("multi_cmd_submit_button", "submit command for 2 hosts");
$sel->click_ok("//tr[\@id='r3']/td[3]");
$sel->value_is("multi_cmd_submit_button", "submit command for 3 hosts");
$sel->click_ok("//tr[\@id='r3']/td[4]");
$sel->value_is("multi_cmd_submit_button", "submit command for 2 hosts");
$sel->click_ok("opt1");
$sel->click_ok("multi_cmd_submit_button");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->is_text_present_ok("Commands successfully submitted");
