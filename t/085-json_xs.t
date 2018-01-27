use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

open(my $ph, '-|', 'bash -c "find ./lib ./t ./plugins/plugins-available/*/{lib,t} -type f" 2>&1') or die('find failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);
    check_json_xs($line);
}
done_testing();


sub check_json_xs {
    my($file) = @_;
    ok($file, $file);
    my $out = `grep -n JSON::XS "$file" | grep -v Cpanel::JSON::XS`;
    if($out) {
        fail($file." uses JSON::XS instead of Cpanel::JSON::XS");
    }
    return;
}
