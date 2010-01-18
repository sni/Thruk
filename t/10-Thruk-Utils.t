#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 7;
use Data::Dumper;

use_ok('Thruk::Utils');

#########################
# sort
my $befor = [
  {a => 0, b => 'b', c => 2},
  {a => 3, b => 'a', c => 10},
  {a => 2, b => 'c', c => 7},
  {a => 0, b => 'c', c => 11},
];
my $sorted_by_a_exp = [
  {a => 0, b => 'b', c => 2},
  {a => 0, b => 'c', c => 11},
  {a => 2, b => 'c', c => 7},
  {a => 3, b => 'a', c => 10},
];
my $sorted_by_b_exp = [
  {a => 3, b => 'a', c => 10},
  {a => 0, b => 'b', c => 2},
  {a => 2, b => 'c', c => 7},
  {a => 0, b => 'c', c => 11},
];
my $sorted_by_c_exp = [
  {a => 0, b => 'b', c => 2},
  {a => 2, b => 'c', c => 7},
  {a => 3, b => 'a', c => 10},
  {a => 0, b => 'c', c => 11},
];
my $sorted_by_ba_exp = [
  {a => 3, b => 'a', c => 10},
  {a => 0, b => 'b', c => 2},
  {a => 0, b => 'c', c => 11},
  {a => 2, b => 'c', c => 7},
];
my $sorted_by_abc_exp = [
  {a => 0, b => 'b', c => 2},
  {a => 0, b => 'c', c => 11},
  {a => 2, b => 'c', c => 7},
  {a => 3, b => 'a', c => 10},
];
#########################

my $sorted_by_a = Thruk::Utils::sort(undef, $befor, 'a', 'ASC');
is_deeply($sorted_by_a, $sorted_by_a_exp, 'sort by colum a');

my $sorted_by_b = Thruk::Utils::sort(undef, $befor, 'b', 'ASC');
is_deeply($sorted_by_b, $sorted_by_b_exp, 'sort by colum b');

my $sorted_by_c = Thruk::Utils::sort(undef, $befor, 'c', 'ASC');
is_deeply($sorted_by_c, $sorted_by_c_exp, 'sort by colum c');

my $sorted_by_ba = Thruk::Utils::sort(undef, $befor, ['b', 'a'], 'ASC');
is_deeply($sorted_by_ba, $sorted_by_ba_exp, 'sort by colum b,a');

my $sorted_by_ba_reverse = Thruk::Utils::sort(undef, $befor, ['b', 'a'], 'DESC');
my @sorted_by_ba_exp_reverse = reverse @{$sorted_by_ba_exp};
is_deeply($sorted_by_ba_reverse, \@sorted_by_ba_exp_reverse, 'sort by colum b,a reverse');

my $sorted_by_abc = Thruk::Utils::sort(undef, $befor, ['a','b','c'], 'ASC');
is_deeply($sorted_by_abc, $sorted_by_abc_exp, 'sort by colum a,b,c');

