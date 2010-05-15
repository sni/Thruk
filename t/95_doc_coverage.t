use strict;
use warnings;
use Test::More;
use Config::General;
use Data::Dumper;

# ensure that all config options are well documented

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# read our config and enable everything
my $conf = get_thruk_conf();
my $docs = get_docs();
for my $key (keys %{$conf}) {
    next if $key eq 'Component';
    is($docs->{$key}, 1, $key);
}
for my $key (keys %{$conf->{'Component'}}) {
    is($docs->{"Component $key"}, 1, "documentation entry for: $key");
}

done_testing();


sub get_thruk_conf {
    my $conf_string = "";
    open(my $ph, '<', 'thruk.conf') or die("cannot open thruk.conf");
    while(<$ph>) {
    my $line = $_;
        next if $line !~ m/(=\s+|<)/mx;
        $line =~ s/^\s*#//g;
        $conf_string .= $line;
    }
    close($ph);

    $conf = new Config::General(-String => $conf_string);
    my %config = $conf->getall;
    return \%config;
}


sub get_docs {
    my $doc_header;
    open(my $ph, '<', 'docs/THRUK_MANUAL.txt') or die("cannot open docs/THRUK_MANUAL.txt");
    while(<$ph>) {
    my $line = $_;
        if($line =~ m/^====\s+(.*)$/) {
            $doc_header->{$1} = 1;
        }
        if($line =~ m/^===\s+(.*)$/) {
            $doc_header->{$1} = 1;
        }
    }
    close($ph);
    return $doc_header;
}
