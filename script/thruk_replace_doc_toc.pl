#!/usr/bin/perl

use warnings;
use strict;

my $file = $ARGV[0] || die("usage: $0 <file>");

my $toc='<div id="toc"><div id="toctitle">Table of Contents</div>'."\n";

my $cont = '';
open(my $fh, '<', $file);
while(my $line = <$fh>) {
    $cont .= $line;
    if($line =~ m/<h(\d+)\ id="([^"]+)">([^<]+)</mx) {
        my($lvl,$link,$name) = ($1,$2,$3);
        if($lvl <= 3) {
            $lvl--;
            $toc .= "<div class='toclevel".$lvl."'><a href='#".$link."'>".$name."</a></div>\n";
        }
    }
}
$toc .= "</div>\n";
close($fh);

$cont =~ s|<script\ type="text/javascript">.*?</script>||sm;
$cont =~ s|<div\ id=\"toc\">\s*<div\ id=\"toctitle\">Table\ of\ Contents</div>.*?</div>|$toc|sm;

open($fh, '>', $file);
print $fh $cont;
close($fh);
