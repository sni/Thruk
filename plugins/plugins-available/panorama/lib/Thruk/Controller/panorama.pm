package Thruk::Controller::panorama;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use JSON::XS;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::panorama - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

# enable panorama features if this plugin is loaded
Thruk->config->{'use_feature_panorama'} = 1;

######################################

=head2 panorama_cgi

page: /thruk/cgi-bin/panorama.cgi

=cut
sub panorama_cgi : Regex('thruk\/cgi\-bin\/panorama\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/panorama/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    if($c->request->query_keywords eq 'state') {
        return($self->_stateprovider($c));
    }

    my $data  = Thruk::Utils::get_user_data($c);
    $c->stash->{state}     = encode_json($data->{'panorama'}->{'state'} || {});
    $c->stash->{template}  = 'panorama.tt';
    return 1;
}

##########################################################

=head2 index

=cut
sub _stateprovider {
    my ( $self, $c ) = @_;

    my $task  = $c->request->parameters->{'task'};
    my $value = $c->request->parameters->{'value'};
    my $name  = $c->request->parameters->{'name'};
use Data::Dumper; print STDERR Dumper($c->request->parameters);
    if($task eq 'set') {
        my $data = Thruk::Utils::get_user_data($c);
        if($value eq 'null') {
            delete $data->{'panorama'}->{'state'}->{$name};
        } else {
            $data->{'panorama'}->{'state'}->{$name} = $value;
        }
        Thruk::Utils::store_user_data($c, $data);
    }

    $c->stash->{'json'} = {
        'status' => 'ok'
    };

    return $c->forward('Thruk::View::JSON');
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2012, <sven@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
