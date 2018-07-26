package Thruk::Controller::Rest::V1::panorama;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::Rest::V1::panorama - Panorama Dashboards Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/panorama
# lists panorama dashboards.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/panorama$%mx, \&_rest_get_thruk_panorama);
sub _rest_get_thruk_panorama {
    my($c, $path_info) = @_;
    require Thruk::Utils::Panorama;

    my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, 'all');
    my $data = [];
    my @exposed_keys = qw/nr name user/;
    for my $d (@{$dashboards}) {
        my $exposed = {};
        for my $key (@exposed_keys) {
            $exposed->{$key} = $d->{$key};
        }
        push @{$data}, $exposed;
    }
    return $data;
}

##########################################################
# REST PATH: GET /thruk/panorama/<nr>
# panorama dashboards for given number.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/panorama/(\d+)$%mx, \&_rest_get_thruk_panorama_by_id);
sub _rest_get_thruk_panorama_by_id {
    my($c, $path_info, $nr) = @_;
    require Thruk::Utils::Panorama;

    my $data = Thruk::Utils::Panorama::load_dashboard($c, $nr);
    if(!$data) {
        return({ 'message' => 'no such dashboard', code => 404 });
    }
    return $data;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
