package Thruk::Utils::RecurringDowntimes;

use strict;
use warnings;
use Thruk::Utils;
use Thruk::Utils::Auth;
use File::Copy qw/move/;

=head1 NAME

Thruk::Utils::RecurringDowntimes - Utils for Recurring Downtimes

=head1 DESCRIPTION

Utils for Recurring Downtimes

=head1 METHODS

=cut

=head2 index

=cut

##########################################################

=head2 update_cron_file

    update_cron_file($c)

update downtimes cron

=cut
sub update_cron_file {
    my($c) = @_;

    # gather cron entries for all recurring downtimes
    my $combined_entries = {};
    my $downtimes = get_downtimes_list($c, 0, 1);
    for my $d (@{$downtimes}) {
        next unless defined $d->{'schedule'};
        next unless scalar @{$d->{'schedule'}} > 0;
        for my $cr (@{$d->{'schedule'}}) {
            my $time = Thruk::Utils::get_cron_time_entry($cr);
            $combined_entries->{$time} = [] unless $combined_entries->{$time};
            push @{$combined_entries->{$time}}, $d->{'file'};
        }
    }
    my $cron_entries = [];
    for my $time (sort keys %{$combined_entries}) {
        my $cmd = _get_downtime_cmd($c, $combined_entries->{$time});
        push @{$cron_entries}, [$time, $cmd];
    }

    Thruk::Utils::update_cron_file($c, 'downtimes', $cron_entries);
    return;
}

##########################################################

=head2 get_downtimes_list

    get_downtimes_list($c, $auth, $backendfilter, $host, $service)

return list of downtimes

  auth)
    0)  no authentication used, list all downtimes
    1)  use authentication (default)
  backendfilter)
    0)  list downtimes for selected backends only (default)
    1)  list downtimes for all backends

=cut
sub get_downtimes_list {
    my($c, $auth, $backendfilter, $host, $service) = @_;
    $auth          = 1 unless defined $auth;
    $backendfilter = 0 unless defined $backendfilter;

    return [] unless $c->config->{'use_feature_recurring_downtime'};

    my @hostfilter    = $auth ? (Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' )) : [];
    my @servicefilter = $auth ? (Thruk::Utils::Auth::get_auth_filter( $c, 'services' )) : [];

    # skip further auth tests if this user has admins permission anyway
    if($auth) {
        $auth = 0 if(!$hostfilter[0] && !$servicefilter[0]);
    }

    # host and service filter
    push @servicefilter, {  host_name => $host }     if $host;
    push @servicefilter, { description => $service } if $service;
    push @hostfilter, { name => $host }              if $host;

    my($hosts, $services, $hostgroups, $servicegroups) = ({},{},{},{});
    if($host || $service) {
        my $host_data    = $c->{'db'}->get_hosts(filter => \@hostfilter,    columns => [qw/name groups/]);
        $hosts    = Thruk::Utils::array2hash($host_data, 'name');
        undef $host_data;
        my $service_data = $c->{'db'}->get_services(filter => \@servicefilter, columns => [qw/host_name description host_groups groups/] );
        $services = Thruk::Utils::array2hash($service_data,  'host_name', 'description');
        undef $service_data;
    }

    if($service) {
        $hostgroups    = Thruk::Utils::array2hash($services->{$host}->{$service}->{'host_groups'});
        $servicegroups = Thruk::Utils::array2hash($services->{$host}->{$service}->{'groups'});
    }
    elsif($host) {
        $hostgroups    = Thruk::Utils::array2hash($hosts->{$host}->{'groups'});
    }

    # which objects is the user allowed to see
    my($authhosts, $authservices, $authhostgroups, $authservicegroups) = ({},{},{},{});
    if($auth) {
        my $host_data = $c->{'db'}->get_hosts(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'hosts')], columns => [qw/name groups/]);
        for my $h (@{$host_data}) {
            $authhosts->{$h->{'name'}} = 1;
            for my $g (@{$h->{'groups'}}) {
                $authhostgroups->{$g} = 1;
            }
        }
        undef $host_data;
        my $service_data = $c->{'db'}->get_services(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'services')], columns => [qw/host_name description host_groups groups/]);
        for my $s (@{$service_data}) {
            $authservices->{$s->{'host_name'}}->{$s->{'description'}} = 1;
            for my $g (@{$s->{'host_groups'}}) {
                $authhostgroups->{$g} = 1;
            }
            for my $g (@{$s->{'groups'}}) {
                $authservicegroups->{$g} = 1;
            }
        }
    }

    my $default_rd         = get_default_recurring_downtime($c, $host, $service);
    my $downtimes          = [];
    my $reinstall_required = 0;
    my @files = glob($c->config->{'var_path'}.'/downtimes/*.tsk');
    for my $dfile (@files) {
        next unless -f $dfile;
        $reinstall_required++ if $dfile !~ m/\/\d+\.tsk$/mx;
        my $d = read_downtime($c, $dfile, $default_rd, $authhosts, $authservices, $authhostgroups, $authservicegroups, $host, $service, $auth, $backendfilter, $hosts, $services, $hostgroups, $servicegroups);
        push @{$downtimes}, $d if $d;
    }
    update_cron_file($c) if $reinstall_required;

    # sort by target & host & service
    @{$downtimes} = sort {    $a->{'target'}                         cmp $b->{'target'}
                           or (lc join(',', @{$a->{'host'}})         cmp lc join(',', @{$b->{'host'}}))
                           or lc $a->{'service'}                     cmp lc $b->{'service'}
                           or (lc join(',', @{$a->{'hostgroup'}})    cmp lc join(',', @{$b->{'hostgroup'}}))
                           or (lc join(',', @{$a->{'servicegroup'}}) cmp lc join(',', @{$b->{'servicegroup'}}))
                         } @{$downtimes};

    return $downtimes;
}

##########################################################

=head2 check_downtime

    check_downtime($c, $rd, $file)

check downtime for expired hosts or services

=cut
sub check_downtime {
    my($c, $rd, $file) = @_;
    require Thruk::Utils::SelfCheck;
    my($err, $detail) = (0, "");
    eval {
        ($err, $detail) = Thruk::Utils::SelfCheck::check_recurring_downtime($c, $rd, $file);
    };
    if($@) {
        $err++;
        $detail = "Could not check recurring downtimes from $file: ".$@;
    }
    if($err) {
        $rd->{'error'} = $detail;
        Thruk::Utils::write_data_file($file, $rd);
    }
    if($err == 0 && $rd->{'error'}) {
        delete $rd->{'error'};
        Thruk::Utils::write_data_file($file, $rd);
    }
    return($err, $detail);
}

##########################################################

=head2 read_downtime

    read_downtime($c, $dfile, $default_rd, $authhosts, $authservices, $authhostgroups, $authservicegroups, $host, $service, $auth, $backendfilter, $hosts, $services, $hostgroups, $servicegroups)

return single downtime

=cut
sub read_downtime {
    my($c, $dfile, $default_rd, $authhosts, $authservices, $authhostgroups, $authservicegroups, $host, $service, $auth, $backendfilter, $hosts, $services, $hostgroups, $servicegroups) = @_;

    # move file to new file layout
    if($dfile !~ m/\/\d+\.tsk$/mx) {
        my $newfile = get_data_file_name($c);
        move($dfile, $newfile);
        $dfile = $newfile;
    }

    my $d = Thruk::Utils::read_data_file($dfile);
    $d->{'file'} = $dfile;
    $d->{'file'} =~ s|^.*/||gmx;
    $d->{'file'} =~ s|\.tsk$||gmx;

    # set fallback target
    if(!$d->{'target'}) {
        $d->{'target'} = 'host';
        $d->{'target'} = 'service' if $d->{'service'};
    }

    # convert attributes to array
    for my $t (qw/host hostgroup service servicegroup/) {
        $d->{$t} = [] unless defined $d->{$t};
        $d->{$t} = [split/\s*,\s*/mx,$d->{$t}] unless ref $d->{$t} eq 'ARRAY';
        $d->{$t} = [sort @{$d->{$t}}];
    }

    # apply auth filter
    if($auth) {
        if($d->{'target'} eq 'host') {
            for my $hst (@{$d->{'host'}}) {
                return unless defined $authhosts->{$hst};
            }
        }
        elsif($d->{'target'} eq 'service') {
            for my $hst (@{$d->{'host'}}) {
                for my $svc (@{$d->{'service'}}) {
                    return unless defined $authservices->{$hst}->{$svc};
                }
            }
        }
        elsif($d->{'target'} eq 'servicegroup') {
            for my $grp (@{$d->{'servicegroup'}}) {
                return unless defined $authservicegroups->{$grp};
            }
        }
        elsif($d->{'target'} eq 'hostgroup') {
            for my $grp (@{$d->{'hostgroup'}}) {
                return unless defined $authhostgroups->{$grp};
            }
        }
    }

    # other filter?
    if($host) {
        my $found = 0;
        if($d->{'target'} eq 'host') {
            for my $hst (@{$d->{'host'}}) {
                if(defined $hosts->{$hst}) {
                    $found++;
                    last;
                }
            }
        }
        elsif($d->{'target'} eq 'service') {
            return if $host && !$service;
            for my $hst (@{$d->{'host'}}) {
                for my $svc (@{$d->{'service'}}) {
                    if(defined $services->{$hst}->{$svc}) {
                        $found++;
                        last;
                    }
                }
            }
        }
        elsif($d->{'target'} eq 'servicegroup') {
            return if $host && !$service;
            for my $grp (@{$d->{'servicegroup'}}) {
                if(defined $servicegroups->{$grp}) {
                    $found++;
                    last;
                }
            }
        }
        elsif($d->{'target'} eq 'hostgroup') {
            for my $grp (@{$d->{'hostgroup'}}) {
                if(defined $hostgroups->{$grp}) {
                    $found++;
                    last;
                }
            }
        }
        return unless $found;
    }

    # backend filter?
    my $backends = Thruk::Utils::list($d->{'backends'});
    if(!$backendfilter && scalar @{$backends} > 0) {
        my $found = 0;
        $found = 1 if $backends->[0] eq ''; # no backends at all
        for my $b (@{$backends}) {
            next unless $c->stash->{'backend_detail'}->{$b};
            $found = 1 if $c->stash->{'backend_detail'}->{$b}->{'disabled'} != 2;
        }
        return unless $found;
    }

    # set some defaults
    for my $key (keys %{$default_rd}) {
        $d->{$key} = $default_rd->{$key} unless defined $d->{$key};
    }
    return $d;
}

##########################################################

=head2 check_downtime_permissions

    check_downtime_permissions($c, $downtime)

 returns:
   0 - no permission
   1 - read-only
   2 - write

=cut
sub check_downtime_permissions {
    my($c, $d) = @_;
    if(!$d->{'target'}) {
        $d->{'target'} = 'host';
        $d->{'target'} = 'service' if $d->{'service'};
    }
    $d->{'host'}         = [$d->{'host'}]         unless ref $d->{'host'}         eq 'ARRAY';
    $d->{'hostgroup'}    = [$d->{'hostgroup'}]    unless ref $d->{'hostgroup'}    eq 'ARRAY';
    $d->{'servicegroup'} = [$d->{'servicegroup'}] unless ref $d->{'servicegroup'} eq 'ARRAY';
    my $write = 0;
    my $read  = 0;
    if($d->{'target'} eq 'host') {
        for my $hst (@{$d->{'host'}}) {
            $write++ if $c->check_cmd_permissions('host', $hst);
            $read++  if $c->check_permissions('host', $hst);
        }
        return 2 if $write == scalar @{$d->{'host'}};
        return 1 if $read  == scalar @{$d->{'host'}};
    }
    elsif($d->{'target'} eq 'hostgroup') {
        for my $grp (@{$d->{'hostgroup'}}) {
            $write++ if $c->check_cmd_permissions('hostgroup', $grp);
            $read++  if $c->check_permissions('hostgroup', $grp);
        }
        return 2 if $write == scalar @{$d->{'hostgroup'}};
        return 1 if $read  == scalar @{$d->{'hostgroup'}};
    }
    elsif($d->{'target'} eq 'service') {
        for my $hst (@{$d->{'host'}}) {
            $write++ if $c->check_cmd_permissions('service', $d->{'service'}, $hst);
            $read++  if $c->check_permissions('service', $d->{'service'}, $hst);
        }
        return 2 if $write == scalar @{$d->{'host'}}; # number must match of hosts, because for services only hosts are lists
        return 1 if $read  == scalar @{$d->{'host'}};
    }
    elsif($d->{'target'} eq 'servicegroup') {
        for my $grp (@{$d->{'servicegroup'}}) {
            $write++ if $c->check_cmd_permissions('servicegroup', $grp);
            $read++  if $c->check_permissions('servicegroup', $grp);
        }
        return 2 if $write == scalar @{$d->{'servicegroup'}};
        return 1 if $read  == scalar @{$d->{'servicegroup'}};
    }
    return 0;
}

##########################################################

=head2 get_default_recurring_downtime

    get_default_recurring_downtime($c, $host, $service, $hostgroup, $servicegroup)

return default recurring downtime

=cut
sub get_default_recurring_downtime {
    my($c, $host, $service, $hostgroup, $servicegroup) = @_;
    my $default_rd = {
            target       => 'service',
            host         => [],
            service      => $service,
            servicegroup => [],
            hostgroup    => [],
            backends     => [],
            schedule     => [],
            duration     => 120,
            comment      => 'automatic downtime',
            childoptions => 0,
            fixed        => 1,
            flex_range   => 720,
    };
    push @{$default_rd->{'host'}},         $host         if $host;
    push @{$default_rd->{'servicegroup'}}, $servicegroup if $servicegroup;
    push @{$default_rd->{'hostgroup'}},    $hostgroup    if $hostgroup;
    if($c->req->parameters->{'backend'}) {
        $default_rd->{'backends'} = [split/\s*,\s*/mx, $c->req->parameters->{'backend'}];
    } elsif($c->{'db'}) {
        $default_rd->{'backends'} = $c->{'db'}->peer_key();
    }
    return($default_rd);
}


##########################################################

=head2 get_downtime_backends

    get_downtime_backends($c, $downtime)

return default recurring downtime

=cut
sub get_downtime_backends {
    my($c, $downtime) = @_;

    my $backends = ref $downtime->{'backends'} eq 'ARRAY' ? $downtime->{'backends'} : [$downtime->{'backends'}];
    my $choose_backends = 0;
    my $cmd_typ;
    if(scalar @{$backends} == 0 and @{$c->{'db'}->get_peers()} > 1) {
        $choose_backends = 1;
        $c->{'db'}->enable_backends();
    }
    if(!$downtime->{'target'}) {
        $downtime->{'target'} = 'host';
        $downtime->{'target'} = 'service' if $downtime->{'service'};
    }

    if($downtime->{'target'} eq 'host') {
        $cmd_typ = 55;
        if($choose_backends) {
            my $data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $downtime->{'host'} } ], columns => [qw/name/] );
            $backends = [keys %{Thruk::Utils::array2hash($data, 'peer_key')}];
        }
    }
    elsif($downtime->{'target'} eq 'service') {
        $cmd_typ = 56;
        if($choose_backends) {
            my $data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $downtime->{'host'}, 'description' => $downtime->{'service'} } ], columns => [qw/description/] );
            $backends = [keys %{Thruk::Utils::array2hash($data, 'peer_key')}];
        }
    }
    elsif($downtime->{'target'} eq 'hostgroup') {
        $cmd_typ = 84;
        if($choose_backends) {
            my $data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'groups' => { '>=' => $downtime->{'hostgroup'} }} ], columns => [qw/name/] );
            $backends = [keys %{Thruk::Utils::array2hash($data, 'peer_key')}];
        }
    }
    elsif($downtime->{'target'} eq 'servicegroup') {
        $cmd_typ = 122;
        if($choose_backends) {
            my $data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'groups' => { '>=' => $downtime->{'servicegroup'} }} ], columns => [qw/description/] );
            $backends = [keys %{Thruk::Utils::array2hash($data, 'peer_key')}];
        }
    }

    return($backends, $cmd_typ);
}

##########################################################

=head2 get_data_file_name

    get_data_file_name($c, [$nr])

return filename for data file

=cut
sub get_data_file_name {
    my($c, $nr) = @_;
    if(!defined $nr || $nr !~ m/^\d+$/mx) {
        $nr = 1;
    }

    while(-f $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk') {
        $nr++;
    }

    return $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
}

##########################################################
sub _get_downtime_cmd {
    my($c, $files, $verbose) = @_;
    # ensure proper cron.log permission
    open(my $fh, '>>', $c->config->{'var_path'}.'/cron.log');
    Thruk::Utils::IO::close($fh, $c->config->{'var_path'}.'/cron.log');
    my $log = sprintf(">/dev/null 2>>%s/cron.log", $c->config->{'var_path'});
    $log = sprintf(">>%s/cron.log 2>&1", $c->config->{'var_path'}) if $verbose;
    my $cmd = sprintf("cd %s && %s '%s downtimetask \"%s\"%s' %s",
                            $c->config->{'project_root'},
                            $c->config->{'thruk_shell'},
                            $c->config->{'thruk_bin'},
                            join('|', @{$files}),
                            $verbose ? ' -vv ' : '',
                            $log,
                    );
    return $cmd;
}

##########################################################

1;
