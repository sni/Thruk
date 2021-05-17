package Thruk::Controller::Rest::V1::logcache;

use warnings;
use strict;

use Thruk::Backend::Manager ();
use Thruk::Controller::rest_v1 ();

=head1 NAME

Thruk::Controller::Rest::V1::logcache - Logcache rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/logcache/stats
# lists logcache statistics
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/logcache/stats$%mx, \&_rest_get_thruk_logcache_stats);
sub _rest_get_thruk_logcache_stats {
    my($c) = @_;

    my $pre = _check_prereqs($c);
    return($pre) if $pre;

    my @stats = Thruk::Backend::Provider::Mysql->_log_stats($c);
    Thruk::Backend::Manager::close_logcache_connections($c);
    return(\@stats);
}

##########################################################
# REST PATH: POST /thruk/logcache/update
# runs the logcache delta update.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/logcache/update$%mx, \&_rest_get_thruk_logcache_update);
sub _rest_get_thruk_logcache_update {
    my($c) = @_;

    my $pre = _check_prereqs($c);
    return($pre) if $pre;

    my($backends_count, $log_count, $errors) = Thruk::Backend::Provider::Mysql->_import_logs($c, 'update');
    Thruk::Backend::Manager::close_logcache_connections($c);
    return({
        'errors'       => $errors,
        'message'      => 'logcache update finished.',
        'insert_count' => $log_count,
        'code'         => scalar @{$errors} == 0 ? 200 : 500,
    });
}

##########################################################
sub _check_prereqs {
    my($c) = @_;
    if(!$c->config->{'logcache'}) {
        return({
            'message' => 'logcache is disabled',
            'code'    => 400,
        });
    }

    my $type = '';
    $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;

    eval {
        if($type eq 'mysql') {
            require Thruk::Backend::Provider::Mysql;
            Thruk::Backend::Provider::Mysql->import;
        } else {
            die("unknown logcache type: ".$type);
        }
    };
    if($@) {
        return({
            'message' => 'failed to load logcache: '.$@,
            'code'    => 500,
        });
    }
    return;
}

1;
