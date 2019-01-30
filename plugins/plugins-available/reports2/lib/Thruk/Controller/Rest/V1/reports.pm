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

    my $reports = _clean_reports(Thruk::Utils::Reports::get_report_list($c));
    return $reports;
}

##########################################################
# REST PATH: POST /thruk/reports
# create new report.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/reports?$%mx, \&_rest_get_thruk_reports_new);
sub _rest_get_thruk_reports_new {
    my($c, $path_info) = @_;
    require Thruk::Utils::Reports;

    my $report = Thruk::Utils::Reports::report_save($c, "new", \%{$c->req->parameters});
    if(ref $report eq 'HASH' && $report->{'nr'}) {
        return({
            'message' => 'successfully saved 1 report.',
            'id'      => $report->{'nr'},
            'count'   => 1,
        });
    }
    return({
        'message' => 'failed to save report',
        'code'    => 500,
    });
}

##########################################################
# REST PATH: GET /thruk/reports/<nr>
# report for given number.

# REST PATH: PATCH /thruk/reports/<nr>
# update attributes for given number.

# REST PATH: POST /thruk/reports/<nr>
# update entire report for given number.

# REST PATH: DELETE /thruk/reports/<nr>
# remove report for given number.
Thruk::Controller::rest_v1::register_rest_path_v1(['GET', 'POST', 'PATCH', 'DELETE'], qr%^/thruk/reports?/(\d+)$%mx, \&_rest_get_thruk_report_by_id);
sub _rest_get_thruk_report_by_id {
    my($c, $path_info, $nr) = @_;
    require Thruk::Utils::Reports;

    my $reports = _clean_reports(Thruk::Utils::Reports::get_report_list($c, undef, $nr));
    if(!$reports->[0]) {
        return({ 'message' => 'no such report', code => 404 });
    }

    my $method = $c->req->method();
    if($method eq 'PATCH') {
        Thruk::Utils::IO::merge_deep($reports->[0], $c->req->parameters);
        if(Thruk::Utils::Reports::report_save($c, $nr, $reports->[0])) {
            return({
                'message' => 'successfully saved 1 report.',
                'count'   => 1,
            });
        }
        return({
            'message' => 'failed to save report',
            'code'    => 500,
        });
    }
    elsif($method eq 'POST') {
        $reports->[0] = \%{$c->req->parameters};
        if(Thruk::Utils::Reports::report_save($c, $nr, $reports->[0])) {
            return({
                'message' => 'successfully saved 1 report.',
                'count'   => 1,
            });
        }
        return({
            'message' => 'failed to save report',
            'code'    => 500,
        });
    }
    elsif($method eq 'DELETE') {
        if(Thruk::Utils::Reports::report_remove($c, $nr)) {
            return({
                'message' => 'successfully removed 1 report.',
                'count'   => 1,
            });
        }
        return({
            'message' => 'failed to removed report',
            'code'    => 500,
        });
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

    my $reports = _clean_reports(Thruk::Utils::Reports::get_report_list($c, undef, $nr));
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
sub _clean_reports {
    my($reports) = @_;
    return unless $reports;
    my $remove_keys = [qw/backends_hash long_error failed_backends var/];
    for my $r (@{$reports}) {
        for my $key (@{$remove_keys}) {
            delete $r->{$key};
        }
    }
    return($reports);
}

##########################################################

1;
