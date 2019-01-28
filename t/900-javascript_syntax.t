use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;

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
                    plugins/plugins-available/panorama/root/js/*.js
                    ');
for my $file (@jsfiles) {
    ok(1, "checking ".$file);
    next if $file =~ m/all_in_one/mxi;
    TestUtils::verify_js($file);
}

my @tplfiles = split(/\n/, `find templates plugins/plugins-available/*/templates/. themes/themes-available/*/templates -name \*.tt`);
for my $file (@tplfiles) {
    ok(1, "checking ".$file);
    TestUtils::verify_tt($file);
}

use_ok("Thruk::Config");
my $config = Thruk::Config::get_config();

my $files = ['root/thruk/startup.html', 'plugins/plugins-available/mobile/templates/mobile.tt'];
for my $file (@{$files}) {
    my $content = read_file($file);
    my @jquery = grep/jquery-\d+.*\.js$/, @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}};
    is(scalar @jquery, 1, 'found jquery in config');
    like($content, qr/$jquery[0]/, 'found jquery in '.$file);
}


done_testing();
