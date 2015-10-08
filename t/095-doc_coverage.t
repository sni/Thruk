use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;

# ensure that all config options are well documented
my $src = "docs/documentation/configuration.asciidoc";

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# read our config and enable everything
use_ok("Thruk::Config");
my $conf = get_thruk_conf();
my $docs = get_docs();
for my $key (keys %{$conf}) {
    next if $key eq 'Component';
    next if $key =~ /^\d+$/mx;
    is($docs->{$key}, 1, "documentation entry for: $key");
}
for my $key (keys %{$conf->{'Component'}}) {
    is($docs->{"Component $key"}, 1, "documentation entry for: $key");
}

done_testing();


sub get_thruk_conf {
    my @conf_rows;
    open(my $ph, '<', 'thruk.conf') or die("cannot open thruk.conf");
    my $amend = 0;
    while(<$ph>) {
        my $line = $_;
        next if !$amend && $line !~ m/^\#?\s*([\w_\-]+\s*=\s+|<)/mx;
        $amend = $line =~ m/\\$/mx ? 1 : 0;
        $line =~ s/^\s*#//g;
        push(@conf_rows, $line);
    }
    close($ph);

    my $conf = {};
    Thruk::Config::_parse_rows("tmp thruk config", \@conf_rows, $conf);
    return $conf;
}


sub get_docs {
    my $doc_header;
    open(my $ph, '<', $src) or die("cannot open ".$src.": ".$!);
    while(<$ph>) {
    my $line = $_;
        if($line =~ m/^===\s+(.*)$/) {
            $doc_header->{$1} = 1;
        }
        if($line =~ m/^==\s+(.*)$/) {
            $doc_header->{$1} = 1;
        }
    }
    close($ph);
    return $doc_header;
}
