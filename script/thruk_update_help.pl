#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

unless(-f "objectdefinitions.html") {
    `wget "http://nagios.sourceforge.net/docs/3_0/objectdefinitions.html"`;
}

my $help = {};
my $section;
my $key;
my $helptext = "";
open(my $fh, "objectdefinitions.html") or die("failed to open: $!");
while(my $line = <$fh>) {
    chomp($line);
    if($line =~ m/class="Definition">define\s+(.*?)\s*{/gmx) {
        $section = $1;
        print "found section: $section\n";
        $help->{$section} = {};
        next;
    }
    if(defined $section) {
        if($line =~ m/<strong>(.*?)<\/strong>:<\/td>/gmx) {
            $key = strip_tags($1, 1);
            $key =~ s/\s*\**$//gmx;
            $key =~ s/;$//gmx;
            print " -> $key\n";
            next;
        }
        if(defined $key) {
            if($line =~ m/<\/td>/gmx) {
                $help->{$section}->{$key} = strip_tags($helptext);
                undef $key;
                $helptext = "";
                next;
            }
            $helptext .= $line;
        }
    }
}
close($fh);

my $oldsource = "";
open($fh, '<', 'plugins/plugins-available/conf/lib/Monitoring/Config/Help.pm') or die("cannot read file: ".$!);
while(my $line = <$fh>) {
    $oldsource .= $line;
    last if $line =~ "^__DATA__";
}
close($fh);

open($fh, '>', 'plugins/plugins-available/conf/lib/Monitoring/Config/Help.pm') or die("cannot write to file: ".$!);
print $fh $oldsource;
print $fh Dumper($help);
close($fh);
exit;

############################################
sub strip_tags {
    my $text = shift;
    my $all  = shift || 0;
    if($all) {
        $text =~ s/<.*?>//gmx;
    } else {
        $text =~ s/<td.*?>//gmxi;
        $text =~ s/<\/td>//gmxi;
        $text =~ s/<a.*?>(.*?)<\/a>/$1/gmxi;
    }
    return $text;
}
