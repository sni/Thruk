use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Test skipped, $ENV{NO_PATCH_TEST} was set' if $ENV{NO_PATCH_TEST};
plan tests => 28;

alarm(120);

# create a tmp directory
mkdir('tmppatches') or die("cannot create tmp folder: $!");

END {
    `rm -rf tmppatches`;
}

my $rsync = 'rsync -av --exclude=".git" --exclude="tmppatches/" --exclude="tmp" --exclude="blib" --exclude="var" --exclude="themes" --exclude="plugins" --exclude="logs" --exclude="docs" --exclude="debian" . tmppatches/.';
`$rsync`;
is($?, 0, 'rsync ok: '.$rsync);

chdir('tmppatches') or die("chdir failed: $!");

my $precmds = {
  'support/0003-thruk-scripts.patch'      => 'cp script/thruk script/naglint .',
  'support/0004-thruk_data_scripts.patch' => 'cp script/thruk_auth .',
  'support/0006-logrotate.patch'          => 'cp support/thruk.logrotate thruk-base',
  'support/0007-fcgish.patch'             => 'cp support/fcgid_env.sh .',
  'support/0031-naemon-init.patch'        => 'cp support/thruk.init thruk',
  'support/0032-naemon-httpd.patch'       => 'cp support/apache_fcgid.conf thruk.conf',
  'support/0035-naemon-cgicfg.patch'      => 'cd .. && cp cgi.cfg cgi.cfg.testbak && git checkout cgi.cfg; cp cgi.cfg tmppatches/ && mv cgi.cfg.testbak cgi.cfg',
  'support/0036-naemon-htpasswd.patch'    => 'cp support/htpasswd .',
  'support/0003-thruk-check.patch'        => 'cp script/check_thruk .',
};

my @patches = glob('support/*.patch');
for my $p (@patches) {
    if(defined $precmds->{$p}) {
        my $cmd = $precmds->{$p};
        ok(1, $cmd);
        my $out = `$cmd 2>&1`;
        is($?, 0, 'precmd succeeded') or diag("%> ".$cmd."\n\n".$out);
    }
    my $cmd = 'patch -p1 --fuzz=0 -s < '.$p.' 2>&1';
    ok(1, $cmd);
    my $out = `$cmd`;
    is($?, 0, 'patch succeeded') or diag("%> ".$cmd."\n\n".$out);
}

chdir('..') or die("chdir failed: $!");
`rm -rf tmppatches`;
is($?, 0, 'cleanup succeeded');
