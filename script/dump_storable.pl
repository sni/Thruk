#!/usr/bin/env perl

use warnings;
use strict;
use Storable qw/retrieve/;
use Data::Dumper;

my $data = retrieve($ARGV[0]);
$Data::Dumper::Sortkeys = 1;
print Dumper($data);
