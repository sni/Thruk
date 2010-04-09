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

$sel->open_ok("/thruk/");
$sel->click_ok("link=Services");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->click_ok("//tr[\@id='r0']/td[4]");
$sel->click_ok("//tr[\@id='r1']/td[4]");
$sel->click_ok("//tr[\@id='r2']/td[4]");
$sel->click_ok("//tr[\@id='r3']/td[4]");
$sel->click_ok("//tr[\@id='r4']/td[4]");
$sel->value_is("multi_cmd_submit_button", "submit command for 5 services");
$sel->click_ok("//tr[\@id='r0']/td[1]/table/tbody/tr/td[1]");
$sel->value_is("multi_cmd_submit_button", "submit command for 5 services and 1 host");
$sel->click_ok("opt1");
$sel->click_ok("multi_cmd_submit_button");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->click_ok("//div[\@id='thruk_message']/table/tbody/tr/td[1]/span");
$sel->is_text_present_ok("Commands successfully submitted");
$sel->click_ok("filter_button");
$sel->text_is("s0_filter_title", "Display Filters:");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht4");
$sel->click_ok("s0_ht8");
$sel->click_ok("s0_ht1");
$sel->click_ok("s0_accept_ht");
$sel->text_is("s0_htn", "Up");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht4");
$sel->click_ok("s0_accept_ht");
$sel->text_is("s0_htn", "Up | Down");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht8");
$sel->click_ok("s0_accept_ht");
$sel->text_is("s0_htn", "Up | Down | Unreachable");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht2");
$sel->click_ok("s0_accept_ht");
$sel->text_is("s0_htn", "All problems");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht1");
$sel->click_ok("s0_accept_ht");
$sel->is_text_present_ok("Pending | Down | Unreachable");
$sel->click_ok("s0_btn_accept_search");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->is_text_present_ok("Display Filters:");
$sel->text_is("//td[\@id='s0_add_new_filter_button']/img", "");
$sel->click_ok("//td[\@id='s0_add_new_filter_button']/img");
WAIT: {
    for (1..60) {
        if (eval { $sel->is_element_present("s0_1_ts") }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
WAIT: {
    for (1..60) {
        if (eval { $sel->is_element_present("s0_1_value") }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
$sel->select_ok("s0_1_ts", "label=Servicegroup");
$sel->click_ok("//select[\@id='s0_1_ts']/option[5]");
$sel->click_ok("s0_1_value");
$sel->type_keys_ok("s0_1_value", "cri");
WAIT: {
    for (1..60) {
        if (eval { $sel->is_element_present("//div[\@id='search-results']/ul/li[1]/b/i") }) { pass; last WAIT }
        sleep(1);
    }
    fail("timeout");
}
$sel->text_is("//div[\@id='search-results']/ul/li[1]/b/i", "1 Servicegroups");
$sel->click_ok("link=critical");
$sel->click_ok("s0_btn_accept_search");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->click_ok("s0_filter_button_mini");
$sel->click_ok("filter_button");
$sel->is_text_present_ok("Display Filters:");
$sel->click_ok("//table[\@id='s0_filterTable']/tbody/tr[7]/td[3]/input");
$sel->click_ok("//input[\@name='delete Filter']");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht2");
$sel->click_ok("s0_accept_ht");
$sel->click_ok("//img[\@alt='add new filter']");
$sel->click_ok("s1_htn");
$sel->click_ok("s1_ht2");
$sel->click_ok("s1_ht4");
$sel->click_ok("s1_ht1");
$sel->click_ok("s1_accept_ht");
$sel->click_ok("s0_htn");
$sel->click_ok("s0_ht2");
$sel->click_ok("s0_ht4");
$sel->click_ok("s0_ht8");
$sel->click_ok("s0_accept_ht");
$sel->click_ok("s0_btn_accept_search");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->text_is("s0_htn", "Pending");
$sel->text_is("s1_htn", "Unreachable");
$sel->click_ok("s0_hpn");
$sel->click_ok("s0_hp1");
$sel->click_ok("s0_hp4");
$sel->click_ok("s0_hp16");
$sel->click_ok("s0_hp64");
$sel->click_ok("s0_hp256");
$sel->click_ok("s0_hp1024");
$sel->click_ok("s0_hp4096");
$sel->click_ok("s0_hp16384");
$sel->click_ok("s0_hp65536");
$sel->click_ok("s0_hp262144");
$sel->click_ok("s0_accept_hp");
$sel->text_is("s0_hpn", "In Scheduled Downtime & Has Been Acknowledged & Checks Disabled & Event Handler Disabled & Flap Detection Disabled & Is Flapping & Notifications Disabled & Passive Checks Disabled & Passive Checks & In Hard State");
$sel->click_ok("s1_hpn");
$sel->click_ok("s1_hp2");
$sel->click_ok("s1_hp8");
$sel->click_ok("s1_hp32");
$sel->click_ok("s1_hp128");
$sel->click_ok("s1_hp512");
$sel->click_ok("s1_hp2048");
$sel->click_ok("s1_hp8192");
$sel->click_ok("s1_hp32768");
$sel->click_ok("s1_hp131072");
$sel->click_ok("s1_hp524288");
$sel->click_ok("s1_accept_hp");
$sel->text_is("s1_hpn", "Not In Scheduled Downtime & Has Not Been Acknowledged & Checks Enabled & Event Handler Enabled & Flap Detection Enabled & Is Not Flapping & Notifications Enabled & Passive Checks Enabled & Active Checks & In Soft State");
$sel->click_ok("s0_btn_accept_search");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
$sel->text_is("s0_hpn", "In Scheduled Downtime & Has Been Acknowledged & Checks Disabled & Event Handler Disabled & Flap Detection Disabled & Is Flapping & Notifications Disabled & Passive Checks Disabled & Passive Checks & In Hard State");
$sel->text_is("s1_hpn", "Not In Scheduled Downtime & Has Not Been Acknowledged & Checks Enabled & Event Handler Enabled & Flap Detection Enabled & Is Not Flapping & Notifications Enabled & Passive Checks Enabled & Active Checks & In Soft State");
$sel->click_ok("s0_hpn");
$sel->click_ok("s0_hp1");
$sel->click_ok("s0_hp4");
$sel->click_ok("s0_hp16");
$sel->click_ok("s0_hp64");
$sel->click_ok("s0_hp256");
$sel->click_ok("s0_hp1024");
$sel->click_ok("s0_hp4096");
$sel->click_ok("s0_hp16384");
$sel->click_ok("s0_hp65536");
$sel->click_ok("s0_hp262144");
$sel->click_ok("s0_accept_hp");
$sel->click_ok("s1_hpn");
$sel->click_ok("s1_accept_hp");
$sel->click_ok("s1_btn_del_search");
$sel->click_ok("s0_btn_accept_search");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("Current Network Status");
