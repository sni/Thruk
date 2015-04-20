package Thruk::Utils::Conf::Tools::CheckPNPTemplates;

use strict;
use warnings;
use Thruk::Utils::Conf;

=head1 NAME

Thruk::Utils::Conf::Tools::CheckPNPTemplates.pm - Tool to cleanup pnp templates

=head1 DESCRIPTION

Tool to clean up pnp templates

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category    => 'Templates',
        link        => 'Check PNP Templates',
        title       => 'Check PNP Templates',
        description => 'Fixes common mistakes in pnp templates',
        fixlink     => 'fix',
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

    my $result    = [];
    for my $type (qw/host service/) {
        my $templates = $c->{'obj_db'}->get_templates_by_type($type);
        my $pnp_templates = [];
        for my $tmp (@{$templates}) {
            if($tmp->get_name =~ m/pnp/mx) {
                push @{$pnp_templates}, $tmp;
            }
        }
        if(scalar @{$pnp_templates} == 0) {
            push $result, {
                ident      => 'no'.$type.'template',
                id         => '',
                name       => $type.' template',
                type       => $type,
                obj        => '',
                message    => 'did not find any template matching *pnp*, please create pnp templates first.',
                cleanable  => 0,
            };
            next;
        }
        if(scalar @{$pnp_templates} > 1) {
            push $result, {
                ident      => 'too many'.$type.'template',
                id         => '',
                name       => $type.' template',
                type       => $type,
                obj        => '',
                message    => 'found more than one template matching *pnp*, cannot continue.',
                cleanable  => 0,
            };
            next;
        }
        my $pnp_template      = $pnp_templates->[0];
        my $pnp_template_name = $pnp_template->get_name();
        # check the template itself
        if(!$pnp_template->{'conf'}->{'action_url'}) {
            push $result, {
                ident      => $type.'template_no_action_url',
                id         => $pnp_template->get_id(),
                name       => $pnp_template->get_name(),
                type       => $type,
                obj        => $pnp_template,
                message    => 'no action_url found in pnp template',
                cleanable  => 0,
            };
            next;
        }
        if(!defined $pnp_template->{'conf'}->{'process_perf_data'}) {
            push $result, {
                ident      => $type.'template_no_process_perf_data',
                id         => $pnp_template->get_id(),
                name       => $pnp_template->get_name(),
                type       => $type,
                obj        => $pnp_template,
                message    => 'no process_perf_data found in pnp template',
                cleanable  => 0,
            };
            next;
        }

        my $live_objects;
        if($type eq 'host') {
            my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' )], columns => [qw/name perf_data state/]);
            for my $hst (@{$hosts}) {
                $live_objects->{$hst->{'name'}} = $hst;
            }
        }
        elsif($type eq 'service') {
            my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' )], columns => [qw/host_name description perf_data state/]);
            for my $svc (@{$services}) {
                $live_objects->{$svc->{'host_name'}}->{$svc->{'description'}} = $svc;
            }
        } else {
            die("unimplemented: ".$type);
        }
        for my $obj (@{$c->{'obj_db'}->get_objects_by_type($type)}) {
            # skip thruk bp objects
            next if $obj->{'file'}->{'path'} =~ m/\Qthruk_bp_generated.cfg\E/mx;
            next if $obj->{'file'}->{'path'} =~ m/\Qcheck_mk_objects.cfg\E/mx;

            # check if this object gathers performance data
            my $liveobj;
            if($type eq 'host') {
                next unless defined $live_objects->{$obj->get_name()};
                $liveobj = $live_objects->{$obj->get_name()};
            }
            elsif($type eq 'service') {
                next;
            } else {
                die("unimplemented: ".$type);
            }
            next unless $liveobj;

            # failed checks may lead to wrong assumptions
            if(!$liveobj->{'perf_data'} && $liveobj->{'state'} != 0) {
                next;
            }

            my @skip_attributes;
            if($liveobj->{'perf_data'}) {
                # this object should use the pnp template and have no action_url or process_perf_data defined by itself
                if(!$obj->{'conf'}->{'use'} || !grep(/^\Q$pnp_template_name\E$/mx)) {
                    # TODO: check parent templates too, might be inherited
                    push $result, {
                        ident      => $obj->get_id().';use_pnp_template',
                        id         => $obj->get_id(),
                        name       => $obj->get_name(),
                        type       => $obj->get_type(),
                        obj        => $obj,
                        message    => 'object should use the pnp template',
                        cleanable  => 1,
                    };
                    next;
                }
                @skip_attributes = qw/action_url process_perf_data/;
            } else {
                # this object should not use the pnp template and have no process_perf_data defined by itself
                if($obj->{'conf'}->{'use'} && grep(/^\Q$pnp_template_name\E$/mx)) {
                    push $result, {
                        ident      => $obj->get_id().';del_pnp_template',
                        id         => $obj->get_id(),
                        name       => $obj->get_name(),
                        type       => $obj->get_type(),
                        obj        => $obj,
                        message    => 'object should use not the pnp template, as it has no performance data',
                        cleanable  => 1,
                    };
                    next;
                }
                @skip_attributes = qw/process_perf_data/;
            }
            for my $attr (@skip_attributes) {
                if(defined $obj->{'conf'}->{$attr}) {
                    push $result, {
                        ident      => $obj->get_id().';del_'.$attr,
                        id         => $obj->get_id(),
                        name       => $obj->get_name(),
                        type       => $obj->get_type(),
                        obj        => $obj,
                        message    => 'object should not define '.$attr.' by itself',
                        cleanable  => 1,
                    };
                }
            }
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
# TODO: implement
    #my $list = $self->get_list($c, $ignores);
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
