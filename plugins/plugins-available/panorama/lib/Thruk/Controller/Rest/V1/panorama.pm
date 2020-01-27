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
        next if($id && $d->{'nr'} ne $id);
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
# REST PATH: POST /thruk/panorama/<nr>/maintenance
# Puts given dashboard into maintenance mode.
#
# Required arguments:
#
#   * text
# REST PATH: DELETE /thruk/panorama/<nr>/maintenance
# removes maintenance mode from given dashboard.
Thruk::Controller::rest_v1::register_rest_path_v1(['POST', 'DELETE'], qr%^/thruk/panorama/(\d+)/maintenance$%mx, \&_rest_get_thruk_panorama_maint);
sub _rest_get_thruk_panorama_maint {
    my($c, undef, $id) = @_;
    require Thruk::Utils::Panorama;

    my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $id);
    if(!$dashboard) {
        return({ 'message' => 'no such dashboard', code => 404 });
    }

    my $name   = $dashboard->{'tab'}->{'xdata'}->{'title'} // 'no name';
    my $method = $c->req->method;
    if($method eq 'DELETE') {
        unlink(Thruk::Utils::Panorama::get_maint_file($c, $dashboard->{'nr'}));
        return({ 'message' => 'maintenance mode removed from dashboard '.$name });
    }
    if($method eq 'POST') {
        my $text = $c->req->parameters->{'text'};
        if(!defined $text) {
            return({ 'message' => 'missing argument: text', 'description' => 'text is a required argument', code => 400 });
        }
        Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/panorama');
        Thruk::Utils::IO::json_lock_store(Thruk::Utils::Panorama::get_maint_file($c, $dashboard->{'nr'}), { 'maintenance' => $text }, { 'pretty' => 1 });
        return({ 'message' => 'dashboard '.$name.' put into maintenance mode' });
    }
}

##########################################################

1;
