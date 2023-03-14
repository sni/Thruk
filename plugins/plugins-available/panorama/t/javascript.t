use warnings;
use strict;
use File::Temp qw/tempfile/;
use Test::More;

use Thruk ();

use lib('t');
use TestUtils qw/:js/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
$ENV{'THRUK_QUIET'} = 1;

my $mech = js_init();

#################################################
# load jquery js source
my @jsfiles = glob('root/thruk/vendor/jquery-*.min.js');
ok($jsfiles[0], "found jquery source");
js_eval_ok($jsfiles[0]) or BAIL_OUT("failed to load jquery");

#################################################
# load ext js source
js_ok("document.getElementsByTagName('body')[0].innerHTML += '<script src=\"\"></script>';", "add script tag");
@jsfiles = glob('root/thruk/vendor/extjs-*/ext-all-debug.js');
ok($jsfiles[0], "found extjs source");
js_eval_ok($jsfiles[0]) or BAIL_OUT("failed to load extjs");

#################################################
# read 3rd party js files
my $config = Thruk::config();
for my $file (@{$config->{'all_in_one_javascript_panorama'}}) {
    my $testfile = $file;
    if($testfile =~ m/^plugins\//mx) {
        $testfile =~ s|plugins/panorama/|plugins/plugins-available/panorama/root/|gmx;
    } else {
        $testfile = 'root/thruk/'.$testfile;
    }
    next if $testfile =~ m|OpenLayers|mx;
    next if $testfile =~ m|jquery|mxi;
    js_eval_ok($testfile) or BAIL_OUT("failed to load ".$testfile);
}

#################################################
# extract global vars
my $tst = TestUtils::test_page(
    'url'           => '/thruk/cgi-bin/panorama.cgi',
    'like'          => 'thruk_version.*=',
);
$tst->{'content'} =~ m|<\!\-\-(.*?)\-\->|smx;
my($fh, $filename) = tempfile();
print $fh $1;
close($fh);
js_eval_ok($filename) && unlink($filename);

#################################################
# read static js files
use_ok('Thruk::Utils::Panorama');
for my $file (@{Thruk::Utils::Panorama::get_static_panorama_files($config)}) {
    $file =~ s|plugins/panorama/|plugins/plugins-available/panorama/root/|gmx;
    ok($file, $file);
    js_eval_ok($file) or BAIL_OUT("failed to load ".$file);
    my $content = Thruk::Utils::IO::read($file);
    ok($content =~ m/\n$/s, "file $file must end with a newline");
}

#################################################
# set start page
$tst = TestUtils::test_page(
    'url'           => '/thruk/cgi-bin/panorama.cgi',
    'like'          => 'thruk_version.*=',
);
$mech->update_html($tst->{'content'});
($fh, $filename) = tempfile();
print $fh $tst->{'content'};
close($fh);
js_eval_extracted($filename);

#################################################
# add dynamic js
$tst = TestUtils::test_page(
    'url'           => '/thruk/cgi-bin/panorama.cgi?js=1',
    'like'          => 'BLANK_IMAGE_URL',
    'content_type'  => 'text/javascript; charset=utf-8',
);
($fh, $filename) = tempfile();
print $fh $tst->{'content'};
close($fh);
js_eval_ok($filename) && unlink($filename);

#################################################
# tests from javascript_tests file
my @functions = Thruk::Utils::IO::read('t/xt/panorama/javascript_tests.js') =~ m/^\s*function\s+(test\w+)/gmx;
ok(scalar @functions > 0, "read ".(scalar @functions)." functions from javascript_test.js");
js_eval_ok('t/xt/panorama/javascript_tests.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

js_deinit();
done_testing();
