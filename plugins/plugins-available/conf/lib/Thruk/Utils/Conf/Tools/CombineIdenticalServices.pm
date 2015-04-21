package Thruk::Utils::Conf::Tools::CombineIdenticalServices;

use strict;
use warnings;
use Storable qw/dclone/;
use Digest::MD5 qw/md5_hex/;
use Encode qw/encode_utf8/;
use Thruk::Utils::Conf;

=head1 NAME

Thruk::Utils::Conf::Tools::CombineIdenticalServices.pm - Tool to combine identical services

=head1 DESCRIPTION

Tool to combine identical services

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category    => 'Cleanup',
        link        => 'Combine Identical Services',
        title       => 'Combine Identical Services',
        description => 'Merges services which are identical except hosts/hostgroups',
        fixlink     => 'merge',
    };
    bless($self, $class);
    return($self);
}

##########################################################

=head2 get_list($c, $ignores)

returns list of potential objects to cleanup

=cut
sub get_list {
    my($self, $c, $ignores) = @_;

    my $uniq_services = {};
    for my $obj (@{$c->{'obj_db'}->get_objects_by_type('service')}) {
        my $conf = dclone($obj->{'conf'});
        delete $conf->{'host_name'};
        delete $conf->{'hostgroup_name'};
        my $hash = _make_hash($conf);
        $uniq_services->{$hash} = [] unless defined $uniq_services->{$hash};
        push @{$uniq_services->{$hash}}, $obj->get_id();
    }

    my $result = [];
    for my $hash (keys %{$uniq_services}) {
        if(scalar @{$uniq_services->{$hash}} > 1) {
            my $obj = $c->{'obj_db'}->get_object_by_id($uniq_services->{$hash}->[0]);
            push @{$result}, {
                ident      => $hash,
                id         => $obj->get_id(),
                name       => $obj->get_name(),
                type       => $obj->get_type(),
                obj        => $obj,
                message    => 'could merge '.scalar @{$uniq_services->{$hash}}.' services',
                cleanable  => 1,
                merge      => $uniq_services->{$hash},
            };
        }
    }
    return(Thruk::Utils::Conf::clean_from_tool_ignores($result, $ignores));
}

##########################################################

=head2 cleanup

cleanup this object

=cut
sub cleanup {
    my($self, $c, $ident, $ignores) = @_;
    my $list = $self->get_list($c, $ignores);
    for my $data (@{$list}) {
        next unless($ident eq 'all' || $data->{'ident'} eq $ident);
        my $master_service = $data->{'obj'};
        my $master_id      = $data->{'id'};
        my $master_conf    = dclone($master_service->{'conf'});
        $master_conf->{'host_name'}      = [] unless defined $master_conf->{'host_name'};
        $master_conf->{'hostgroup_name'} = [] unless defined $master_conf->{'hostgroup_name'};
        for my $merge_id (@{$data->{'merge'}}) {
            next if $merge_id eq $master_id;
            my $merge_obj = $c->{'obj_db'}->get_object_by_id($merge_id);
            push @{$master_conf->{'host_name'}},      @{$merge_obj->{'conf'}->{'host_name'}}      if $merge_obj->{'conf'}->{'host_name'};
            push @{$master_conf->{'hostgroup_name'}}, @{$merge_obj->{'conf'}->{'hostgroup_name'}} if $merge_obj->{'conf'}->{'hostgroup_name'};
            $c->{'obj_db'}->delete_object($merge_obj);
        }
        delete $master_conf->{'host_name'}      if scalar @{$master_conf->{'host_name'}}      == 0;
        delete $master_conf->{'hostgroup_name'} if scalar @{$master_conf->{'hostgroup_name'}} == 0;
        $c->{'obj_db'}->update_object($master_service, $master_conf, join("\n", @{$master_service->{'comments'}}));
    }
    return;
}

##########################################################
sub _make_hash {
    my($conf) = @_;
    my $string = "";
    for my $attr (sort keys %{$conf}) {
        $string .= ";" if $string;
        if(ref $conf->{$attr} eq '') {
            $string .= $attr.'='.$conf->{$attr};
        } else {
            $string .= $attr.'='.join(',', @{$conf->{$attr}});
        }
    }
    return(md5_hex(encode_utf8($string)));
}
##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
