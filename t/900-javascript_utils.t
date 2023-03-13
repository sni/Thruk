use warnings;
use strict;
use File::Temp qw/tempfile/;
use Log::Log4perl qw(:easy);
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
eval "use WWW::Mechanize::Chrome";
plan skip_all => 'WWW::Mechanize::Chrome required' if $@;

eval "use Protocol::WebSocket::Frame";
plan skip_all => 'Protocol::WebSocket::Frame required' if $@;
# cannot eval larger files otherwise
$Protocol::WebSocket::Frame::MAX_PAYLOAD_SIZE = 0;
ok($Protocol::WebSocket::Frame::MAX_PAYLOAD_SIZE == 0, "payload size is reduced now");

my($chrome, $diagnosis) = WWW::Mechanize::Chrome->find_executable();
plan skip_all => 'WWW::Mechanize::Chrome requires chrome: '.$diagnosis if !$chrome;

Log::Log4perl->easy_init($ERROR);
my $mech = WWW::Mechanize::Chrome->new(
    headless         => 1,
    separate_session => 1,
    tab              => 'current',
    launch_arg       => ["--password-store=basic", "--remote-allow-origins=*" ],
);
$mech->get_local($0);
my $console = $mech->add_listener('Runtime.consoleAPICalled', sub {
  return if(scalar @_ == 0);
  diag(join ", ",
      map { $_->{value} // $_->{description} }
      @{ $_[0]->{params}->{args} }
  );
});

js_ok("function diag(txt) { console.log(txt); }", 'added diag function');

#################################################
js_ok("url_prefix='/'", 'set url prefix');
my @jsfiles = glob('root/thruk/javascript/thruk-*.js');
ok($jsfiles[0], $jsfiles[0]);
js_eval_ok($jsfiles[0]);

#################################################
# tests from javascript_tests file
my @functions = Thruk::Utils::IO::read('t/data/javascript_tests.js') =~ m/^\s*function\s+(test\w+)/gmx;
ok(scalar @functions > 0, "read ".(scalar @functions)." functions from javascript_test.js");
js_eval_ok('t/data/javascript_tests.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

#################################################
# some more functions
_eval_extracted_js('templates/login.tt');
@functions = Thruk::Utils::IO::read_as_list('t/data/javascript_tests_login_tt.js') =~ m/^\s*function\s+(test\w+)/gmx;
js_eval_ok('t/data/javascript_tests_login_tt.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

#################################################
$mech->close();
done_testing();


#################################################
# SUBS
#################################################
sub _eval_extracted_js {
    my($file) = @_;
    ok(1, "extracting from ".$file);
    my $cont = Thruk::Utils::IO::read($file);
    my @codes = $cont =~ m/<script[^>]*text\/javascript.*?>(.*?)<\/script>/gsmxi;
    my $jscode = join("\n", @codes);
    $jscode =~ s/\[\%\s*product_prefix\s*\%\]/thruk/gmx;
    my($fh, $filename) = tempfile();
    print $fh $jscode;
    close($fh);
    js_eval_ok($filename);
    unlink($filename);
    return;
}

#################################################
sub js_ok {
  my($src, $msg) = @_;
  $mech->eval_in_page($src);
  my @err = $mech->js_errors();
  for my $e (@err) {
    _diag_js_error($e);
  }
  $mech->clear_js_errors();
  ok(scalar @err == 0, $msg);
}

#################################################
sub js_eval_ok {
  my($file) = @_;
  my $src = Thruk::Utils::IO::read($file);
  js_ok($src, $file);
}

#################################################
sub js_is {
  my($src, $expect, $msg) = @_;
  my($val, $type) = $mech->eval_in_page($src);
  my @err = $mech->js_errors();
  if(scalar @err != 0) {
    fail("failed to evaluate: ".$src);
  }
  for my $e (@err) {
    _diag_js_error($e);
  }
  $mech->clear_js_errors();
  is($val, $expect, $msg);
}

#################################################
sub _diag_js_error {
  my($e) = @_;
  if($e->{'message'}) {
    diag($e->{'message'});
    return;
  }
  if($e->{'exceptionDetails'}) {
    diag(sprintf("[%s:%d:%d] %s: %s",
      $e->{'exceptionDetails'}->{url},
      $e->{'exceptionDetails'}->{lineNumber},
      $e->{'exceptionDetails'}->{columnNumber},
      $e->{'exceptionDetails'}->{text},
      $e->{'exceptionDetails'}->{exception}->{description},
    ));
    return;
  }
}
