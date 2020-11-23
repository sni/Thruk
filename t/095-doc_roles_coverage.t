use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;

use lib('t');
use TestUtils;

# ensure that all config options are well documented
my $src = "docs/documentation/cgi-cfg.asciidoc";

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# read our config and enable everything
my $c     = TestUtils::get_c();
my $docs  = get_docs();
my $roles = $Thruk::Authentication::User::possible_roles;
my $hash  = Thruk::Config::array2hash($roles);
for my $role (@{$roles}) {
    is($docs->{$role}, 1, "documentation entry for: $role");
}

for my $role (`grep ^authorized_for_ cgi.cfg`) {
    $role =~ s/=.*$//gmx;
    chomp($role);
    is($hash->{$role}, $role, "Thruk::Authentication::User::possible_roles entry for: $role");
}

done_testing();


sub get_docs {
    my $doc_roles;
    open(my $ph, '<', $src) or die("cannot open ".$src.": ".$!);
    while(<$ph>) {
    my $line = $_;
        if($line =~ m/^===\s+(.*)$/) {
            my $entry = $1;
            next unless $entry =~ m/^authorized_for_/gmx;
            $doc_roles->{$entry} = 1;
        }
    }
    close($ph);
    return $doc_roles;
}
