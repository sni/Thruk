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

    $c->stash->{'timezones'}       = Thruk::Utils::get_timezone_data($c, 1);
    my $found = 0;
    for my $tz (@{$c->stash->{'timezones'}}) {
        if($tz->{'text'} eq $c->stash->{'user_tz'}) {
            $found = 1;
            last;
        }
    }
    if(!$found) {
        unshift @{$c->stash->{'timezones'}}, {
            text   => $c->stash->{'user_tz'},
            abbr   => '',
            offset => 0,
        };
    }

    Thruk::Utils::ssi_include($c, 'user');

    if(defined $c->req->parameters->{'action'}) {
        my $action = $c->req->parameters->{'action'};
        if($action eq 'save') {
            my $data = Thruk::Utils::get_user_data($c);
            $data->{'tz'} = $c->req->parameters->{'timezone'};
            if(Thruk::Utils::store_user_data($c, $data)) {
                Thruk::Utils::set_message( $c, 'success_message', 'Settings saved' );
            }
            return $c->redirect_to('user.cgi');
        }
    }

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
