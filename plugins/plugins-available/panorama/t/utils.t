use warnings;
use strict;
use Data::Dumper;
use Test::More;

use utf8;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::Panorama");

my $testfolder = $0;
$testfolder =~ s|/[^/]+$||gmx;

####################################################
my $c = TestUtils::get_c();
my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, 1, undef, $testfolder."/data/utf8.tab");
isnt($dashboard, undef, "dashboard loaded");
is($dashboard->{'panlet_2'}->{'xdata'}->{'label'}->{'labeltext'}, 'codelabelöäüß€', 'label read from code part');
is($dashboard->{'panlet_1'}->{'xdata'}->{'label'}->{'labeltext'}, 'datalabelöäüß€', 'label read from __data__ part');

####################################################
done_testing();
