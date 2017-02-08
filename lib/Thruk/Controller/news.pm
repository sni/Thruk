package Thruk::Controller::news;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::news - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(defined $c->req->parameters->{'action'}) {
        my $action = $c->req->parameters->{'action'};
        if($action eq 'dismiss') {
            my $news = Thruk::Utils::News::get_news($c);
            my $data = Thruk::Utils::get_user_data($c);
            $data->{'news'}->{'read'} = $news->[0]->{'basefile'};
            Thruk::Utils::store_user_data($c, $data);
            return $c->render(json => {'status' => 'ok'});
        }
    }

    $c->stash->{template} = 'news.tt';

    Thruk::Utils::ssi_include($c);

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
