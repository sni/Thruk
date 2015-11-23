#!/usr/bin/env perl

use strict;
use warnings;

$| = 1;

my $cur_case_logs   = [];
my $errored         = 0;
my $case_num        = 0;
my $cur_case_num    = 0;
my $print_result    = 0;
my $in_results      = 0;
my $exitcode        = 0;
my $latest_case;
my $counting_cases;
while(my $line = <>) {
    # just skip empty lines
    if($line =~ m|^[\s\.]+$|mx) {
    }
    elsif($line =~ m|SAKULI_RETURN_VAL:\s+(\d+)|mx) {
        $exitcode = $1;
        print $line;
    }
    # number of cases
    # number of cases
    elsif($line =~ m|\Qread test suite information of file\E|mx) {
        $counting_cases = 1;
    }
    elsif($counting_cases) {
        if($line =~ m|\QEnd of File\E|mx) {
            $counting_cases = 0;
        } else {
            $case_num++;
        }
    }
    # start of case
    elsif($line =~ m|\QNow start to execute the test case \E'(.*)'|mx) {
        $cur_case_num++;
        _print_end_case() if $latest_case;
        $latest_case = $1;
        printf("%02d/%02d %s", $cur_case_num, $case_num, $latest_case);
        $cur_case_logs = [];
        $errored = 0;
    }
    # case results
    elsif($line =~ m|=+\s+test\s+case\s+"([^"]+)"\s+ended\s+with\s+(.*?)\s=+|mx) {
        my $res = $2;
        _print_end_case() if $latest_case;
        $latest_case = "";
        if($res ne 'OK') {
            $print_result = 1;
        } else {
            $print_result = 0;
        }
        print $line;
        $in_results = 1;
    }
    # end of tests
    elsif($line =~ m|^===|mx) {
        _print_end_case() if $latest_case;
        $latest_case = "";
        print $line;
        $in_results = 1;
    }
    # inside case
    elsif($latest_case) {
        push @{$cur_case_logs}, $line;
        if($errored || $line !~ m/^INFO\s+/mx) {
            if(!$errored) {
                print "ERROR\n";
                # print backlog for this case
                print(join("", @{$cur_case_logs}));
            } else {
                print "\n";
            }
            chomp($line);
            print $line;
            $errored = 1;
        } else{
            print ".";
        }
    } else {
        if(!$in_results || $print_result) {
            print $line;
        }

    }
}
exit($exitcode);

sub _print_end_case {
    print "OK" unless $errored;
    print "\n";
    if($errored) {
        `docker kill \$(docker ps | awk '{print \$1}' | grep -v CONT)`;
        exit($exitcode) if $exitcode;
        exit(1);
    }
}