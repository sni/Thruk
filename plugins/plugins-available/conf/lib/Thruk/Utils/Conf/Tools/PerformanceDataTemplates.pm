package Thruk::Utils::Conf::Tools::PerformanceDataTemplates;

use warnings;
use strict;

use Thruk::Config 'noautoload';
use Thruk::Utils::Auth ();
use Thruk::Utils::Conf ();
use Thruk::Utils::IO ();

=head1 NAME

Thruk::Utils::Conf::Tools::PerformanceDataTemplates.pm - Tool to cleanup performance data templates

=head1 DESCRIPTION

Tool to clean up performance data templates

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category       => 'Templates',
        link           => 'Performance Data Templates',
        title          => 'Check Performance Data Templates',
        description    => 'Fixes common mistakes with performance data templates',
        fixlink        => 'fix',
        fix_all_serial => 1,
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

    my $pattern = "pnp";
    if($ENV{'OMD_ROOT'}) {
        my $site_config = Thruk::Config::parse_omd_site_config();
        if($site_config->{'CONFIG_PNP4NAGIOS'} eq 'off' && $site_config->{'CONFIG_NAGFLUX'} eq 'on') {
            $pattern = "-perf";
        }
    }

    my $result    = [];
    for my $type (qw/host service/) {
        my $templates = $c->{'obj_db'}->get_templates_by_type($type);
        my $perf_templates = [];
        for my $tmp (@{$templates}) {
            if($tmp->get_name =~ m/$pattern/mx) {
                push @{$perf_templates}, $tmp;
            }
        }
        if(scalar @{$perf_templates} == 0) {
            push @{$result}, {
                ident      => 'no'.$type.'template',
                id         => '',
                name       => $type.' template',
                type       => $type,
                obj        => '',
                message    => 'did not find any template matching *'.$pattern.'*, please create perf templates first.',
                cleanable  => 0,
            };
            next;
        }
        if(scalar @{$perf_templates} > 1) {
            push @{$result}, {
                ident      => 'too many'.$type.'template',
                id         => '',
                name       => $type.' template',
                type       => $type,
                obj        => '',
                message    => 'found more than one template matching *'.$pattern.'*, cannot continue.',
                cleanable  => 0,
            };
            next;
        }
        my $perf_template      = $perf_templates->[0];
        my $perf_template_name = $perf_template->get_name();
        # check the template itself
        if(!$perf_template->{'conf'}->{'action_url'}) {
            push @{$result}, {
                ident      => $type.'template_no_action_url',
                id         => $perf_template->get_id(),
                name       => $perf_template->get_name(),
                type       => $type,
                obj        => $perf_template,
                message    => 'no action_url found in perf template',
                cleanable  => 0,
            };
            next;
        }
        if(!defined $perf_template->{'conf'}->{'process_perf_data'}) {
            push @{$result}, {
                ident      => $type.'template_no_process_perf_data',
                id         => $perf_template->get_id(),
                name       => $perf_template->get_name(),
                type       => $type,
                obj        => $perf_template,
                message    => 'no process_perf_data found in perf template',
                cleanable  => 0,
            };
            next;
        }

        my $live_objects;
        if($type eq 'host') {
            my $hosts = $c->db->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' )], columns => [qw/name perf_data state has_been_checked/]);
            for my $hst (@{$hosts}) {
                $live_objects->{$hst->{'name'}} = $hst;
            }
        }
        elsif($type eq 'service') {
            my $services = $c->db->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' )], columns => [qw/host_name description perf_data state has_been_checked/]);
            for my $svc (@{$services}) {
                $live_objects->{$svc->{'host_name'}}->{$svc->{'description'}} = $svc;
            }
        } else {
            die("unimplemented: ".$type);
        }
        for my $obj (@{$c->{'obj_db'}->get_objects_by_type($type)}) {
            # skip thruk bp objects and other known generated things
            next if $obj->{'file'}->{'readonly'};
            next if $obj->{'file'}->{'path'} =~ m/\Qthruk_bp_generated.cfg\E/mx;
            next if $obj->{'file'}->{'path'} =~ m/\Qcheck_mk_objects.cfg\E/mx;

            # check if this object gathers performance data
            my $liveobj;
            if($type eq 'host') {
                next unless defined $live_objects->{$obj->get_name()};
                $liveobj = $live_objects->{$obj->get_name()};
            }
            elsif($type eq 'service') {
                # get list of hosts, hostgroups and reverse references then
                # find the first one with perfdata
                my $description = $obj->{'conf'}->{'service_description'};
                next unless $description;
                my $hosts = $c->{'obj_db'}->get_hosts_for_service($obj);
                my $first_hst;
                for my $hst_name (keys %{$hosts}) {
                    my $hst = $c->{'obj_db'}->get_object_by_id($hosts->{$hst_name});
                    $first_hst = $live_objects->{$hst_name}->{$description} unless $first_hst;
                    if($live_objects->{$hst_name}->{$description} && $live_objects->{$hst_name}->{$description}->{'perf_data'}) {
                        $liveobj = $live_objects->{$hst_name}->{$description};
                        last;
                    }
                }
                $liveobj = $first_hst unless $liveobj;
            } else {
                die("unimplemented: ".$type);
            }
            next unless $liveobj;

            # failed checks may lead to wrong assumptions
            if(!$liveobj->{'perf_data'} && $liveobj->{'state'} != 0) {
                next;
            }

            # pending checks never have performance data, ignore them
            if(!$liveobj->{has_been_checked}) {
                next;
            }

            my @skip_attributes;
            if($liveobj->{'perf_data'}) {
                # this object should use the perf template and have no action_url or process_perf_data defined by itself
                if(!$obj->{'conf'}->{'use'} || !grep(/^\Q$perf_template_name\E$/mx, @{$obj->{'conf'}->{'use'}})) {
                    my $used_templates = $obj->get_used_templates($c->{'obj_db'});
                    if(!grep(/^\Q$perf_template_name\E$/mx, @{$used_templates})) {
                        push @{$result}, {
                            ident      => $obj->get_id().'/use_perf_template',
                            id         => $obj->get_id(),
                            name       => $obj->get_name(),
                            type       => $obj->get_type(),
                            obj        => $obj,
                            message    => 'object should use the '.$perf_template_name.' template',
                            cleanable  => 1,
                            action     => 'add_template',
                            template   => $perf_template_name,
                        };
                        next;
                    }
                }
                @skip_attributes = qw/action_url process_perf_data/;
            } else {
                # this object should not use the perf template and have no process_perf_data defined by itself
                if($obj->{'conf'}->{'use'} && grep(/^\Q$perf_template_name\E$/mx, @{$obj->{'conf'}->{'use'}})) {
                    push @{$result}, {
                        ident      => $obj->get_id().'/del_perf_template',
                        id         => $obj->get_id(),
                        name       => $obj->get_name(),
                        type       => $obj->get_type(),
                        obj        => $obj,
                        message    => 'object should use not the '.$perf_template_name.' template, as it has no performance data',
                        cleanable  => 1,
                        action     => 'del_template',
                        template   => $perf_template_name,
                    };
                    next;
                }
                @skip_attributes = qw/process_perf_data/;
            }
            for my $attr (@skip_attributes) {
                if(defined $obj->{'conf'}->{$attr}) {
                    push @{$result}, {
                        ident      => $obj->get_id().'/del_'.$attr,
                        id         => $obj->get_id(),
                        name       => $obj->get_name(),
                        type       => $obj->get_type(),
                        obj        => $obj,
                        message    => 'object should not define '.$attr.' by itself',
                        cleanable  => 1,
                        action     => 'del_attr',
                        attr       => $attr,
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
    my $list = $self->get_list($c, $ignores);
    for my $data (@{$list}) {
        next unless($ident eq 'all' || $data->{'ident'} eq $ident);
        if($data->{'action'} eq 'del_attr') {
            delete $data->{'obj'}->{'conf'}->{$data->{'attr'}};
        }
        elsif($data->{'action'} eq 'add_template') {
            $data->{'obj'}->{'conf'}->{'use'} = [] unless defined $data->{'obj'}->{'conf'}->{'use'};
            unshift(@{$data->{'obj'}->{'conf'}->{'use'}}, $data->{'template'});
        }
        elsif($data->{'action'} eq 'del_template') {
            my $template_name = $data->{'template'};
            @{$data->{'obj'}->{'conf'}->{'use'}} = grep(!/^\Q$template_name\E$/mx, @{$data->{'obj'}->{'conf'}->{'use'}});
        }
        else {
            die("unknown action: ".$data->{'action'});
        }
        $c->{'obj_db'}->update_object($data->{'obj'}, Thruk::Utils::IO::dclone($data->{'obj'}->{'conf'}), join("\n", @{$data->{'obj'}->{'comments'}}));
    }
    return;
}

##########################################################

1;
