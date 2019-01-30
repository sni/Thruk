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
# lists all panorama dashboards.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/panorama$%mx, \&_rest_get_thruk_panorama);
sub _rest_get_thruk_panorama {
    my($c, undef, $id) = @_;
    require Thruk::Utils::Panorama;

    my $data = [];
    my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, 'all');
    for my $d (@{$dashboards}) {
        my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $d->{'nr'});
        push @{$data}, $dashboard;
    }
    if($id && scalar @{$data} == 0) {
        return({ 'message' => 'no such dashboard', code => 404 });
    }
    return $data;
}

##########################################################
# REST PATH: GET /thruk/panorama/<nr>
# returns panorama dashboard for given number.
# alias for /thruk/panorama?nr=<nr>
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/panorama/(\d+)$%mx, \&_rest_get_thruk_panorama);

##########################################################

1;
