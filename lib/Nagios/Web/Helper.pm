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

######################################
# return the livestatus object
sub get_livesocket {
    my ( $self, $c ) = @_;

    our $livesocket;

    if(defined $livesocket) {
        $c->log->debug("got livestatus from cache");
        return($livesocket);
    }
    $c->log->debug("creating new livestatus");

    my $livesocket_path = Nagios::Web->config->{'livesocket'};
    if(!defined $livesocket_path) {
        $livesocket_path = $self->_get_livesocket_path_from_nagios_cfg(Nagios::Web->config->{'cgi_cfg'});
    }

    $c->log->debug("connecting via: ".$livesocket_path);

    if($livesocket_path =~ m/:/mx) {
        $livesocket = Nagios::MKLivestatus->new(
                                server           => $livesocket_path,
                                verbose          => Nagios::Web->config->{'livesocket_verbose'},
                                keepalive        => 1,
#                                errors_are_fatal => 0,
        );
    } else {
        $livesocket = Nagios::MKLivestatus->new(
                                socket          => $livesocket_path,
                                verbose         => Nagios::Web->config->{'livesocket_verbose'},
                                keepalive       => 1,
#                                errors_are_fatal => 0,
        );
    }
    return($livesocket);
}

########################################
sub sort {
    my $self  = shift;
    my $c     = shift;
    my $data  = shift;
    my $key   = shift;
    my $order = shift;
    my @sorted;

    $order = "ASC" if !defined $order;

    my @keys;
    if(ref($key) eq 'ARRAY') {
        @keys = @{$key};
    } else {
        @keys = ($key);
    }

    my @compares;
    for my $key (@keys) {
        # sort numeric
        if(!defined or $data->[0]->{$key} =~ m/^\d+$/xm) {
            push @compares, '$a->{'.$key.'} <=> $b->{'.$key.'}';
        }
        # sort alphanumeric
        else {
            push @compares, '$a->{'.$key.'} cmp $b->{'.$key.'}';
        }
    }
    my $sortstring = join(' || ', @compares);
    $c->log->debug("ordering by: ".$sortstring);

    if(uc $order eq 'ASC') {
        eval '@sorted = sort { '.$sortstring.' } @{$data};';
    } else {
        eval '@sorted = reverse sort { '.$sortstring.' } @{$data};';
    }

    return(\@sorted);
}

########################################
sub _get_livesocket_path_from_nagios_cfg {
    my $self            = shift;
    my $nagios_cfg_path = shift;

    if(!-r $nagios_cfg_path) {
        confess('cannot read your '.$nagios_cfg_path.'. please specify a livesocket_path in your nagios_web.conf');
    }

    # read nagios.cfg
    my $conf       = new Config::General($nagios_cfg_path);
    my %nagios_cfg = $conf->getall;

    if(!defined $nagios_cfg{'broker_module'}) {
        confess('cannot find a livestatus socket path in your '.$nagios_cfg_path.'. No livestatus broker module loaded?');
    }

    my @broker;
    if(ref $nagios_cfg{'broker_module'} eq 'ARRAY') {
        @broker = [$nagios_cfg{'broker_module'}];
    }else {
        push @broker, $nagios_cfg{'broker_module'};
    }

    for my $neb_line (@broker) {
        if($neb_line =~ m/livestatus.o\s+(.*?)$/) {
            my $livesocket_path = $1;
            return($livesocket_path);
        }
    }

    confess('cannot find a livestatus socket path in your '.$nagios_cfg_path.'. No livestatus broker module loaded?');
}


1;
