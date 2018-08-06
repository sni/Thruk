use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local tests only'  if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 6;
}

$ENV{'TEST_MODE'} = 1;
my $cmds = [
    './script/thruk_update_docs_rest.pl',
    'diff -bNuh docs/documentation/rest.asciidoc.tst docs/documentation/rest.asciidoc',
    'diff -bNuh docs/documentation/rest_commands.asciidoc.tst docs/documentation/rest_commands.asciidoc',
];
for my $cmd (@{$cmds}) {
    open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
    ok($ph, $cmd.' started');
    my $errors = "";
    while(<$ph>) {
        chomp(my $line = $_);
        next if $line =~ m/fetching\ keys\ for/mx;
        $errors .= $line."\n";
    }
    if($errors) {
        fail($errors);
    } else {
        ok(1, "no errors");
    }
}

unlink('docs/documentation/rest.asciidoc.tst');
unlink('docs/documentation/rest_commands.asciidoc.tst');
