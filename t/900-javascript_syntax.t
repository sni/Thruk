use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

#################################################
my @jsfiles = glob('root/thruk/javascript/thruk-*.js
                    plugins/plugins-available/*/root/*.js
                    plugins/plugins-available/panorama/templates/panorama_js.tt
                    plugins/plugins-available/panorama/templates/_panorama_js_*.tt
                    ');
for my $file (@jsfiles) {
    ok(1, "checking ".$file);
    next if $file =~ m/bigscreen/mxi;
    next if $file =~ m/OpenLayers/mxi;
    next if $file =~ m/all_in_one/mxi;
    TestUtils::verify_js($file);
}

my @tplfiles = split(/\n/, `find templates plugins/plugins-available/*/templates/. themes/themes-available/*/templates -name \*.tt`);
for my $file (@tplfiles) {
    ok(1, "checking ".$file);
    TestUtils::verify_tt($file);
}

done_testing();
