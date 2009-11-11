package Nagios::Web::Action::AddDefaults;

=head1 NAME

Nagios::Web::Controller::Root - Root Controller for Nagios::Web

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

use strict;
use warnings;
use Moose;
use Carp;
use Nagios::MKLivestatus;
use Data::Dumper;
use Config::General;

extends 'Catalyst::Action';

########################################
before 'execute' => sub {
    my ( $self, $controller, $c, $test ) = @_;

    ###############################
    # parse cgi.cfg
    $c->{'cgi_cfg'} = $self->_parse_config_file(Nagios::Web->config->{'cgi_cfg'});

    ###############################
    my $live_socket_path    = Nagios::Web->config->{livesocket_path};
    my $live_socket_verbose = Nagios::Web->config->{livesocket_verbose} || 0;
    if(!defined $live_socket_path) {
        croak('no main_config_file defined in '.Nagios::Web->config->{'cgi_cfg'}) if ! defined $c->{'cgi_cfg'}->{'main_config_file'};
        $live_socket_path = $self->_get_livesocket_path_from_nagios_cfg($c->{'cgi_cfg'}->{'main_config_file'});

        if(!defined $live_socket_path) {
            croak("no livesocket broker module found in ".$c->{'cgi_cfg'}->{'main_config_file'}.". NEB Module not loaded?");
        }
    }

    ###############################
    $c->{'live'} = Nagios::MKLivestatus->new(
                                'socket'   => $live_socket_path,
                                'verbose'  => $live_socket_verbose,
    );

    ###############################
    $c->stash->{'refresh_rate'} = $c->{'cgi_cfg'}->{'refresh_rate'};
    $c->stash->{'remote_user'}  = 'admin';

    $c->response->headers->header('refresh' => $c->{'cgi_cfg'}->{'refresh_rate'}) if defined $c->{'cgi_cfg'}->{'refresh_rate'};
};

########################################
#after 'execute' => sub {
#    my ( $self, $controller, $c, $test ) = @_;
#    $c->stash->{foo} = 'bar';
#};


########################################
sub _parse_config_file {
    my $self = shift;
    my $file = shift;
    if(!defined $file) { die('no file'); }
    if(! -r $file)     { croak("cannot open file (".$file."): $!"); }

    my $conf = new Config::General($file);
    my %config = $conf->getall;

    return(\%config);
}

########################################
sub _get_livesocket_path_from_nagios_cfg {
    my $self            = shift;
    my $nagios_cfg_path = shift;

    # read nagios.cfg
    my $nagios_cfg = $self->_parse_config_file($nagios_cfg_path);

    return if !defined $nagios_cfg->{'broker_module'};

    my @broker;
    if(ref $nagios_cfg->{'broker_module'} eq 'ARRAY') {
        @broker = [$nagios_cfg->{'broker_module'}];
    }else {
        push @broker, $nagios_cfg->{'broker_module'};
    }

    for my $neb_line (@broker) {
        if($neb_line =~ m/livestatus.o\s+(.*?)$/) {
            my $livesocket_path = $1;
            return($livesocket_path);
        }
    }
}



__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
