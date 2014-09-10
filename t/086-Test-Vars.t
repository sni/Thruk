#!/usr/bin/env perl

use warnings;
use strict;
use Test::More;

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval { require Test::Vars; };

if($@) {
   my $msg = 'Test::Vars required for this test';
   plan( skip_all => $msg );
}

use Test::Vars;
all_vars_ok(ignore_vars => [qw($sec $min $hour $wday $yday $isdst $dow $doy $dst
                               $dev $ino $mode $nlink $uid $gid $rdev $size
                               $atime $mtime $ctime $blksize $blocks
                               $hfilter $controller $test $ct
                          )]);
