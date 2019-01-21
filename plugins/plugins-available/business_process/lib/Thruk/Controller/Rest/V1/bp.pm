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
    my($c) = @_;
    require Thruk::BP::Utils;

    my $bps = Thruk::BP::Utils::load_bp_data($c, undef, undef, 1);
    my $data = [];
    for my $bp (@{$bps}) {
        push @{$data}, $bp->TO_JSON();
    }
    return($data);
}

##########################################################
# REST PATH: GET /thruk/bp/<nr>
# business processes for given number.
# alias for /thruk/bp?id=<nr>
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/bp/(\d+)$%mx, \&_rest_get_thruk_bp_by_id);
sub _rest_get_thruk_bp_by_id {
    my($c, undef, $nr) = @_;
    require Thruk::BP::Utils;

    my $bps = Thruk::BP::Utils::load_bp_data($c, $nr, undef, 1);
    if($bps->[0]) {
        return($bps->[0]->TO_JSON());
    }
    return({ 'message' => 'no such business process', code => 404 });
}

##########################################################
# REST PATH: POST /thruk/bp
# create new business process.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/bp$%mx, \&_rest_get_thruk_bp_new);
sub _rest_get_thruk_bp_new {
    my($c) = @_;
    require Thruk::Utils::Reports;
    require Thruk::BP::Utils;

    Thruk::BP::Utils::clean_orphaned_edit_files($c, 86400);
    my($file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
    my $bp = Thruk::BP::Components::BP->new($c, $file, $c->req->parameters);
    my $label = Thruk::BP::Utils::clean_nasty($c->req->parameters->{'name'} || 'New Business Process');
    $label = Thruk::BP::Utils::make_uniq_label($c, $label);
    $bp->set_label($c, $label);
    $bp->save();

    my $bps = Thruk::BP::Utils::load_bp_data($c);
    my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
    Thruk::BP::Utils::update_cron_file($c); # check cronjob
    if($rc != 0) {
        return({ 'message' => 'reload command failed', code => 500 });
    }

    $bps = Thruk::BP::Utils::load_bp_data($c, $newid, undef, 1);
    if(!$bps->[0]) {
        return({ 'message' => 'creating business process failed', code => 500 });
    }
    return({ 'message' => 'business process sucessfully created', data => $bps->[0] });
}

##########################################################
# REST PATH: POST /thruk/bp/<nr>
# update business processes configuration for given number.
# REST PATH: PATCH /thruk/bp/<nr>
# update business processes configuration partially for given number.
# REST PATH: DELETE /thruk/bp/<nr>
# remove business processes for given number.
Thruk::Controller::rest_v1::register_rest_path_v1(['POST', 'PATCH','DELETE'], qr%^/thruk/bp/(\d+)$%mx, \&_rest_get_thruk_bp_by_id_crud);
sub _rest_get_thruk_bp_by_id_crud {
    my($c, undef, $nr) = @_;
    require Thruk::BP::Utils;

    my $bps = Thruk::BP::Utils::load_bp_data($c, $nr, undef, 1);
    if(!$bps->[0]) {
        return({ 'message' => 'no such business process', code => 404 });
    }
    my $bp     = $bps->[0];
    my $method = $c->req->method;

    my $action = "updated";
    if($method eq 'DELETE') {
        $bp->remove($c);
        $action = "removed";
    }
    if($method eq 'PATCH') {
        my $file = delete $bp->{'file'};
        Thruk::Utils::IO::merge_deep($bp, $c->req->parameters);
        $bp->set_file($c, $file);
        $bp->{'id'} = $nr;
        $bp->save($c);
        $bp->commit($c);
    }
    if($method eq 'POST') {
        $bp->FROM_JSON($c, $c->req->parameters);
{ open(my $fh5, '>', '/omd/sites/demo/var/thruk/test.log'); use Data::Dumper; print $fh5 Dumper($bp); CORE::close($fh5); }
        $bp->save($c);
        $bp->commit($c);
    }

    $bps = Thruk::BP::Utils::load_bp_data($c);
    my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
    Thruk::BP::Utils::update_cron_file($c); # check cronjob
    if($rc != 0) {
        return({ 'message' => 'reload command failed', code => 500 });
    }
    return({ 'message' => 'business process sucessfully '.$action });
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
