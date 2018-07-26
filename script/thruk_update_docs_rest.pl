#!/usr/bin/env perl

use warnings;
use strict;
use File::Slurp qw/read_file/;

use Thruk::Utils::CLI;
use Thruk::Controller::rest_v1;

my $output_file = "docs/documentation/rest.asciidoc";

my($paths, $keys, $docs) = Thruk::Controller::rest_v1::get_rest_paths();

`cp t/scenarios/cli_api/omd/1.tbp bp/9999.tbp`;
`cp t/scenarios/cli_api/omd/1.rpt var/reports/9999.rpt`;
`cp t/scenarios/cli_api/omd/1.tab panorama/9999.tab`;

my $content = read_file($output_file);
$content =~ s/^(\QSee examples and detailed description for all available rest api urls\E:\n).*$/$1\n\n/gsmx;
my $c = Thruk::Utils::CLI->new()->get_c();
Thruk::Utils::set_user($c, 'thrukadmin');
$c->stash->{'is_admin'} = 1;

for my $url (sort keys %{$paths}) {
    for my $proto (sort keys %{$paths->{$url}}) {
        $content .= "=== $proto $url\n\n";
        my $doc   = $docs->{$url}->{$proto} ? join("\n", @{$docs->{$url}->{$proto}})."\n\n" : '';
        $content .= $doc;

        if(!$keys->{$url}->{$proto}) {
            $keys->{$url}->{$proto} = _fetch_keys($proto, $url, $doc);
        }
        if($keys->{$url}->{$proto}) {
            $content .= '[options="header"]'."\n";
            $content .= "|===========================================\n";
            $content .= sprintf("|%-33s | %s\n", 'Attribute', 'Description');
            for my $doc (@{$keys->{$url}->{$proto}}) {
                $content .= sprintf("|%-33s | %s\n", $doc->[0], $doc->[1]);
            }
            $content .= "|===========================================\n\n\n";
        }
    }
}

open(my $fh, '>', $output_file) or die("cannot write to ".$output_file.': '.$@);
print $fh $content;
close($fh);

unlink('bp/9999.tbp');
unlink('var/reports/9999.rpt');
unlink('panorama/9999.tab');

exit 0;

################################################################################
sub _fetch_keys {
    my($proto, $url, $doc) = @_;

    return if $proto ne 'GET';
    return if $doc =~ m/alias|https?:/mx;
    return if $url eq '/thruk/reports/<nr>/report';

    my $keys = [];
    $c->{'rendered'} = 0;
    $c->req->parameters->{'limit'} = 1;
    print STDERR "fetching keys for ".$url."\n";
    my $tst_url = $url;
    $tst_url =~ s|<nr>|9999|gmx;
    my $data = Thruk::Controller::rest_v1::_process_rest_request($c, $tst_url);
    if($data && ref($data) eq 'ARRAY' && $data->[0] && ref($data->[0]) eq 'HASH') {
        for my $k (sort keys %{$data->[0]}) {
            push @{$keys}, [$k, ""];
        }
    }
    elsif($data && ref($data) eq 'HASH' && !$data->{'code'}) {
        for my $k (sort keys %{$data}) {
            push @{$keys}, [$k, ""];
        }
    }
    else {
        print STDERR "ERROR: got no usable data\n";
        return;
    }
    return $keys;
}
