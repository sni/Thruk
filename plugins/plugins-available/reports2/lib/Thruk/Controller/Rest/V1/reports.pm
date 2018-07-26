package Thruk::Controller::Rest::V1::reports;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::Rest::V1::reports - Reports Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/reports
# list of reports.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/reports?$%mx, \&_rest_get_thruk_reports);
sub _rest_get_thruk_reports {
    my($c, $path_info) = @_;
    require Thruk::Utils::Reports;

    my $reports = Thruk::Utils::Reports::get_report_list($c);
    my $data    = [];
    my @exposed_keys = qw/nr name user template is_public to cc/;
    for my $r (@{$reports}) {
        my $exposed = {};
        for my $key (@exposed_keys) {
            $exposed->{$key} = $r->{$key};
        }
        push @{$data}, $exposed;
    }
    return $data;
}

##########################################################
# REST PATH: GET /thruk/reports/<nr>
# report for given number.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/reports?/(\d+)$%mx, \&_rest_get_thruk_report_by_id);
sub _rest_get_thruk_report_by_id {
    my($c, $path_info, $nr) = @_;
    require Thruk::Utils::Reports;

    my $reports = Thruk::Utils::Reports::get_report_list($c, undef, $nr);
    if(!$reports->[0]) {
        return({ 'message' => 'no such report', code => 404 });
    }
    return($reports->[0]);
}

##########################################################
# REST PATH: GET /thruk/reports/<nr>/report
# return the actual report file in binary format.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/reports?/(\d+)/report$%mx, \&_rest_get_thruk_report_by_id_file);
sub _rest_get_thruk_report_by_id_file {
    my($c, $path_info, $nr) = @_;
    require Thruk::Utils::Reports;

    my $reports = Thruk::Utils::Reports::get_report_list($c, undef, $nr);
    if(!$reports->[0]) {
        return({ 'message' => 'no such report', code => 404 });
    }
    return(Thruk::Utils::Reports::report_show($c, $nr));
}

##########################################################
# REST PATH: POST /thruk/reports/<nr>/generate
# generate report for given number.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/reports?/(\d+)/generate$%mx, \&_rest_get_thruk_report_by_id_generate);
sub _rest_get_thruk_report_by_id_generate {
    my($c, $path_info, $nr) = @_;
    require Thruk::Utils::Reports;

    my $reports = Thruk::Utils::Reports::get_report_list($c, undef, $nr);
    if(!$reports->[0]) {
        return({ 'message' => 'no such report', code => 404 });
    }

    my $job = Thruk::Utils::Reports::generate_report_background($c, $nr);
    if($job) {
        return({ 'message' => 'report started in background', job => $job });
    }
    return({ 'message' => 'report finished' });
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
