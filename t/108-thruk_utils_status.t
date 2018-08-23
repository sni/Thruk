use strict;
use warnings;
use utf8;
use Test::More;

plan tests => 17;

use_ok('Thruk::Utils::Status');
use_ok('Monitoring::Livestatus::Class::Lite');

my $query = "name = 'test'";
_test_filter($query, 'Filter: name = test');
is($query, "name = 'test'", "original string unchanged");
_test_filter('name ~~ "test"', 'Filter: name ~~ test');
_test_filter('groups >= "test"', 'Filter: groups >= test');
_test_filter('check_interval != 5', 'Filter: check_interval != 5');
_test_filter('host = "a" AND host = "b"', "Filter: host = a\nFilter: host = b\nAnd: 2");
_test_filter('host = "a" AND host = "b" AND host = "c"', "Filter: host = a\nFilter: host = b\nFilter: host = c\nAnd: 3");
_test_filter('host = "a" OR host = "b"', "Filter: host = a\nFilter: host = b\nOr: 2");
_test_filter('host = "a" OR host = "b" OR host = "c"', "Filter: host = a\nFilter: host = b\nFilter: host = c\nOr: 3");
_test_filter("(name = 'test')", 'Filter: name = test');
_test_filter('(host = "a" OR host = "b") AND host = "c"', "Filter: host = a\nFilter: host = b\nOr: 2\nFilter: host = c\nAnd: 2");
_test_filter("name = 'te\"st'", 'Filter: name = te"st');
_test_filter("name = 'te(st)'", 'Filter: name = te(st)');
_test_filter("host_name = \"test\" or host_name = \"localhost\" and status = 0", "Filter: host_name = test\nFilter: host_name = localhost\nOr: 2\nFilter: status = 0\nAnd: 2");
_test_filter(' name ~~  "test"  ', 'Filter: name ~~ test');

sub _test_filter {
    my($filter, $expect) = @_;
    my $f = Thruk::Utils::Status::parse_lexical_filter($filter);
    my $s = Monitoring::Livestatus::Class::Lite->new('test.sock')->table('hosts')->filter($f)->statement(1);
    is(join("\n", @{$s}), $expect, 'got correct statement');
}