package Thruk::Controller::minemap;

use strict;
use warnings;
use Thruk 1.1.1;
use Carp;
use Data::Dumper;
use Thruk::Utils::Status;
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

Thruk::Utils::Status::add_view({'group' => 'Mine Map',
                                'name'  => 'Mine Map',
                                'value' => 'minemap',
                                'url'   => 'minemap.cgi'
                            });

Thruk->config->{'has_feature_minemap'} = 1;

######################################

=head2 minemap_cgi

page: /thruk/cgi-bin/minemap.cgi

=cut
sub minemap_cgi : Regex('thruk\/cgi\-bin\/minemap\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/minemap/index');
}


##########################################################

=head2 index

minemap index page

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    my $style = $c->{'request'}->{'parameters'}->{'style'} || 'minemap';
    if($style ne 'minemap') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );

    # get pages hosts
    my $uniq_hosts    = {};
    for my $svc (@{$services}) {
        $uniq_hosts->{$svc->{'host_name'}} = 1;
    }
    my @keys = sort keys %{$uniq_hosts};
    Thruk::Backend::Manager::_page_data(undef, $c, \@keys);
    $uniq_hosts = Thruk::Utils::array2hash($c->{'stash'}->{'data'});

    # build matrix
    my $matrix        = {};
    my $uniq_services = {};
    my $hosts         = {};
    for my $svc (@{$services}) {
        next unless defined $uniq_hosts->{$svc->{'host_name'}};
        $uniq_services->{$svc->{'description'}} = 1;
        $hosts->{$svc->{'host_name'}} = $svc;
        $matrix->{$svc->{'host_name'}}->{$svc->{'description'}} = $svc;
    }

    $c->stash->{services}     = $uniq_services;
    $c->stash->{hostnames}    = $hosts;
    $c->stash->{matrix}       = $matrix;


    $c->stash->{style}        = 'minemap';
    $c->stash->{substyle}     = 'service';
    $c->stash->{title}        = 'Mine Map';
    $c->stash->{page}         = 'status';
    $c->stash->{template}     = 'minemap.tt';
    $c->stash->{infoBoxTitle} = 'Mine Map';

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

__PACKAGE__->meta->make_immutable;

1;
