use warnings;
use strict;
use Test::More 0.96;

use Thruk::Config 'noautoload';
use Thruk::Utils::IO ();

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
    { name => 'agents',       'tarball' => 'https://github.com/sni/thruk-plugin-agents/archive/refs/heads/master.tar.gz' },
    { name => 'editor',       'tarball' => 'https://github.com/sni/thruk-plugin-editor/archive/refs/heads/master.tar.gz' },
    { name => 'omd',          'tarball' => 'https://github.com/sni/thruk-plugin-omd/archive/refs/heads/master.tar.gz' },
    { name => 'pansnaps',     'tarball' => 'https://github.com/ConSol/thruk-plugin-pansnaps/archive/refs/heads/master.tar.gz' },
    { name => 'woshsh',       'tarball' => 'https://github.com/sni/thruk-plugin-woshsh/archive/refs/heads/master.tar.gz' },
    { name => 'node-control', 'tarball' => 'https://github.com/sni/thruk-plugin-node-control/archive/refs/heads/master.tar.gz' },
];
my $filter = $ARGV[0];
my $extra_tests = [
  't/081-modules.t',
  't/083-xss.t',
  't/085-json_xs.t',
  't/087-trailing_whitespace.t',
  't/090-io.t',
  't/092-backticks.t',
  't/088-remove_after.t',
  't/092-clean_debug.t',
  't/092-private_subs.t',
  't/092-stash-config.t',
  't/092-thruk-view-json.t',
  't/092-todo.t',
  't/094-plugin-root-path.t',
  't/094-template_encoding.t',
  't/099-Perl-Critic.t',
  't/900-javascript_syntax.t',
  glob('t/data/800-plugins/*.t'),
];

TestUtils::test_command({
    cmd     => $BIN.' plugin search report -f',
    like    => ['/reports2/'],
    exit    => 0,
});

my $failed = {};
for my $p (@{$plugins}) {
    next if($filter && $p->{'name'} ne $filter);

    # install plugin or use existing if core plugin
    my $use_existing = 0;
    if(-e 'plugins/plugins-enabled/'.$p->{'name'}) {
        $use_existing = 1;
    }
    elsif(-e 'plugins/plugins-available/'.$p->{'name'}) {
        TestUtils::test_command({
            cmd     => $BIN.' plugin enable '.$p->{'name'},
            like    => ['/enabled plugin/' ],
            exit    => 0,
        });
        $use_existing = 2;
        if(-d 'plugins/plugins-available/'.$p->{'name'}.'/.git') {
            # run git pull if clean workspace
            my($rc, $out) = Thruk::Utils::IO::cmd('cd plugins/plugins-available/'.$p->{'name'}.' && git status');
            if($out =~ m/\Qworking tree clean\E/mx) {
                my($rc, $out) = Thruk::Utils::IO::cmd('cd plugins/plugins-available/'.$p->{'name'}.' && git pull');
                is($rc, 0, 'git pull exited with rc 0');
            } else {
                fail("skipping git pull, workspace not clean");
                diag($out);
            }
        }
    } else {
        TestUtils::test_command({
            cmd     => $BIN.' plugin install '.$p->{'name'}.( $p->{'tarball'} ? ' '.$p->{'tarball'} : ''),
            like    => ['/Installed/',
                        '/successfully/'
                        ],
            exit    => 0,
        });
    }

    # enable additional test config
    if(-e 'plugins/plugins-enabled/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf') {
        mkdir('thruk_local.d');
        symlink('../plugins/plugins-enabled/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf', 'thruk_local.d/test-'.$p->{'name'}.'.conf');
    }

    # run plugin test files
    TestUtils::clear();
    for my $testfile (glob("plugins/plugins-enabled/".$p->{'name'}."/t/*.t"), @{$extra_tests}) {
        next if($p->{'skip_tests'} && $testfile =~ $p->{'skip_tests'});
        my $testsource = Thruk::Utils::IO::read($testfile);
        Thruk::Config::set_config_env();
        my $rc = subtest $testfile => sub {
            # required for ex.: t/092-todo.t
            local @ARGV = (sprintf("plugins/plugins-available/%s", $p->{'name'}));
            $testsource =~ s/^\Quse warnings;\E//gmx;
            no warnings qw(redefine);
            eval("#line 1 $testfile\n".$testsource);
        };
        $failed->{$p->{'name'}}->{$testfile} = 1 unless $rc;
    }

    # remove additional test config again
    if(-e 'plugins/plugins-enabled/'.$p->{'name'}.'/t/data/'.$p->{'name'}.'.conf') {
        unlink('thruk_local.d/test-'.$p->{'name'}.'.conf');
    }

    # uninstall plugin
    if(!$use_existing) {
        TestUtils::test_command({
            cmd     => $BIN.' plugin remove '.$p->{'name'},
            like    => ['/Removed plugin/',
                        '/successfully/'
                        ],
            exit    => 0,
        });
    }
    elsif($use_existing == 2) {
        TestUtils::test_command({
            cmd     => $BIN.' plugin disable '.$p->{'name'},
            like    => ['/disabled plugin/' ],
            exit    => 0,
        });
    }
}

# show summary
for my $p (sort keys %{$failed}) {
    for my $file (sort keys %{$failed->{$p}}) {
        fail("failed plugin: $p at test $file");
    }
}

done_testing();
