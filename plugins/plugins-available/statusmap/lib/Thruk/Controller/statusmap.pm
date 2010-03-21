package Thruk::Controller::statusmap;

use strict;
use warnings;
use JSON::XS;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::statusmap - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

Thruk->config->{'use_feature_statusmap'} = 1;

######################################

=head2 statusmap_cgi

page: /thruk/cgi-bin/statusmap.cgi

=cut
sub statusmap_cgi : Path('/thruk/cgi-bin/statusmap.cgi') {
    my ( $self, $c ) = @_;
    return $c->detach('/statusmap/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{level}        = $c->request->parameters->{'level'}   || 1;
    $c->stash->{type}         = $c->request->parameters->{'type'}    || 1;
    $c->stash->{groupby}      = $c->request->parameters->{'groupby'} || 1;

    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: state name alias address address has_been_checked last_state_change plugin_output", { Slice => {}, AddPeer => 1 });

    # order by address
    if($c->stash->{groupby} == 2) {
        $hosts = Thruk::Utils::sort($c, $hosts, ['address'], 'ASC');
    }

    my $json = {
        'id'   => 'rootnode',
        'name' => 'network map',
        'data' => {
            '$area' => 100,
        },
        'children' => [],
    };


    my $x = 0;
    for my $host (@{$hosts}) {
        my $program_start = $c->stash->{'pi_detail'}->{$host->{'peer_key'}}->{'program_start'};
        my($class, $status, $duration,$color);
        if($host->{'has_been_checked'}) {
            if($host->{'state'} == 0) {
                $class    = 'hostUP';
                $status   = 'UP';
                $color    = '#00FF00';
            }
            if($host->{'state'} == 1) {
                $class    = 'hostDOWN';
                $status   = 'DOWN';
                $color    = '#FF0000';
            }
            if($host->{'state'} == 2) {
                $class    = 'hostUNREACHABLE';
                $status   = 'UNREACHABLE';
                $color    = '#FF0000';
            }
        } else {
            $class    = 'hostPENDING';
            $status   = 'PENDING';
        }
        if($host->{'last_state_change'}) {
            $duration = '( for '.Thruk::Utils::filter_duration(time() - $host->{'last_state_change'}).' )';
        } else {
            $duration = '( for '.Thruk::Utils::filter_duration(time() - $program_start).'+ )';
        }
        my $json_host = {
            'id'   => 'host_node_'.$x,
            'name' => $host->{'name'},
            'data' => {
                '$area'         =>  100,
                '$color'        => $color,
                'class'         => $class,
                'status'        => $status,
                'duration'      => $duration,
                'plugin_output' => $host->{'plugin_output'},
                'alias'         => $host->{'alias'},
                'address'       => $host->{'address'},
            },
            'children' => [],
        };
        push @{$json->{'children'}}, $json_host;
        $x++;
    }

#use Data::Dumper;
#print "HTTP/1.0 200 OK\n\n<pre>";
#print Dumper($json);

    #my $coder = JSON::XS->new->utf8->pretty;  # with indention (bigger)
    my $coder = JSON::XS->new->utf8->shrink;   # shortest possible
    $c->stash->{json}         = $coder->encode($json);

    $c->stash->{title}        = 'Network Map';
    $c->stash->{page}         = 'statusmap';
    $c->stash->{template}     = 'statusmap.tt';
    $c->stash->{infoBoxTitle} = 'Network Map For All Hosts';

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
