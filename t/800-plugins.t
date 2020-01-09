use strict;
use warnings;
use Test::More;

BEGIN {
  plan skip_all => 'local test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
  plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local';

my $plugins = [
    { name => 'editor' },
    { name => 'omd' },
    { name => 'pansnaps' },
    { name => 'status-dashboard' },
    { name => 'woshsh',          travis => 0 }, # somehow broken on travis
];
my $filter = $ARGV[0];
my $extra_tests = [
  't/083-xss.t',
  't/088-remove_after.t',
  't/092-todo.t',
  't/094-template_encoding.t',
  't/900-javascript_syntax.t',
];

for my $p (@{$plugins}) {
    next if($filter && $p->{'name'} ne $filter);
    next if(defined $p->{'travis'} && $ENV{'TEST_TRAVIS'} && !$p->{'travis'});
    my $use_existing = 0;
    if(-e 'plugins/plugins-available/'.$p->{'name'}) {
      $use_existing = 1;
    } else {
      TestUtils::test_command({
          cmd     => $BIN.' plugin install '.$p->{'name'},
          like    => ['/Installed/',
                      '/successfully/'
                    ],
          exit    => 0,
      });
    }

    if(-e 'plugins/plugins-available/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf') {
      symlink('../plugins/plugins-available/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf', 'thruk_local.d/test-'.$p->{'name'}.'.conf');
    }
    for my $testfile (glob("plugins/plugins-available/".$p->{'name'}."/t/*.t"), @{$extra_tests}) {
        TestUtils::test_command({
            cmd     => sprintf("%s %s plugins/plugins-available/%s", $^X, $testfile, $p->{'name'}),
            like    => ['/ok|\#\ SKIP/'],
            unlike  => ['/not ok/'],
            exit    => 0,
          });
    }
    if(-e 'plugins/plugins-available/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf') {
      unlink('thruk_local.d/test-'.$p->{'name'}.'.conf');
    }

    if(!$use_existing) {
      TestUtils::test_command({
          cmd     => $BIN.' plugin remove '.$p->{'name'},
          like    => ['/Removed plugin/',
                      '/successfully/'
                    ],
          exit    => 0,
      });
    }
}

done_testing();
