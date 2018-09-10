package Thruk::Controller::Rest::V1::recurring_downtimes;

use strict;
use warnings;
use Thruk::Controller::rest_v1;

=head1 NAME

Thruk::Controller::Rest::V1::recurring_downtimes - Recurring downtimes rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/recurring_downtimes
# lists recurring downtimes.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/recurring_downtimes?$%mx, \&_rest_get_thruk_downtimes);
sub _rest_get_thruk_downtimes {
    my($c, undef, $nr) = @_;
    require Thruk::Utils::RecurringDowntimes;

    my $downtimes = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c);
    return($downtimes) unless defined $nr;

    my $rd;
    for my $d (@{$downtimes}) {
        if($d->{'file'} eq $nr) {
            $rd = $d;
            last;
        }
    }
    if(!$rd) {
        return({ 'message' => 'no such downtime', code => 404 });
    }

    my $file = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
    my $method = $c->req->method();
    if($method eq 'PATCH') {
        Thruk::Utils::IO::merge_deep($rd, $c->req->parameters);
        if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $rd) != 2) {
            return({ 'message' => 'permission denied', code => 403 });
        }
        Thruk::Utils::IO::json_lock_store($file, $rd, 1, 1);
        Thruk::Utils::RecurringDowntimes::update_cron_file($c);
        return({
            'message' => 'successfully saved 1 downtime.',
            'count'   => 1,
        });
    }
    elsif($method eq 'POST') {
        $rd = \%{$c->req->parameters};
        if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $rd) != 2) {
            return({ 'message' => 'permission denied', code => 403 });
        }
        Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/downtimes/');
        Thruk::Utils::IO::json_lock_store($file, $rd, 1, 1);
        Thruk::Utils::RecurringDowntimes::update_cron_file($c);
        return({
            'message' => 'successfully saved 1 downtime.',
            'count'   => 1,
        });
    }
    elsif($method eq 'DELETE') {
        if(unlink($file)) {
            Thruk::Utils::RecurringDowntimes::update_cron_file($c);
            return({
                'message' => 'successfully removed 1 downtime.',
                'count'   => 1,
            });
        }
        return({
            'message' => 'failed to removed downtime',
            'code'    => 500,
        });
    }

    return($rd);
}

##########################################################
# REST PATH: GET /thruk/recurring_downtimes/<file>
# alias for /thruk/recurring_downtimes?file=<file>

# REST PATH: PATCH /thruk/recurring_downtimes/<file>
# update attributes for given downtime.

# REST PATH: POST /thruk/recurring_downtimes/<file>
# update entire downtime for given file.

# REST PATH: DELETE /thruk/recurring_downtimes/<file>
# remove downtime for given file.
Thruk::Controller::rest_v1::register_rest_path_v1(['GET', 'POST', 'PATCH', 'DELETE'], qr%^/thruk/recurring_downtimes?/([^/\.]+)$%mx, \&_rest_get_thruk_downtimes);

##########################################################
# REST PATH: POST /thruk/recurring_downtimes
# create new downtime.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/recurring_downtimes?$%mx, \&_rest_get_thruk_downtime_new);
sub _rest_get_thruk_downtime_new {
    my($c) = @_;
    require Thruk::Utils::RecurringDowntimes;

    my $rd = Thruk::Utils::RecurringDowntimes::get_default_recurring_downtime($c);
    Thruk::Utils::IO::merge_deep($rd, $c->req->parameters);
    if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $rd) != 2) {
        return({ 'message' => 'permission denied', code => 403 });
    }
    my $file = Thruk::Utils::RecurringDowntimes::get_data_file_name($c, $c->req->parameters->{'file'});
    my $nr   = 0;
    if($file =~ m/\/(\d+)\.tsk$/mx) { $nr = $1; }
    Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/downtimes/');
    Thruk::Utils::IO::json_lock_store($file, $rd, 1, 1);
    Thruk::Utils::RecurringDowntimes::update_cron_file($c);
    return({
        'message' => 'successfully created downtime.',
        'file'    => $nr,
        'count'   => 1,
    });
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
