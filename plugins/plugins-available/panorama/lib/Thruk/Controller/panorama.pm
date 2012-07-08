package Thruk::Controller::panorama;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use JSON::XS;
use URI::Escape;
use IO::Socket;

use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::panorama - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

##########################################################
# enable panorama features if this plugin is loaded
Thruk->config->{'use_feature_panorama'} = 1;

##########################################################
# add new menu item
Thruk::Utils::Menu::insert_item('General', {
                                    'href'  => '/thruk/cgi-bin/panorama.cgi',
                                    'name'  => 'Panorama View',
                                    target  => '_parent'
                         });

##########################################################

=head2 panorama_cgi

page: /thruk/cgi-bin/panorama.cgi

=cut
sub panorama_cgi : Regex('thruk\/cgi\-bin\/panorama\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/panorama/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    if(defined $c->request->query_keywords and $c->request->query_keywords eq 'state') {
        return($self->_stateprovider($c));
    }

    if(defined $c->request->parameters->{'task'}) {
        my $task = $c->request->parameters->{'task'};
        if($task eq 'stats_core_metrics') {
            return($self->_stats_core_metrics($c));
        }
        elsif($task eq 'stats_check_metrics') {
            return($self->_stats_check_metrics($c));
        }
        elsif($task eq 'stats_gearman') {
            return($self->_stats_gearman($c));
        }
    }

    my $data  = Thruk::Utils::get_user_data($c);
    $c->stash->{state}     = encode_json($data->{'panorama'}->{'state'} || {});
    $c->stash->{template}  = 'panorama.tt';
    return 1;
}

##########################################################

=head2 index

=cut
sub _stateprovider {
    my ( $self, $c ) = @_;

    my $task  = $c->request->parameters->{'task'};
    my $value = $c->request->parameters->{'value'};
    my $name  = $c->request->parameters->{'name'};

    if(defined $task and $task eq 'set') {
        my $data = Thruk::Utils::get_user_data($c);
        if($value eq 'null') {
            $c->log->debug("panorama: removed ".$name);
            delete $data->{'panorama'}->{'state'}->{$name};
        } else {
            $c->log->debug("panorama: set ".$name." to ".$self->_nice_ext_value($value));
            $data->{'panorama'}->{'state'}->{$name} = $value;
        }
        Thruk::Utils::store_user_data($c, $data);

        $c->stash->{'json'} = {
            'status' => 'ok'
        };
    } else {
        $c->stash->{'json'} = {
            'status' => 'failed'
        };
    }

    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _nice_ext_value {
    my($self, $orig) = @_;
    my $value = uri_unescape($orig);
    $value =~ s/^o://gmx;
    my @val   = split/\^/mx, $value;
    my $o = {};
    for my $v (@val) {
        my($key, $val) = split(/=/mx, $v, 2);
        $val =~ s/^n%3A//gmx;
        $val =~ s/^b%3A0/false/gmx;
        $val =~ s/^b%3A1/true/gmx;
        if($val =~ m/^a%3A/mx) {
            $val =~ s/^a%3A//mx;
            $val =~ s/s%253A//gmx;
            $val = [ split(m/n%253A|%5E/mx, $val) ];
            @{$val} = grep {!/^$/mx} @{$val};
        }
        elsif($val =~ m/^o%3A/mx) {
            $val =~ s/^o%3A//mx;
            $val = [ split(m/n%253A|%3D|%5E/mx, $val) ];
            @{$val} = grep {!/^$/mx} @{$val};
            $val = {@{$val}};
        } else {
            $val =~ s/^s%3A//mx;
        }
        $o->{$key} = $val;
    }
    $Data::Dumper::Sortkeys = 1;
    $value = Dumper($o);
    $value =~ s/^\$VAR1\ =//gmx;
    $value =~ s/\n/ /gmx;
    $value =~ s/\s+/ /gmx;
    return $value;
}

##########################################################
sub _stats_core_metrics {
    my($self, $c) = @_;

    my $data = $c->{'db'}->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );
    my $json = {
        columns => [
            { 'header' => 'Type',  dataIndex => 'type',  flex  => 1 },
            { 'header' => 'Total', dataIndex => 'total', align => 'right' },
            { 'header' => 'Rate',  dataIndex => 'rate',  align => 'right', xtype => 'numbercolumn', format => '0.00/s' },
        ],
        data    => [
            { type => 'Servicechecks',       total => $data->{'service_checks'}, rate => $data->{'service_checks_rate'} },
            { type => 'Hostchecks',          total => $data->{'host_checks'},    rate => $data->{'host_checks_rate'} },
            { type => 'Connections',         total => $data->{'connections'},    rate => $data->{'connections_rate'} },
            { type => 'Requests',            total => $data->{'requests'},       rate => $data->{'requests_rate'} },
            { type => 'NEB Callbacks',       total => $data->{'neb_callbacks'},  rate => $data->{'neb_callbacks_rate'} },
            { type => 'Cached Log Messages', total => $data->{'cached_log_messages'}, rate => '' },
        ]
    };

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _stats_check_metrics {
    my($self, $c) = @_;

    my $data = $c->{'db'}->get_performance_stats( services_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], hosts_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );

    my $json = {
        columns => [
            { 'header' => 'Type',  dataIndex => 'type', flex  => 1 },
            { 'header' => 'Min',   dataIndex => 'min', width => 60, align => 'right', xtype => 'numbercolumn',  format => '0.00s' },
            { 'header' => 'Max',   dataIndex => 'max', width => 60,  align => 'right', xtype => 'numbercolumn', format => '0.00s' },
            { 'header' => 'Avg',   dataIndex => 'avg', width => 60,  align => 'right', xtype => 'numbercolumn', format => '0.00s' },
        ],
        data    => [
            { type => 'Service Check Execution Time', min => $data->{'services_execution_time_min'}, max => $data->{'services_execution_time_max'}, avg => $data->{'services_execution_time_max'} },
            { type => 'Service Check Latency',        min => $data->{'services_latency_min'},        max => $data->{'services_latency_max'},        avg => $data->{'services_latency_avg'} },
            { type => 'Host Check Execution Time',    min => $data->{'hosts_execution_time_min'},    max => $data->{'hosts_execution_time_max'},    avg => $data->{'hosts_execution_time_avg'} },
            { type => 'Host Check Latency',           min => $data->{'hosts_latency_min'},           max => $data->{'hosts_latency_max'},           avg => $data->{'hosts_latency_avg'} },
        ]
    };

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _stats_gearman {
    my($self, $c) = @_;

    my $host = 'localhost';
    my $port = 4730;
    if(defined $c->request->parameters->{'server'}) {
        ($host,$port) = split(/:/mx, $c->request->parameters->{'server'}, 2);
    }

    my $handle = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port,
    )
    or do { warn "can't connect to port $port on $host: $!"; return; };
    $handle->autoflush(1);

    print $handle "status\n";

    my $data = {};

    while ( defined( my $line = <$handle> ) ) {
        chomp($line);
        my($name,$total,$running,$worker) = split(/\t/mx, $line);
        next if $name eq 'dummy';
        if(defined $worker) {
            my $stat = {
                'name'      => $name,
                'worker'    => int($worker),
                'running'   => int($running),
                'waiting'   => int($total - $running),
            };
            $data->{$name} = $stat;
        }
        last if $line eq '.';
    }
    CORE::close($handle);


    $c->stash->{'json'} = $data;

    return $c->forward('Thruk::View::JSON');
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2012, <sven@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
