use warnings;
use strict;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

#################################################
my $filter = $ARGV[0];
my @jsfiles = glob('root/thruk/javascript/thruk-*.js
                    plugins/plugins-available/*/root/*.js
                    plugins/plugins-available/panorama/templates/panorama_js.tt
                    plugins/plugins-available/panorama/templates/_panorama_js_*.tt
                    plugins/plugins-available/panorama/root/js/*.js
                    ');
for my $file (@jsfiles) {
    next if($filter && $file !~ m%$filter%mx);
    ok(1, "checking ".$file);
    TestUtils::verify_js($file);
}

my @tplfiles = split(/\n/, `find templates/. plugins/plugins-available/*/templates/. -type f`);
for my $file (@tplfiles) {
    next if($filter && $file !~ m%$filter%mx);
    ok(1, "checking ".$file);
    TestUtils::verify_tt($file);
}

use_ok("Thruk::Config");
my $config = Thruk::Config::get_config();

done_testing();
