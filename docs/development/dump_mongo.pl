#!/usr/bin/perl

use warnings;
use strict;
use MongoDB;

my $self = {
  'db' => MongoDB::Connection->new(host => 'localhost:27017'),
  'last_program_start' => time(),
};

my $data = $self->{'db'}->status->status->find();
use Data::Dumper; print STDERR Dumper($data);
