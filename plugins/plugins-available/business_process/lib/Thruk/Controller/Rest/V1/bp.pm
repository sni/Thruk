package Thruk::Controller::Rest::V1::bp;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::Rest::V1::bp - Business Process Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/bp
# lists business processes.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/bp$%mx, \&_rest_get_thruk_bp);
sub _rest_get_thruk_bp {
    my($c, $path_info) = @_;
    require Thruk::BP::Utils;

    my $bps = Thruk::BP::Utils::load_bp_data($c);
    my $data = [];
    my @exposed_keys = qw/id name file last_check last_state_change
                            state_type status status_text template time draft/;
    for my $bp (@{$bps}) {
        my $exposed = {};
        for my $key (@exposed_keys) {
            $exposed->{$key} = $bp->{$key};
        }
        push @{$data}, $exposed;
    }
    return($data);
}

##########################################################
# REST PATH: GET /thruk/bp/<nr>
# business processes for given number.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/bp/(\d+)$%mx, \&_rest_get_thruk_bp_by_id);
sub _rest_get_thruk_bp_by_id {
    my($c, $path_info, $nr) = @_;
    require Thruk::BP::Utils;

    my $bps = Thruk::BP::Utils::load_bp_data($c, $nr);
    if($bps->[0]) {
        return($bps->[0]->TO_JSON());
    }
    return({ 'message' => 'no such business process', code => 404 });
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
