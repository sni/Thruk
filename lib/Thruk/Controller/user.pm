package Thruk::Controller::user;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::user - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    $c->stash->{'page'}            = 'conf';
    $c->stash->{has_jquery_ui}     = 1;
    $c->stash->{'no_auto_reload'}  = 1;
    $c->stash->{'title'}           = 'User Profile';
    $c->stash->{'infoBoxTitle'}    = 'User Profile';

    Thruk::Utils::ssi_include($c, 'user');

    #if(defined $c->req->parameters->{'action'}) {
    #    my $action = $c->req->parameters->{'action'};
    #}

    $c->stash->{template} = 'user_profile.tt';

    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
