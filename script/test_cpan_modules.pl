#!/usr/bin/env perl

use warnings;
use strict;

my $module = $ARGV[0];
if(!$module) {
    print "usage: $0 <modulename>\n";
    print "\n";
    print "example: $0 Template-Toolkit\n";
    exit 1;
}
$module =~ s/::/-/g;

# get baseurl for this module
my $mainpage  = `wget -q -O - http://search.cpan.org/dist/$module/`;

# get versions
my @matches = $mainpage =~ m|<option.*?"(.*?)">(.*?)&nbsp;.*?\-\-.*;(.*?)<\/option>|gmx;
my @versions;
while(@matches) {
    my $path = shift @matches;
    my $name = shift @matches;
    my $date = shift @matches;
    next if $name =~ m/\-trial/i;
    next if $name =~ m/_\d+/;
    push @versions, [$path, $name, $date];
}

my $num = scalar @versions;
print "testing ".$num." releases of ".$module."\n";
my $x = 0;
for my $v (@versions) {
    my($path, $name, $date) = @{$v};
    $x++;
    my $version = $name;
    $version =~ s/^\Q$module\E\-//gmx;
    printf("%02d/%d %-13s %-12s", $x, $num, $date, $version);
    my $cpanpage  = `wget -q -O - http://search.cpan.org/$path`;
    my $url;
    if($cpanpage =~ m|(\/CPAN\/authors\/id\/.*?/\Q$name\E\.tar\.gz)|mx) {
        $url = $1;
    }
    if(!$url) {
        print " -> could not find downloadlink\n";
        next;
    }
    $url = "http://search.cpan.org/".$url;
    `cpanm -n $url >/dev/null 2>&1`;
    if($? != 0) {
        print " -> broken\n";
        next;
    }
    my $out = `DELAY=1 REQUESTS=20 ./script/test_page_rps.sh master`;
    $out =~ s/^master\s*//mx;
    chomp($out);
    print $out,"\n";
}

# install latest version again
#$module =~ s/-/::/g;
#`cpanm -n $module`;
