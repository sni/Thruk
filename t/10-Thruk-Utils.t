#!/usr/bin/env perl

#########################

use strict;
use Test::More tests => 29;
use Data::Dumper;

use_ok('Thruk::Utils');
use_ok('Thruk::Utils::External');
use_ok('Thruk::Backend::Manager');
BEGIN { use_ok 'Catalyst::Test', 'Thruk' }

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

my $sorted_by_a = Thruk::Backend::Manager::_sort(undef, $befor, { 'ASC' => 'a' });
is_deeply($sorted_by_a, $sorted_by_a_exp, 'sort by colum a');

my $sorted_by_b = Thruk::Backend::Manager::_sort(undef, $befor, { 'ASC' => 'b'});
is_deeply($sorted_by_b, $sorted_by_b_exp, 'sort by colum b');

my $sorted_by_c = Thruk::Backend::Manager::_sort(undef, $befor, { 'ASC' => 'c'});
is_deeply($sorted_by_c, $sorted_by_c_exp, 'sort by colum c');

my $sorted_by_ba = Thruk::Backend::Manager::_sort(undef, $befor, { 'ASC' => ['b', 'a'] });
is_deeply($sorted_by_ba, $sorted_by_ba_exp, 'sort by colum b,a');

my $sorted_by_ba_reverse = Thruk::Backend::Manager::_sort(undef, $befor, { 'DESC' => ['b', 'a'] });
my @sorted_by_ba_exp_reverse = reverse @{$sorted_by_ba_exp};
is_deeply($sorted_by_ba_reverse, \@sorted_by_ba_exp_reverse, 'sort by colum b,a reverse');

my $sorted_by_abc = Thruk::Backend::Manager::_sort(undef, $befor, { 'ASC' => ['a','b','c'] });
is_deeply($sorted_by_abc, $sorted_by_abc_exp, 'sort by colum a,b,c');

#########################
my($res, $c) = ctx_request('/thruk/main.html');
my $contactgroups = $c->{'db'}->get_contactgroups_by_contact($c, 'thrukadmin');
is_deeply($contactgroups, {}, 'get_contactgroups_by_contact(thrukadmin)');

#########################
use_ok('XML::Parser');

my $escaped = Thruk::Utils::Filter::xml_escape("& <br> üöä?");
my $p1 = XML::Parser->new();
eval {
    $p1->parse('<data>'.$escaped.'</data>');
};
is("$@", "", "no XML::Parser errors");

#########################
# external cmd
my $id = Thruk::Utils::External::cmd($c, { cmd => "sleep 1; echo 'test'; echo \"err\" >&2;" });
isnt($id, undef, "got an id");

# wait for completion
for(1..5) {
    last unless Thruk::Utils::External::is_running($c, $id);
    sleep(1);
}

is(Thruk::Utils::External::is_running($c, $id), 0, "job finished");
my($out, $err, $time, $dir) = Thruk::Utils::External::get_result($c, $id);

is($out,  "test\n", "got result");
is($err,  "err\n",  "got error");
ok($time >=1,       "got time (".$time."s)");
isnt($dir, undef,   "got dir");

#########################
# external perl
$id = Thruk::Utils::External::perl($c, { expr => "print STDERR 'blah'; print 'blub';" });
isnt($id, undef, "got an id");

# wait for completion
for(1..5) {
    last unless Thruk::Utils::External::is_running($c, $id);
    sleep(1);
}

is(Thruk::Utils::External::is_running($c, $id), 0, "job finished");
($out, $err, $time, $dir) = Thruk::Utils::External::get_result($c, $id);

is($out,   "blub",  "got result");
is($err,   "blah",  "got error");
is($time,  0,       "got time");
isnt($dir, undef,   "got dir");


is(Thruk::Utils::version_compare('1.0.0',   '1.0.1'),   1, 'version_compare: 1.0.0 vs. 1.0.1');
is(Thruk::Utils::version_compare('1.0.1',   '1.0.0'),   0, 'version_compare: 1.0.1 vs. 1.0.0');
is(Thruk::Utils::version_compare('1.0.0',   '1.0.1b1'), 1, 'version_compare: 1.0.0 vs. 1.0.1b1');
is(Thruk::Utils::version_compare('1.0.1b1', '1.0.1b2'), 1, 'version_compare: 1.0.1b1 vs. 1.0.1b2');
