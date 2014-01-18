package Thruk::Action::AddCachedDefaults;

=head1 NAME

Thruk::Action::AddCachedDefaults - Add Defaults to the context but trys to use cached process info

=head1 DESCRIPTION

same like AddDefaults but trys to use cached things

=head1 METHODS

=cut

use strict;
use warnings;
use Moose;
use Carp;

extends 'Catalyst::Action';

########################################
before 'execute' => sub {
    Thruk::Action::AddDefaults::add_defaults(2, @_);
};

########################################
__PACKAGE__->meta->make_immutable;

########################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
