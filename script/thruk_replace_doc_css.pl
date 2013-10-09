#!/usr/bin/env perl

use warnings;
use strict;

my $file = $ARGV[0] || die("usage: $0 <file> <css>");
my $css  = $ARGV[1] || die("usage: $0 <file> <css>");

my $cont  = read_file($file);
my $style = read_file($css);

$cont =~ s|<style type="text/css">.*?</style>|<style type="text/css">$style</style>|sm;

open(my $fh, '>', $file);
print $fh $cont;
close($fh);


sub read_file {
    my($file) = @_;
    my $cont = '';
    open(my $fh, '<', $file);
    while(my $line = <$fh>) {
        $cont .= $line;
    }
    close($fh);
    return $cont;
}
