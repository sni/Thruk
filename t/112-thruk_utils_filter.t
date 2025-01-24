use warnings;
use strict;
use Test::More;
use utf8;

plan tests => 31;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Utils::Filter');

###########################################################
{
    my $txt = 'pl=4.5%;10;20;0;100';
    ok(1, "parsing: ".$txt);
    my($data, $has_parents, $has_warn, $has_crit, $has_min, $has_max) = Thruk::Utils::Filter::split_perfdata($txt);
    is($has_parents, 0, "no parents");
    is($has_warn, 1, "has warnings");
    is($has_crit, 1, "has crit");
    is($has_min, 1, "has min");
    is($has_max, 1, "has max");
    is(scalar @{$data}, 1, "found 1 perf label");
    is($data->[0]->{'name'}, 'pl', "parsed name");
    is($data->[0]->{'value'}, '4.5', "parsed value");
    is($data->[0]->{'unit'}, '%', "parsed unit");
};

###########################################################
{
    my $txt = 'beans=100;50:;:100;0;100 caches=90;50:;:100;0;100';
    ok(1, "parsing: ".$txt);
    my($data, $has_parents, $has_warn, $has_crit, $has_min, $has_max) = Thruk::Utils::Filter::split_perfdata($txt);
    is($has_parents, 0, "no parents");
    is($has_warn, 1, "has warnings");
    is($has_crit, 1, "has crit");
    is($has_min, 1, "has min");
    is($has_max, 1, "has max");
    is(scalar @{$data}, 2, "found 2 perf label");
    is($data->[0]->{'name'}, 'beans', "parsed name");
    is($data->[0]->{'value'}, '100', "parsed value");
    is($data->[0]->{'unit'}, '', "parsed unit");
};

###########################################################
{
    my $txt = '::1rtmin=0.123ms;;;;';
    ok(1, "parsing: ".$txt);
    my($data, $has_parents, $has_warn, $has_crit, $has_min, $has_max) = Thruk::Utils::Filter::split_perfdata($txt);
    is($has_parents, 1, "no parents");
    is($has_warn, 0, "has warnings");
    is($has_crit, 0, "has crit");
    is($has_min, 0, "has min");
    is($has_max, 0, "has max");
    is(scalar @{$data}, 1, "found 2 perf label");
    is($data->[0]->{'name'}, 'rtmin', "parsed name");
    is($data->[0]->{'value'}, '0.123', "parsed value");
    is($data->[0]->{'unit'}, 'ms', "parsed unit");
};

###########################################################