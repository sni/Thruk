use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Temp qw/ tempfile /;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = './script/naglint';
if(defined $ENV{'THRUK_BIN'}) {
    $BIN = $ENV{'THRUK_BIN'};
    $BIN =~ s/thruk$/naglint/mx;
}

ok(-f $BIN, "naglint exists: $BIN") or BAIL_OUT("$0: no binary found");

# create test file
my($fh, $filename) = tempfile(TEMPLATE => 'tempXXXXX', SUFFIX => '.cfg');
ok((defined $filename and $filename ne ''), "created testfile: ".$filename);

print $fh <<EOT;
# test
define contactgroup {
  alias                          test_contacts_alias
contactgroup_name              test_contact
# blah
  members      test_contact, asdasdas,    asd
}
EOT
close($fh);


# stdin
TestUtils::test_command({
    cmd  => '/bin/cat '.$filename.' | '.$BIN.' -v',
    like => ['/define contactgroup/'],
});

# from args
TestUtils::test_command({
    cmd     => $BIN.' -i '.$filename,
    like    => ['/^$/'],
    errlike => ['/^wrote /'],
});

ok(unlink($filename), "unlinked test file");

done_testing();
