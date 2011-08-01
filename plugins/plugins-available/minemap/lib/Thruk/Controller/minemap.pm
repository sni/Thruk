package Thruk::Controller::minemap;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::minemap - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

######################################
# add new menu item
Thruk::Utils::Menu::insert_sub_item('Current Status', 'Service Groups', {
                                    'href'  => '/thruk/cgi-bin/minemap.cgi',
                                    'name'  => 'Mine Map',
                         });

Thruk->config->{'has_feature_minemap'} = 1;

######################################

=head2 minemap_cgi

page: /thruk/cgi-bin/minemap.cgi

=cut
sub minemap_cgi : Regex('thruk\/cgi\-bin\/minemap\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/minemap/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );

    # build matrix
    my $matrix        = {};
    my $uniq_hosts    = {};
    my $uniq_services = {};
    for my $svc (@$services) {
        $uniq_hosts->{$svc->{'host_name'}} = $svc;
        $uniq_services->{$svc->{'description'}} = 1;
        $matrix->{$svc->{'host_name'}}->{$svc->{'description'}} = $svc;
    }
    $c->stash->{servicesnames} = $uniq_services;
    $c->stash->{hostnames}     = $uniq_hosts;
    $c->stash->{toomany}       = 0;
    if(scalar (keys %{$c->stash->{servicesnames}}) * scalar (keys %{$c->stash->{hostnames}}) > 10000) {
        $c->stash->{toomany}        = 1;
        $c->stash->{hidesearch}     = 0;
    }
    $c->stash->{data}          = $matrix;

    $c->stash->{style}        = 'minemap';
    $c->stash->{substyle}     = 'service';
    $c->stash->{title}        = 'Mine Map';
    $c->stash->{page}         = 'status';
    $c->stash->{template}     = 'minemap.tt';
    $c->stash->{infoBoxTitle} = 'Mine Map For All Hosts';

    Thruk::Utils::ssi_include($c);

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
