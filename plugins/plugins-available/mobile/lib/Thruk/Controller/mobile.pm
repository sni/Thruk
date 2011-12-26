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
        my $status = $c->{'request'}->{'parameters'}->{'status'} || 0;
        my $page   = $c->{'request'}->{'parameters'}->{'page'}   || 1;
        $c->stash->{'default_page_size'} = 25;

        # gather connection status
        my $connection_status = {};
        for my $pd (@{$c->stash->{'backends'}}) {
            my $name  = $c->stash->{'backend_detail'}->{$pd}->{'name'} || 'unknown';
            my $state = 1;
            $state    = 0 if $c->stash->{'backend_detail'}->{$pd}->{'running'};
            $state    = 2 if $c->stash->{'backend_detail'}->{$pd}->{'disabled'} == 2;
            $connection_status->{$pd} = { name  => $name,
                                          state => $state
                                        };
        }

        my($data,$comments,$downtimes);
        if($type eq 'notifications') {
            my $filter = {
                    '-and' => [
                                { 'time' => { '>=' => time() - 86400*3 } },
                                { 'time' => { '<=' => time() } },
                                { 'class' => 3 },
                            ]
            };

            $data = $c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter], pager => $c, sort => {'DESC' => 'time'});
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
            $data = $c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter], pager => $c, sort => {'DESC' => 'time'});
        }
        elsif($type eq 'host_stats') {
            $data = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
        }
        elsif($type eq 'service_stats') {
            $data = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
        }
        elsif($type eq 'hosts') {
            my ($hostfilter, $servicefilter) = $self->_extract_filter_from_param($c);
            if(defined $c->{'request'}->{'parameters'}->{'host'}) {
                $hostfilter = { 'name' => $c->{'request'}->{'parameters'}->{'host'} };
                $comments   = $c->{'db'}->get_comments(
                                filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $c->{'request'}->{'parameters'}->{'host'} }, { 'service_description' => undef } ],
                                sort => { 'DESC' => 'id' } );
                $downtimes  = $c->{'db'}->get_downtimes(
                                filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $c->{'request'}->{'parameters'}->{'host'} }, { 'service_description' => undef } ],
                                sort => { 'DESC' => 'id' } );
            }
            $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ], pager => $c);
        }
        elsif($type eq 'services') {
            my ($hostfilter, $servicefilter) = $self->_extract_filter_from_param($c);
            if(defined $c->{'request'}->{'parameters'}->{'host'}) {
                $servicefilter = { 'description' => $c->{'request'}->{'parameters'}->{'service'},
                                   'host_name'   => $c->{'request'}->{'parameters'}->{'host'} };
                $comments      = $c->{'db'}->get_comments(
                                    filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $c->{'request'}->{'parameters'}->{'host'} }, { 'service_description' => $c->{'request'}->{'parameters'}->{'service'} } ],
                                    sort => { 'DESC' => 'id' } );
                $downtimes     = $c->{'db'}->get_downtimes(
                                    filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $c->{'request'}->{'parameters'}->{'host'} }, { 'service_description' => $c->{'request'}->{'parameters'}->{'service'} } ],
                                    sort => { 'DESC' => 'id' } );
            }
            $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ], pager => $c);
        }
        if(defined $data) {
            $c->stash->{'json'} = {};
            if(ref $data eq 'ARRAY') {
                $data = $c->stash->{'data'} if defined $c->stash->{'data'};
                $c->stash->{'json'}->{'more'} = 1 if $page < $c->stash->{'pages'};
            }
            $c->stash->{'json'}->{'data'} = $data;
            my $program_starts = {};
            for my $key (keys %{$c->stash->{'pi_detail'}}) {
                $program_starts->{$key} = $c->stash->{'pi_detail'}->{$key}->{'program_start'};
            }
            $c->stash->{'json'}->{program_starts}    = $program_starts;
            $c->stash->{'json'}->{connection_status} = $connection_status;
            $c->stash->{'json'}->{downtimes}         = $downtimes if defined $downtimes;
            $c->stash->{'json'}->{comments}          = $comments  if defined $comments;
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
    my($self,$c) = @_;
    my( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::classic_filter($c);
    return($hostfilter, $servicefilter);
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
