use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Test skipped, $ENV{NO_PATCH_TEST} was set' if $ENV{NO_PATCH_TEST};
plan tests => 8;

# create a tmp directory
mkdir('tmppatches') or die("cannot create tmp folder: $!");

my $rsync = 'rsync -av --exclude=".git" --exclude="tmppatches/" --exclude="tmp" --exclude="blib" --exclude="var" . tmppatches/.';
`$rsync`;
is($?, 0, 'rsync ok: '.$rsync);

chdir('tmppatches') or die("chdir failed: $!");


my @patches = glob('support/*.patch');
for my $p (@patches) {
    my $cmd = 'patch -p1 --fuzz=0 -s < '.$p.' 2>&1';
    ok(1, $cmd);
    my $out = `$cmd`;
    is($?, 0, 'patch succeeded') or diag("%> ".$cmd."\n\n".$out);
}

chdir('..') or die("chdir failed: $!");
`rm -rf tmppatches`;
is($?, 0, 'cleanup succeeded');
