use warnings;
use strict;
use Test::More;
use utf8;

plan tests => 45;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils');
use_ok('Thruk::Utils::Status');
use_ok('Monitoring::Livestatus::Class::Lite');

my $c = TestUtils::get_c();

my $query = "name = 'test'";
_test_filter($query, 'Filter: name = test');
is($query, "name = 'test'", "original string unchanged");
_test_filter('name ~~ "test"',
             'Filter: name ~~ test',
             "name ~~ 'test'");
_test_filter('groups >= "test"', 'Filter: groups >= test', "groups >= 'test'");
_test_filter('check_interval != 5', 'Filter: check_interval != 5');
_test_filter('host_name = "a" AND host_name = "b"',
             "Filter: host_name = a\nFilter: host_name = b\nAnd: 2",
             "host_name = 'a' and host_name = 'b'");
_test_filter('host_name = "a" AND host_name = "b" AND host_name = "c"',
             "Filter: host_name = a\nFilter: host_name = b\nFilter: host_name = c\nAnd: 3",
             "host_name = 'a' and host_name = 'b' and host_name = 'c'");
_test_filter('host_name = "a" OR host_name = "b"',
             "Filter: host_name = a\nFilter: host_name = b\nOr: 2",
             "host_name = 'a' or host_name = 'b'");
_test_filter('host_name = "a" OR host_name = "b" OR host_name = "c"',
             "Filter: host_name = a\nFilter: host_name = b\nFilter: host_name = c\nOr: 3",
             "host_name = 'a' or host_name = 'b' or host_name = 'c'");
_test_filter("(name = 'test')",
             'Filter: name = test',
             "name = 'test'");
_test_filter('(host_name = "a" OR host_name = "b") AND host_name = "c"',
             "Filter: host_name = a\nFilter: host_name = b\nOr: 2\nFilter: host_name = c\nAnd: 2",
             "(host_name = 'a' or host_name = 'b') and host_name = 'c'");
_test_filter("name = 'te\"st'", 'Filter: name = te"st');
_test_filter("name = 'te(st)'", 'Filter: name = te(st)');
_test_filter("host_name = \"test\" or host_name = \"localhost\" and status = 0",
             "Filter: host_name = test\nFilter: host_name = localhost\nOr: 2\nFilter: status = 0\nAnd: 2",
             "(host_name = 'test' or host_name = 'localhost') and status = 0");
_test_filter(' name ~~  "test"  ',
             'Filter: name ~~ test',
             "name ~~ 'test'");
_test_filter('host_name = "localhost" AND time > 1 AND time < 10',
             "Filter: host_name = localhost\nFilter: time > 1\nFilter: time < 10\nAnd: 3",
             "host_name = 'localhost' and time > 1 and time < 10");
_test_filter('host_name = "localhost" AND (time > 1 AND time < 10)',
             "Filter: host_name = localhost\nFilter: time > 1\nFilter: time < 10\nAnd: 2\nAnd: 2",
             "host_name = 'localhost' and (time > 1 and time < 10)");
_test_filter('last_check <= "-7d"', 'Filter: last_check <= '.(time() - 86400*7));
_test_filter('last_check <= "now + 2h"', 'Filter: last_check <= '.(time() + 7200));
_test_filter('last_check <= "lastyear"', 'Filter: last_check <= '.Thruk::Utils::_expand_timestring("lastyear"));
_test_filter('(host_groups ~~ "g1" AND host_groups ~~ "g2")  OR (host_name = "h1" and display_name ~~ ".*dn.*")',
             "Filter: host_groups ~~ g1\nFilter: host_groups ~~ g2\nAnd: 2\nFilter: host_name = h1\nFilter: display_name ~~ .*dn.*\nAnd: 2\nOr: 2",
             "(host_groups ~~ 'g1' and host_groups ~~ 'g2') or (host_name = 'h1' and display_name ~~ '.*dn.*')");

sub _test_filter {
    my($filter, $expect, $exp_ftext) = @_;
    my $f = Thruk::Utils::Status::parse_lexical_filter($filter);
    my $s = Monitoring::Livestatus::Class::Lite->new('test.sock')->table('hosts')->filter($f)->statement(1);
    $s    = join("\n", @{$s});
    $s      =~ s/(\d{10})/&_round_timestamps($1)/gemxs;
    $expect =~ s/(\d{10})/&_round_timestamps($1)/gemxs;
    is($s, $expect, 'got correct statement');

    my $txt = Thruk::Utils::Status::filter2text($c, "service", $f);
    is($txt, $exp_ftext//$filter, "filter text is fine") if $filter !~ m/last_check/mx;
}

# round timestamp by 30 seconds to avoid test errors on slow machines
sub _round_timestamps {
    my($x) = @_;
    $x = int($x / 30) * 30;
    return($x);
}

################################################################################
{
    my $params = {
        'dfl_s0_hostprops' => '0',
        'dfl_s0_hoststatustypes' => '15',
        'dfl_s0_op' => [
                        '=',
                        '~'
                        ],
        'dfl_s0_serviceprops' => '0',
        'dfl_s0_servicestatustypes' => '31',
        'dfl_s0_type' => [
                            'host',
                            'service'
                        ],
        'dfl_s0_val_pre' => [
                            '',
                            ''
                            ],
        'dfl_s0_value' => [
                            'localhost',
                            'http'
                        ],
        'dfl_s1_hostprops' => '0',
        'dfl_s1_hoststatustypes' => '15',
        'dfl_s1_op' => '=',
        'dfl_s1_serviceprops' => '0',
        'dfl_s1_servicestatustypes' => '31',
        'dfl_s1_type' => 'host',
        'dfl_s1_val_pre' => '',
        'dfl_s1_value' => 'test'
    };
    my $exp = [{
            'host_prop_filtername'          => 'Any',
            'host_statustype_filtername'    => 'All',
            'hostprops'                     => 0,
            'hoststatustypes'               => 15,
            'service_prop_filtername'       => 'Any',
            'service_statustype_filtername' => 'All',
            'serviceprops'                  => 0,
            'servicestatustypes'            => 31,
            'text_filter'                   => [{
                    'op'        => '=',
                    'type'      => 'host',
                    'val_pre'   => '',
                    'value'     => 'localhost'
                },
                {
                    'op'        => '~',
                    'type'      => 'service',
                    'val_pre'   => '',
                    'value'     => 'http'
                }]
        }, {
            'host_prop_filtername' => 'Any',
            'host_statustype_filtername' => 'All',
            'hostprops' => 0,
            'hoststatustypes' => 15,
            'service_prop_filtername' => 'Any',
            'service_statustype_filtername' => 'All',
            'serviceprops' => 0,
            'servicestatustypes' => 31,
            'text_filter' => [{
                    'op'        => '=',
                    'type'      => 'host',
                    'val_pre'   => '',
                    'value'     => 'test'
                }],
    }];
    my $got = Thruk::Utils::Status::get_searches($c, '', $params);
    is_deeply($got, $exp, "parsed search items from params");
    my $txt = Thruk::Utils::Status::search2text($c, "service", $got);
    my $ext_text = "((host_name = 'localhost' and (description ~~ 'http' or display_name ~~ 'http')) or host_name = 'test')";
    is($txt, $ext_text, "search2text worked")
}

################################################################################
{
    my $params = {'dfl_s0_hostprops' => '0','dfl_s0_hoststatustypes' => '15','dfl_s0_op' => '~','dfl_s0_serviceprops' => '0','dfl_s0_servicestatustypes' => '31','dfl_s0_type' => 'hostgroup','dfl_s0_value' => 'test','dfl_s0_value_sel' => '5','style' => 'detail'};
    my $exp = [
          {
            'host_prop_filtername' => 'Any',
            'host_statustype_filtername' => 'All',
            'hostprops' => 0,
            'hoststatustypes' => 15,
            'service_prop_filtername' => 'Any',
            'service_statustype_filtername' => 'All',
            'serviceprops' => 0,
            'servicestatustypes' => 31,
            'text_filter' => [
                               {
                                 'op' => '~',
                                 'type' => 'hostgroup',
                                 'val_pre' => '',
                                 'value' => 'test'
                               }
                             ]
          }
        ];
    my $got = Thruk::Utils::Status::get_searches($c, '', $params);
    is_deeply($got, $exp, "parsed search items from params");
    my $txt = Thruk::Utils::Status::search2text($c, "service", $got);
    my $ext_text = "host_groups ~~ 'test'";
    is($txt, $ext_text, "search2text worked")
}
