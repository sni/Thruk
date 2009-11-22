package Nagios::Web::Action::AddDefaults;

=head1 NAME

Nagios::Web::Action::AddDefaults - Add Defaults to the context

=head1 DESCRIPTION

loads cgi.cfg

creates MKLivestatus object

=head1 METHODS

=cut

=head2 index

=cut

use strict;
use warnings;
use Moose;
use Carp;
use Nagios::MKLivestatus;
use Data::Dumper;
use Config::General;
use Nagios::Web::Helper;

extends 'Catalyst::Action';

########################################
before 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    ###############################
    # parse cgi.cfg
    $c->{'cgi_cfg'} = Nagios::Web::Helper->get_cgi_cfg($c);

    ###############################
    # get livesocket object
    $c->{'live'} = Nagios::Web::Helper->get_livesocket($c);

    ###############################
    $c->stash->{'refresh_rate'} = $c->{'cgi_cfg'}->{'refresh_rate'};
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    $c->stash->{'page'} = 'status'; # set a default page, so at least some css is loaded
    $c->response->headers->header('refresh' => $c->{'cgi_cfg'}->{'refresh_rate'}) if defined $c->{'cgi_cfg'}->{'refresh_rate'};
};



__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
