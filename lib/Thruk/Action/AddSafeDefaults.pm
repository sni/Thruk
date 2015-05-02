package Thruk::Action::AddSafeDefaults;

=head1 NAME

Thruk::Action::AddSafeDefaults - Add Defaults to the context

=head1 DESCRIPTION

same like AddDefaults but does not redirect to error page on backend errors

=head1 METHODS

=cut

use strict;
use warnings;
use namespace::autoclean;
use Moose;

extends 'Catalyst::Action';

########################################
before 'execute' => sub {
    my $c = $_[2];
    eval {
        Thruk::Action::AddDefaults::add_defaults(1, @_);
    };
    print STDERR $@ if($@ and $c->config->{'thruk_debug'});
};

########################################
after 'execute' => sub {
    Thruk::Action::AddDefaults::after_execute(@_);
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
