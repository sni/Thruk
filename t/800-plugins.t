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
$BIN    = $BIN.' --local' unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

my $plugins = [
    { name => 'editor' },
    { name => 'omd' },
    { name => 'pansnaps' },
    { name => 'status-dashboard' },
];
my $filter = $ARGV[0];

for my $p (@{$plugins}) {
    next if $filter and $p->{'name'} ne $filter;
    TestUtils::test_command({
        cmd     => $BIN.' plugin install '.$p->{'name'},
        like    => ['/Installed/',
                    '/successfully/'
                  ],
        exit    => 0,
    });

    if(-e 'plugins/plugins-available/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf') {
      symlink('../plugins/plugins-available/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf', 'thruk_local.d/test-'.$p->{'name'}.'.conf');
    }
    for my $testfile (glob("plugins/plugins-available/".$p->{'name'}."/t/*.t")) {
        TestUtils::test_command({
            cmd     => $^X.' '.$testfile,
            like    => ['/ok/'],
            unlike  => ['/not ok/'],
            exit    => 0,
          });
    }
    if(-e 'plugins/plugins-available/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf') {
      unlink('thruk_local.d/test-'.$p->{'name'}.'.conf');
    }

    TestUtils::test_command({
        cmd     => $BIN.' plugin remove '.$p->{'name'},
        like    => ['/Removed plugin/',
                    '/successfully/'
                  ],
        exit    => 0,
    });
}

done_testing();
