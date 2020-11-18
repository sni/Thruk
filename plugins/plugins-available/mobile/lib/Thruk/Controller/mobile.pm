package Thruk::Controller::mobile;

use strict;
use warnings;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::mobile - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    $c->stash->{'inject_stats'} = 0;

    if(defined $c->req->parameters->{'data'}) {
        my $type   = $c->req->parameters->{'data'};
        my $status = $c->req->parameters->{'status'} || 0;
        my $page   = $c->req->parameters->{'page'}   || 1;
        $c->stash->{'default_page_size'} = 25;

        # gather connection status
        my $connection_status = {};
        for my $pd (@{$c->stash->{'backends'}}) {
            my $name  = $c->stash->{'backend_detail'}->{$pd}->{'name'} || 'unknown';
            my $state = 1;
            $state    = 0 if $c->stash->{'backend_detail'}->{$pd}->{'running'};
            $state    = 2 if $c->stash->{'backend_detail'}->{$pd}->{'disabled'} == 2;
            $connection_status->{$pd} = { name  => $name,
                                          state => $state,
                                        };
        }

        my ($hostfilter, $servicefilter) = _extract_filter_from_param($c);
        my($data,$comments,$downtimes,$pnp_url);
        if($type eq 'notifications') {
            my($logfilter) = _extract_logfilter_from_param($c);
            my $filter = {
                    '-and' => [
                                { 'time' => { '>=' => time() - 86400*3 } },
                                { 'time' => { '<=' => time() } },
                                { 'class' => 3 },
                            ],
            };

            $data = $c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter, $logfilter], pager => 1, sort => {'DESC' => 'time'});
        }
        elsif($type eq 'alerts') {
            my($logfilter) = _extract_logfilter_from_param($c);
            my $filter = {
                    '-and' => [
                                { 'time' => { '>=' => time() - 86400*3 } },
                                { 'time' => { '<=' => time() } },
                                { '-or' => [
                                    { '-and' => [ { 'state_type' => { '=' => 'HARD' }}, { 'type' => 'SERVICE ALERT' } ] },
                                    { '-and' => [ { 'state_type' => { '=' => 'HARD' }}, { 'type' => 'HOST ALERT' } ] },
                                    { 'type' => 'SERVICE FLAPPING ALERT' },
                                    { 'type' => 'HOST FLAPPING ALERT' },
                                ],
                            }],
            };
            $data = $c->{'db'}->get_logs(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'log'), $filter, $logfilter], pager => 1, sort => {'DESC' => 'time'});
        }
        elsif($type eq 'host_stats') {
            $data = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
        }
        elsif($type eq 'service_stats') {
            $data = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
        }
        elsif($type eq 'hosts') {
            if(defined $c->req->parameters->{'host'} || defined $c->req->parameters->{'filter'}) {
                $hostfilter = { 'name' => $c->req->parameters->{'host'} };
                my $commentfilter = { 'host_name' => $c->req->parameters->{'host'} };
                if(defined $c->req->parameters->{'filter'}) {
                    $hostfilter    = { 'name' => { '~~' => $c->req->parameters->{'filter'} } };
                    $commentfilter = { 'host_name' => { '~~' => $c->req->parameters->{'filter'} } };
                }
                $comments   = $c->{'db'}->get_comments(
                                filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), $commentfilter, { 'service_description' => undef } ],
                                sort => { 'DESC' => 'id' } );
                $downtimes  = $c->{'db'}->get_downtimes(
                                filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), $commentfilter, { 'service_description' => undef } ],
                                sort => { 'DESC' => 'id' } );
            }
            $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ], pager => 1);
            if(defined $c->req->parameters->{'host'} and defined $data->[0]) {
                $pnp_url = Thruk::Utils::get_pnp_url($c, $data->[0]);
            }
        }
        elsif($type eq 'services') {
            if(defined $c->req->parameters->{'host'} || defined $c->req->parameters->{'filter'}) {
                $servicefilter = { 'description' => $c->req->parameters->{'service'},
                                   'host_name'   => $c->req->parameters->{'host'} };
                my $commentfilter = { 'host_name' => $c->req->parameters->{'host'}, 'service_description' => $c->req->parameters->{'service'}, };
                if(defined $c->req->parameters->{'filter'}) {
                    $servicefilter = { -or => [ {'description' => { '~~' => $c->req->parameters->{'filter'} } },
                                                { 'host_name'  => { '~~' => $c->req->parameters->{'filter'} } },
                                              ]};
                    $commentfilter = { -or => [ {'service_description' => { '~~' => $c->req->parameters->{'filter'} } },
                                                { 'host_name'          => { '~~' => $c->req->parameters->{'filter'} } },
                                              ]};
                }
                $comments      = $c->{'db'}->get_comments(
                                    filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $c->req->parameters->{'host'} }, { 'service_description' => $c->req->parameters->{'service'} } ],
                                    sort => { 'DESC' => 'id' } );
                $downtimes     = $c->{'db'}->get_downtimes(
                                    filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $c->req->parameters->{'host'} }, { 'service_description' => $c->req->parameters->{'service'} } ],
                                    sort => { 'DESC' => 'id' } );
            }
            $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ], pager => 1);
            if(defined $c->req->parameters->{'host'} and defined $data->[0]) {
                $pnp_url = Thruk::Utils::get_pnp_url($c, $data->[0]);
            }
        }
        if(defined $data) {
            my $json = {};
            if(ref $data eq 'ARRAY') {
                $data = $c->stash->{'data'} if defined $c->stash->{'data'};
                $json->{'more'} = 1 if($page < ($c->stash->{'pages'} || 1));
            }
            $json->{'data'} = $data;
            my $program_starts = {};
            if(defined $c->stash->{'pi_detail'} and ref $c->stash->{'pi_detail'} eq 'HASH') {
                for my $key (keys %{$c->stash->{'pi_detail'}}) {
                    $program_starts->{$key} = $c->stash->{'pi_detail'}->{$key}->{'program_start'};
                }
            }
            $json->{program_starts}    = $program_starts;
            $json->{connection_status} = $connection_status;
            $json->{downtimes}         = $downtimes if defined $downtimes;
            $json->{comments}          = $comments  if defined $comments;
            $json->{pnp_url}           = $pnp_url   if defined $pnp_url;
            return $c->render(json => $json);
        } else {
            _error("unknown type: ".$type);
            return;
        }
    }

    # add additonal links on the home page
    $c->stash->{links} = [];
    if($c->config->{'Thruk::Plugin::Mobile'}->{'links'}) {
        my $remote_user = $c->stash->{'remote_user'};
        for my $link (@{Thruk::Utils::list($c->config->{'Thruk::Plugin::Mobile'}->{'links'})}) {
            my($name,$url) = split(/\s*;\s*/mx, $link, 2);
            # do not replace in $link, as this would overwrite the config for all users
            $name =~ s/\$CONTACTNAME\$/$remote_user/gmx;
            $url  =~ s/\$CONTACTNAME\$/$remote_user/gmx;
            push @{$c->stash->{links}}, { name => $name, url => $url };
        }
    }

    $c->stash->{template} = 'mobile.tt';

    return 1;
}

##########################################################
sub _extract_filter_from_param {
    my($c) = @_;
    my( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::classic_filter($c);
    return($hostfilter, $servicefilter);
}

##########################################################
sub _extract_logfilter_from_param {
    my($c) = @_;
    my $filter = [];
    if(defined $c->req->parameters->{'host'}) {
        push @{$filter}, { host_name => $c->req->parameters->{'host'} };
    }
    if(defined $c->req->parameters->{'service'}) {
        push @{$filter}, { service_description => $c->req->parameters->{'service'} };
    }
    if($c->req->parameters->{'contact'}) {
        push @{$filter}, { contact_name => $c->req->parameters->{'contact'} };
    }

    return($filter);
}

1;
