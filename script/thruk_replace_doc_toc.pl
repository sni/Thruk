#!/usr/bin/env perl

use warnings;
use strict;

my $file = $ARGV[0] || die("usage: $0 <file>");

my $toc='<div id="toc"><div id="toctitle">Table of Contents</div>'."\n";

my $subtocs      = {};
my $lastsection  = '';
my $lastsection2 = '';
my $cont = '';
open(my $fh, '<', $file);
while(my $line = <$fh>) {
    $cont .= $line;
    if($line =~ m/<h(\d+)\ id="([^"]+)">([^<]+)</mx) {
        my($lvl,$link,$name) = ($1,$2,$3);
        my $tocitem = "<div class='toclevel".$lvl."'><a href='#".$link."'>".$name."</a></div>\n";

        # build top short toc
        if($lvl <= 3) {
            $lvl--;
            $toc .= $tocitem;
        }

        if($lvl == 1) {
            $lastsection = $name;
        }
        if($lvl == 2) {
            $lastsection2 = $name;
        }
        if($lvl >= 2 && $lvl <= 4) {
            $subtocs->{$lastsection} = [] unless defined $subtocs->{$lastsection};
            push @{$subtocs->{$lastsection}}, $tocitem;
        }
        if($lvl >= 3 && $lvl <= 4) {
            $subtocs->{$lastsection2} = [] unless defined $subtocs->{$lastsection2};
            push @{$subtocs->{$lastsection2}}, $tocitem;
        }
    }
}
$toc .= "</div>\n";
close($fh);

my $newcont = "";
for my $line (split/\n/, $cont) {
    if($line =~ m/<h(\d+)\ id="([^"]+)">([^<]+)</mx) {
        my($lvl,$link,$name) = ($1,$2,$3);
        $lastsection = $name;
    }
    if($line =~ m/%subtoc%/mx) {
        die("no such section: ".$lastsection) unless defined $subtocs->{$lastsection};
        $line = '<div class="subtoc"><div class="toctitle">Table of Contents</div>'.join("\n", @{$subtocs->{$lastsection}}).'</div>';
    }
    if($line =~ m/%subtocnotitle%/mx) {
        die("no such section: ".$lastsection) unless defined $subtocs->{$lastsection};
        $line = '<div class="subtoc">'.join("\n", @{$subtocs->{$lastsection}}).'</div>';
    }
    $newcont .= $line."\n";
}

$newcont =~ s|<script\ type="text/javascript">.*?</script>||sm;
$newcont =~ s|<div\ id=\"toc\">\s*<div\ id=\"toctitle\">Table\ of\ Contents</div>.*?</div>|$toc|sm;

open($fh, '>', $file);
print $fh $newcont;
close($fh);
