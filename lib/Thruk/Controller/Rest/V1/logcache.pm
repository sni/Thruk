package Thruk::Controller::Rest::V1::logcache;

use strict;
use warnings;
use Thruk::Controller::rest_v1;

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

    my @stats = Thruk::Backend::Provider::Mysql->_log_stats($c);
    Thruk::Backend::Manager::close_logcache_connections($c);
    return(\@stats);
}

##########################################################

1;
