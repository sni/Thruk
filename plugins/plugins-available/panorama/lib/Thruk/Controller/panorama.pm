package Thruk::Controller::panorama;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use JSON::XS;
use URI::Escape;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::panorama - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

# enable panorama features if this plugin is loaded
Thruk->config->{'use_feature_panorama'} = 1;

######################################

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

    if(defined $c->request->parameters->{'proxy'}) {
        return($self->_stateprovider($c));
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
            $c->log->info("panorama: removed ".$name);
            delete $data->{'panorama'}->{'state'}->{$name};
        } else {
            $c->log->info("panorama: set ".$name." to ".$self->_nice_ext_value($value));
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

=head1 AUTHOR

Sven Nierlein, 2012, <sven@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
