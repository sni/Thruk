package Thruk::Controller::mobile;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::mobile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

# enable mobile features if this plugin is loaded
Thruk->config->{'use_feature_mobile'} = 1;

######################################

=head2 mobile_cgi

page: /thruk/cgi-bin/mobile.cgi

=cut
sub mobile_cgi : Regex('thruk\/cgi\-bin\/mobile\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/mobile/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    if(defined $c->{'request'}->{'parameters'}->{'data'}) {
        my $type   = $c->{'request'}->{'parameters'}->{'data'};
        my $limit  = $c->{'request'}->{'parameters'}->{'limit'} || 25;
        my $status = $c->{'request'}->{'parameters'}->{'status'} || 0;
        my ($hostfilter, $servicefilter) = $self->_extract_filter_from_param($c->{'request'}->{'parameters'});
        my $data;
        if($type eq 'notifications') {
            my $filter = {
                    '-and' => [
                                { 'time' => { '>=' => time() - 86400*3 } },
                                { 'time' => { '<=' => time() } },
                                { 'class' => 3 },
                            ]
            };

            $data = $c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter], limit => $limit, sort => {'DESC' => 'time'});
            for my $entry (@{$data}) {
                $entry->{'formated_time'} = Thruk::Utils::Filter::date_format($c, $entry->{'time'});
            }
        }
        elsif($type eq 'alerts') {
            my $filter = {
                    '-and' => [
                                { 'time' => { '>=' => time() - 86400*3 } },
                                { 'time' => { '<=' => time() } },
                                { '-or' => [
                                    { '-and' => [ { 'options' => { '~' => ';HARD;' }, 'type' => 'SERVICE ALERT' } ] },
                                    { '-and' => [ { 'options' => { '~' => ';HARD;' }, 'type' => 'HOST ALERT' } ] },
                                    { 'type' => 'SERVICE FLAPPING ALERT' },
                                    { 'type' => 'HOST FLAPPING ALERT' },
                                ]
                            }]
            };
            $data = $c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter], limit => $limit, sort => {'DESC' => 'time'});
            for my $entry (@{$data}) {
                $entry->{'formated_time'} = Thruk::Utils::Filter::date_format($c, $entry->{'time'});
            }
        }
        elsif($type eq 'host_stats') {
            $data = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
        }
        elsif($type eq 'service_stats') {
            $data = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
        }
        elsif($type eq 'hosts') {
            $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ], limit => $limit);
        }
        elsif($type eq 'services') {
            $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ], limit => $limit);
        }
        if(defined $data) {
            $c->stash->{'json'} = $data;
            $c->forward('Thruk::View::JSON');
            return;
        } else {
            $c->log->error("unknown type: ".$type);
            return;
        }
    }

    $c->stash->{template}  = 'mobile.tt';

    return 1;
}

##########################################################
sub _extract_filter_from_param {
    my($self,$params) = @_;
    my $fake_c = {'request' => {'parameters' => {}}};
    for my $key (keys %{$params}) {
        if($key =~ m/^filter\[(.*)\]$/) {
            $fake_c->{'request'}->{'parameters'}->{$1} = $params->{$key};
        }
    }
    my( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::classic_filter($fake_c);
    return($hostfilter, $servicefilter);
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
