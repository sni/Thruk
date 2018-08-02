#!/usr/bin/perl

print "Content-type: text/html\n\n";
if($ENV{'REMOTE_USER'}) {
    printf("OK: %s\n", $ENV{'REMOTE_USER'});
} else {
    print "FAILED\n";
}
