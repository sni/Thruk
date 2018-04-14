use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use File::Slurp qw/read_file/;

use lib('t');
require TestUtils;
import TestUtils;

BEGIN {
    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
    eval "use Test::JavaScript";
    plan skip_all => 'Test::JavaScript required' if $@;
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
}

#################################################
# create minimal window object
js_ok("
var window = {
  navigator: {userAgent:'test'},
  document:  {
    createElement:function(){
        return({
            getElementsByTagName:function(){ return([])},
            appendChild:function(){},
            setAttribute:function(){}
        });
    },
    createDocumentFragment:function(){return({})},
    createComment:function(){},
    getElementById:function(){},
    getElementsByTagName:function(t){
        if(t == 'html') {return([{}])};
        if(t == 'script') {return([{src:'ext-all.js'}])};
        return([]);
    },
    documentElement:{
        style: {},
        insertBefore:function(){},
        removeChild:function(){}
    },
    addEventListener: function(){},
    removeEventListener: function(){}
  },
  DOMParser: function(){ return({
    parseFromString: function(){ return({
            getElementsByTagName:function(){ return([])},
        })
    }
  })},
  location: {},
  addEventListener:    function(){},
  removeEventListener: function(){},
  setTimeout:          function(){},
  clearTimeout:        function(){},
  setInterva:          function(){},
  clearInterval:       function(){}
};
var navigator  = window.navigator;
var document   = window.document;
DOMParser      = window.DOMParser;
setTimeout     = function(){};
clearTimeout   = function(){};
setInterval    = function(){};
clearInterval  = function(){};
XMLHttpRequest = function(){ return({
    open: function(){},
    send: function(){}
})};
self           = {};
top            = {};
url_prefix     = '/thruk';
thruk_debug_js = 1;
thruk_onerror  = function() {};
", 'set window object') or BAIL_OUT("failed to create window object");
my @jsfiles = glob('plugins/plugins-available/panorama/root/extjs-*/ext-all-debug.js');
ok($jsfiles[0], $jsfiles[0]);
js_eval_ok($jsfiles[0]) or BAIL_OUT("failed to load extjs");

#################################################
# read 3rd party js files
my $config = Thruk::config();
for my $file (@{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript_panorama'}}) {
    if($file =~ m/^plugins\//mx) {
        $file =~ s|plugins/panorama/|plugins/plugins-available/panorama/root/|gmx;
    } else {
        $file = 'root/thruk/'.$file;
    }
    next if $file =~ m|OpenLayers|mx;
    ok($file, $file);
    js_eval_ok($file) or BAIL_OUT("failed to load ".$file);
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
    my $content = read_file($file);
    ok($content =~ m/\n$/s, "file $file must end with a newline");
}
#################################################
# add dynamic js
$tst = TestUtils::test_page(
    'url'           => '/thruk/cgi-bin/panorama.cgi?js=1',
    'like'          => 'BLANK_IMAGE_URL',
    'content_type'  => 'text/javascript; charset=UTF-8',
);
($fh, $filename) = tempfile();
print $fh $tst->{'content'};
close($fh);
js_eval_ok($filename) && unlink($filename);

#################################################
# tests from javascript_tests file
my @functions = read_file('t/xt/panorama/javascript_tests.js') =~ m/^\s*function\s+(test\w+)/gmx;
js_eval_ok('t/xt/panorama/javascript_tests.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

done_testing();
