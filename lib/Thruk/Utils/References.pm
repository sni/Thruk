package Thruk::Utils::References;

=head1 NAME

Thruk::Utils::References - Gather objects references by name

=cut

use warnings;
use strict;
use Thruk::Utils::RecurringDowntimes;

##############################################

=head1 METHODS

=head2 get_host_matches

    returns all matches for given hostname

=cut
sub get_host_matches {
    my($c, $peer_key, $config_backends, $res, $host_name) = @_;

    # find by livestatus
    _add_livestatus_matches($c, $peer_key, 'host', $res, $host_name);

    # get host from config tool
    _add_config_tool_matches($c, $peer_key, 'host', $config_backends, $res, $host_name);

    # get host from business processes
    _add_bp_matches($c, $peer_key, 'host', $res, $host_name);

    # get host from reports
    _add_report_matches($c, $peer_key, 'host', $res, $host_name);

    # get host from panorama dashboards
    _add_panorama_matches($c, $peer_key, 'host', $res, $host_name);

    # get host from recurring downtimes
    _add_recurring_downtime_matches($c, $peer_key, 'host', $res, $host_name);

    return;
}

##############################################

=head2 get_hostgroup_matches

    returns all matches for given hostgroup

=cut
sub get_hostgroup_matches {
    my($c, $peer_key, $config_backends, $res, $name) = @_;

    # find by livestatus
    _add_livestatus_matches($c, $peer_key, 'hostgroup', $res, $name);

    # get hostgroup from config tool
    _add_config_tool_matches($c, $peer_key, 'hostgroup', $config_backends, $res, $name);

    # get hostgroup from business processes
    _add_bp_matches($c, $peer_key, 'hostgroup', $res, $name);

    # get hostgroup from reports
    _add_report_matches($c, $peer_key, 'hostgroup', $res, $name);

    # get hostgroup from panorama dashboards
    _add_panorama_matches($c, $peer_key, 'hostgroup', $res, $name);

    # get hostgroup from recurring downtimes
    _add_recurring_downtime_matches($c, $peer_key, 'hostgroup', $res, $name);

    return;
}

##############################################

=head2 get_service_matches

    returns all matches for given service

=cut
sub get_service_matches {
    my($c, $peer_key, $config_backends, $res, $host_name, $description) = @_;

    # find by livestatus
    _add_livestatus_matches($c, $peer_key, 'service', $res, $description, $host_name);

    # get service from config tool
    _add_config_tool_matches($c, $peer_key, 'service', $config_backends, $res, $description, $host_name);

    # get service from business processes
    _add_bp_matches($c, $peer_key, 'service', $res, $description, $host_name);

    # get service from reports
    _add_report_matches($c, $peer_key, 'service', $res, $description, $host_name);

    # get service from panorama dashboards
    _add_panorama_matches($c, $peer_key, 'service', $res, $description, $host_name);

    # get service from recurring downtimes
    _add_recurring_downtime_matches($c, $peer_key, 'service', $res, $description, $host_name);

    return;
}

##############################################

=head2 get_servicegroup_matches

    returns all matches for given servicegroup

=cut
sub get_servicegroup_matches {
    my($c, $peer_key, $config_backends, $res, $name) = @_;

    # find by livestatus
    _add_livestatus_matches($c, $peer_key, 'servicegroup', $res, $name);

    # get servicegroup from config tool
    _add_config_tool_matches($c, $peer_key, 'servicegroup', $config_backends, $res, $name);

    # get servicegroup from business processes
    _add_bp_matches($c, $peer_key, 'servicegroup', $res, $name);

    # get servicegroup from reports
    _add_report_matches($c, $peer_key, 'servicegroup', $res, $name);

    # get servicegroup from panorama dashboards
    _add_panorama_matches($c, $peer_key, 'servicegroup', $res, $name);

    # get servicegroup from recurring downtimes
    _add_recurring_downtime_matches($c, $peer_key, 'servicegroup', $res, $name);

    return;
}

##############################################

=head2 get_contact_matches

    returns all matches for given contact

=cut
sub get_contact_matches {
    my($c, $peer_key, $config_backends, $res, $name) = @_;

    # find by livestatus
    _add_livestatus_matches($c, $peer_key, 'contact', $res, $name);

    # get contact from config tool
    _add_config_tool_matches($c, $peer_key, 'contact', $config_backends, $res, $name);

    # get contact from business processes
    _add_bp_matches($c, $peer_key, 'contact', $res, $name);

    # get contacts from reports
    _add_report_matches($c, $peer_key, 'contact', $res, $name);

    # get contact from panorama dashboards
    _add_panorama_matches($c, $peer_key, 'contact', $res, $name);

    for my $key (sort keys %{$c->config->{'cgi_cfg'}}) {
        my $list = Thruk::Utils::array2hash(Thruk::Utils::list([split/\s*,\s*/mx, $c->config->{'cgi_cfg'}->{$key} || '']));
        if($list->{$name}) {
            _add_res($res, $peer_key, 'cgi.cfg', {
                name    => $key,
                details => sprintf('contact is listed as %s in the cgi.cfg', $key),
                link    => 'conf.cgi?sub=users&action=change&data.username='.$name,
            });
        }
    }

    return;
}

##############################################
sub _add_res {
    my($res, $peer_key, $cat, $entry) = @_;
    $res->{$peer_key}->{$cat} = [] unless $res->{$peer_key}->{$cat};
    push @{$res->{$peer_key}->{$cat}}, $entry;
    return($res);
}

##############################################
sub _add_livestatus_matches {
    my($c, $peer_key, $type, $res, $name, $name2) = @_;
    my $matches;
    eval {
        if($type eq 'host') {
            $matches = $c->{'db'}->get_hosts(filter => [{ name => $name }], backend => [$peer_key]);
        }
        elsif($type eq 'hostgroup') {
            $matches = $c->{'db'}->get_hostgroups(filter => [{ name => $name }], backend => [$peer_key]);
        }
        elsif($type eq 'service') {
            $matches = $c->{'db'}->get_services(filter => [{ host_name => $name2, description => $name }], backend => [$peer_key]);
        }
        elsif($type eq 'servicegroup') {
            $matches = $c->{'db'}->get_hostgroups(filter => [{ name => $name }], backend => [$peer_key]);
        }
        elsif($type eq 'contact') {
            $matches = $c->{'db'}->get_contacts(filter => [{ name => $name }], backend => [$peer_key]);
        }
    };
    if($matches) {
        for my $m (@{$matches}) {
            if($type eq 'service') {
                _add_res($res, $peer_key, 'Livestatus', {
                    name    => $m->{'description'},
                    details => $type.' found in the current running core configuration' },
                    link    => 'extinfo.cgi?type=2&host='.$name2.'&service='.$name,
                );
            } else {
                _add_res($res, $peer_key, 'Livestatus', {
                    name    => $m->{'name'},
                    details => $type.' found in the current running core configuration' },
                    link    => $type eq 'host' ? 'extinfo.cgi?type=1&host='.$name : 'conf.cgi?sub=users&action=change&data.username='.$name,
                );
            }
        }
    }
    return;
}

##############################################
sub _add_config_tool_matches {
    my($c, $peer_key, $type, $config_backends, $res, $name, $name2) = @_;
    return unless ($c->config->{'use_feature_configtool'} && $config_backends->{$peer_key});

    $c->stash->{'param_backend'} = $peer_key;
    Thruk::Utils::Conf::set_object_model($c) or die("Failed to set objects model. Object configuration enabled?");
    my $objects;
    if($type eq 'service') {
        $objects = $c->{'obj_db'}->get_objects_by_name('service', $name, 0, 'ho:'.$name2);
    } else {
        $objects = $c->{'obj_db'}->get_objects_by_name($type, $name);
    }
    if($objects) {
        for my $o (@{$objects}) {
            _add_res($res, $peer_key, 'Configuration', {
                name    => $o->get_primary_name() || $o->get_name(),
                details => sprintf('%s found in the filesystem: %s:%d', $type, $o->{'file'}->{'display'}, $o->{'line'}) },
                link    => 'conf.cgi?sub=objects&data.id='.$o->{'id'},
            );
            _add_config_tool_refs($c, $res, $peer_key, $o);
        }
    }
    return;
}

##############################################
sub _add_config_tool_refs {
    my($c, $res, $peer_key, $obj) = @_;

    # list references
    my $refs = $c->{'obj_db'}->get_references($obj);
    for my $t (sort keys %{$refs}) {
        for my $id (sort keys %{$refs->{$t}}) {
            my $r = $c->{'obj_db'}->get_object_by_id($id);
            _add_res($res, $peer_key, 'Configuration', {
                name    => $r->get_primary_name() || $r->get_name(),
                details => sprintf('referenced in %s \'%s\' at %s:%d',
                                $t,
                                $r->get_primary_name() || $r->get_name(),
                                $r->{'file'}->{'display'},
                                $r->{'line'},
                            ),
                link    => 'conf.cgi?sub=objects&data.id='.$id,
            });
        }
    }
    return;
}

##############################################
sub _add_bp_matches {
    my($c, $peer_key, $type, $res, $name, $name2) = @_;
    return unless $c->config->{'use_feature_bp'};

    require Thruk::BP::Utils;
    my $bps = Thruk::BP::Utils::load_bp_data($c);

    for my $bp (@{$bps}) {
        # check direct node matches
        my $found_direct = 0;
        for my $n (@{$bp->{'nodes'}}) {
            if($type eq 'service' && $n->{'host'} eq $name2 && $n->{'service'} eq $name) {
                $found_direct++;
                _add_res($res, $peer_key, 'Business Process', {
                    name    => $bp->{'name'},
                    details => sprintf('referenced in business process node \'%s\' service',
                                    $n->{'label'},
                                ),
                    link    => 'bp.cgi?action=details&bp='.$bp->{'id'}.'&node='.$n->{'id'},
                });
            }
             elsif($n->{$type} eq $name) {
                $found_direct++;
                _add_res($res, $peer_key, 'Business Process', {
                    name    => $bp->{'name'},
                    details => sprintf('referenced in business process node \'%s\' %s',
                                    $n->{'label'},
                                    $type,
                                ),
                    link    => 'bp.cgi?action=details&bp='.$bp->{'id'}.'&node='.$n->{'id'},
                });
            }

            if($type eq 'contact' && $n->{'contacts'}) {
                for my $contact (@{$n->{'contacts'}}) {
                    if($contact eq $name) {
                        $found_direct++;
                        _add_res($res, $peer_key, 'Business Process', {
                            name    => $bp->{'name'},
                            details => sprintf('referenced in business process node \'%s\' contacts',
                                            $n->{'label'},
                                        ),
                            link    => 'bp.cgi?action=details&bp='.$bp->{'id'}.'&node='.$n->{'id'},
                        });
                    }
                }
            }
        }

        # search livedata
        if(!$found_direct && ($type eq 'host' || $type eq 'service')) {
            my $livedata = $bp->bulk_fetch_live_data($c);
            if(
                ($type eq 'host'    && ($livedata->{'hosts'}->{$name} || $livedata->{'services'}->{$name}))
                || ($type eq 'service' && $livedata->{'services'}->{$name2}->{$name})
                || ($type eq 'hostgroup' && $livedata->{'hostgroups'}->{$name})
                || ($type eq 'servicegroup' && $livedata->{'servicegroups'}->{$name})
            ) {
                _add_res($res, $peer_key, 'Business Process', {
                    name    => $bp->{'name'},
                    details => sprintf('referenced in business process \'%s\' livestatus data',
                                    $bp->{'name'},
                                ),
                    link    => 'bp.cgi?action=details&bp='.$bp->{'id'},
                });
            }
        }
    }

    return;
}

##############################################
sub _add_report_matches {
    my($c, $peer_key, $type, $res, $name, $name2) = @_;
    return unless $c->config->{'use_feature_reports'};

    require Thruk::Utils::Reports;
    my $reports = Thruk::Utils::Reports::get_report_list($c, 1);
    for my $r (@{$reports}) {
        my $hosts         = Thruk::Utils::array2hash(Thruk::Utils::list([split/\s*,\s*/mx, $r->{'params'}->{'host'} || '']));
        my $hostgroups    = Thruk::Utils::array2hash(Thruk::Utils::list([split/\s*,\s*/mx, $r->{'params'}->{'hostgroup'} || '']));
        my $services      = Thruk::Utils::array2hash(Thruk::Utils::list([split/\s*,\s*/mx, $r->{'params'}->{'service'} || '']));
        my $servicegroups = Thruk::Utils::array2hash(Thruk::Utils::list([split/\s*,\s*/mx, $r->{'params'}->{'servicegroup'} || '']));
        if(
               ($type eq 'host' && $hosts->{$name})
            || ($type eq 'hostgroup' && $hostgroups->{$name})
            || ($type eq 'service' && $hosts->{$name2} && $services->{$name})
            || ($type eq 'servicegroup' && $servicegroups->{$name})
         ) {
            _add_res($res, $peer_key, 'Reports', {
                name    => $r->{'name'},
                details => sprintf('referenced in report \'%s\' '.$type.'s',
                                $r->{'name'},
                            ),
                link    => 'reports2.cgi?report='.$r->{'nr'}.'&action=list',
            });
        }
        if($type eq 'contact' && $r->{'user'} eq $name) {
            _add_res($res, $peer_key, 'Reports', {
                name    => $r->{'name'},
                details => sprintf('contact owns report \'%s\'',
                                $r->{'name'},
                            ),
                link    => 'reports2.cgi?report='.$r->{'nr'}.'&action=list',
            });
        }
    }

    return;
}

##############################################
sub _add_panorama_matches {
    my($c, $peer_key, $type, $res, $name, $name2) = @_;
    return unless $c->config->{'use_feature_panorama'};

    require Thruk::Utils::Panorama;
    $c->stash->{'is_admin'} = 1;
    $c->{'panorama_var'}    = '';
    my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, 'all');
    for my $d (@{$dashboards}) {
        $d  = Thruk::Utils::Panorama::load_dashboard($c, $d->{'nr'});

        for my $key (sort keys %{$d}) {
            next unless $key =~ m/^tabpan\-/mx;
            next unless(ref $d->{$key} eq 'HASH' && $d->{$key}->{'xdata'} && $d->{$key}->{'xdata'}->{'general'});

            if($type eq 'service') {
                if(   $d->{$key}->{'xdata'}->{'general'}->{'host'} && $d->{$key}->{'xdata'}->{'general'}->{'host'} eq $name2
                   && $d->{$key}->{'xdata'}->{'general'}->{'service'} && $d->{$key}->{'xdata'}->{'general'}->{'service'} eq $name) {
                    _add_res($res, $peer_key, 'Panorama', {
                        name    => $d->{'tab'}->{'xdata'}->{'title'},
                        details => sprintf('service referenced in dashboard \'%s\'',
                                        $d->{'tab'}->{'xdata'}->{'title'},
                                    ),
                        link    => 'panorama.cgi?map='.$d->{'nr'},
                    });
                }
            } else {
                if($d->{$key}->{'xdata'}->{'general'}->{$type} && $d->{$key}->{'xdata'}->{'general'}->{$type} eq $name) {
                    _add_res($res, $peer_key, 'Panorama', {
                        name    => $d->{'tab'}->{'xdata'}->{'title'},
                        details => sprintf('%s referenced in dashboard \'%s\'',
                                        $type,
                                        $d->{'tab'}->{'xdata'}->{'title'},
                                    ),
                        link    => 'panorama.cgi?map='.$d->{'nr'},
                    });
                }
            }
        }

        if($type eq 'contact' && $d->{'user'} eq $name) {
            _add_res($res, $peer_key, 'Panorama', {
                name    => $d->{'tab'}->{'xdata'}->{'title'},
                details => sprintf('contact owns dashboard \'%s\'',
                                $d->{'tab'}->{'xdata'}->{'title'},
                            ),
                link    => 'panorama.cgi?map='.$d->{'nr'},
            });
        }
    }

    return;
}

##############################################
sub _add_recurring_downtime_matches {
    my($c, $peer_key, $type, $res, $name, $name2) = @_;

    if($type eq 'host') {
        my $downtimes = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 0, $name);
        for my $d (@{$downtimes}) {
            _add_res($res, $peer_key, 'Recurring Downtime', {
                name    => $d->{'comment'},
                details => sprintf('host listed in recurring downtime \'%s\'',
                                $d->{'comment'},
                            ),
                link    => 'extinfo.cgi?type=6&recurring=edit&nr='.$d->{'file'},
            });
        }
    }
    elsif($type eq 'service') {
        my $downtimes = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 0, $name2, $name);
        for my $d (@{$downtimes}) {
            _add_res($res, $peer_key, 'Recurring Downtime', {
                name    => $d->{'comment'},
                details => sprintf('service listed in recurring downtime \'%s\'',
                                $d->{'comment'},
                            ),
                link    => 'extinfo.cgi?type=6&recurring=edit&nr='.$d->{'file'},
            });
        }
    } else {
        my $downtimes = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 0);
        for my $d (@{$downtimes}) {
            my $list = Thruk::Utils::array2hash($d->{$type} || []);
            next unless $list->{$name};
            _add_res($res, $peer_key, 'Recurring Downtime', {
                name    => $d->{'comment'},
                details => sprintf('%s listed in recurring downtime \'%s\'',
                                $type,
                                $d->{'comment'},
                            ),
                link    => 'extinfo.cgi?type=6&recurring=edit&nr='.$d->{'file'},
            });
        }
    }

    return;
}

##############################################

1;
