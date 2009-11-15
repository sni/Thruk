package Nagios::Web::Helper;

use strict;
use warnings;
use Config::General;
use Carp;

######################################
# parse the cgi.cg
sub get_cgi_cfg {
    my ( $self, $c ) = @_;

    # read only once per request
    our(%config, $cgi_config_already_read);

    return(\%config) if $cgi_config_already_read;

    $cgi_config_already_read = 1;

    my $file = Nagios::Web->config->{'cgi_cfg'};

    if(!defined $file or $file eq '') {
        Nagios::Web->config->{'cgi_cfg'} = 'undef';
        $c->log->error("cgi.cfg not set");
        $c->error("cgi.cfg not set");
        $c->detach('/error/index/4');
    }
    if(! -r $file) {
        $c->log->error("cgi.cfg not readable: ".$!);
        $c->error("cgi.cfg not readable: ".$!);
        $c->detach('/error/index/4');
    }

    my $conf = new Config::General($file);
    %config  = $conf->getall;

    return(\%config);
}


1;
