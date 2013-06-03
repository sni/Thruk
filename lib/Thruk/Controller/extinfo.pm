package Thruk::Controller::extinfo;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Page;

=head1 NAME

Thruk::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index : Path : Args(0) : MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    $c->stash->{title}        = 'Extended Information';
    $c->stash->{page}         = 'extinfo';
    $c->stash->{template}     = 'extinfo_type_' . $type . '.tt';

    my $infoBoxTitle;
    if( $type == 0 ) {
        $infoBoxTitle = 'Process Information';
        return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
        $self->_process_process_info_page($c);
    }
    if( $type == 1 ) {
        $infoBoxTitle = 'Host Information';
        return unless $self->_process_host_page($c);
    }
    if( $type == 2 ) {
        $infoBoxTitle = 'Service Information';
        return unless $self->_process_service_page($c);
    }
    if( $type == 3 ) {
        $infoBoxTitle = 'All Host and Service Comments';
        $self->_process_comments_page($c);
    }
    if( $type == 4 ) {
        $infoBoxTitle = 'Performance Information';
        $self->_process_perf_info_page($c);
    }
    if( $type == 5 ) {
        $infoBoxTitle = 'Hostgroup Information';
        $self->_process_hostgroup_cmd_page($c);
    }
    if( $type == 6 ) {
        if(exists $c->{'request'}->{'parameters'}->{'recurring'}) {
            $infoBoxTitle = 'Recurring Downtimes';
            $self->_process_recurring_downtimes_page($c);
        } else {
            $infoBoxTitle = 'All Host and Service Scheduled Downtime';
            $self->_process_downtimes_page($c);
        }
    }
    if( $type == 7 ) {
        $infoBoxTitle = 'Check Scheduling Queue';
        $self->_process_scheduling_page($c);
    }
    if( $type == 8 ) {
        $infoBoxTitle = 'Servicegroup Information';
        $self->_process_servicegroup_cmd_page($c);
    }

    $c->stash->{infoBoxTitle} = $infoBoxTitle;
    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################
# SUBS
##########################################################

##########################################################
# create the comments page
sub _process_comments_page {
    my( $self, $c ) = @_;
    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';

    # services
    my $svc_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_svc'}   || 1;
    my $svc_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_svc'} || 1;
    my $svc_order      = "ASC";
    $svc_order = "DESC" if $svc_sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'service_description' ], 'host name' ],
        '2' => [ [ 'service_description' ],                'service name' ],
        '3' => [ [ 'entry_time' ],                         'entry time' ],
        '4' => [ [ 'author' ],                             'author' ],
        '5' => [ [ 'comment' ],                            'comment' ],
        '6' => [ [ 'id' ],                                 'id' ],
        '7' => [ [ 'persistent' ],                         'persistent' ],
        '8' => [ [ 'entry_type' ],                         'entry_type' ],
        '9' => [ [ 'expires' ],                            'expires' ],
    };
    $svc_sortoption = 1 if !defined $sortoptions->{$svc_sortoption};
    $c->stash->{'svc_orderby'}  = $sortoptions->{$svc_sortoption}->[1];
    $c->stash->{'svc_orderdir'} = $svc_order;

    # hosts
    my $hst_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_hst'}   || 1;
    my $hst_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || 1;
    my $hst_order      = "ASC";
    $hst_order = "DESC" if $hst_sorttype == 2;
    $hst_sortoption = 1 if !defined $sortoptions->{$hst_sortoption};
    $c->stash->{'hst_orderby'}  = $sortoptions->{$hst_sortoption}->[1];
    $c->stash->{'hst_orderdir'} = $hst_order;

    $c->stash->{'hostcomments'}    = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => undef } ],
                                                               sort   => { $hst_order => $sortoptions->{$hst_sortoption}->[0] },
                                                              );
    $c->stash->{'servicecomments'} = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => { '!=' => undef } } ],
                                                               sort   => { $svc_order => $sortoptions->{$svc_sortoption}->[0] },
                                                              );

    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->res->header( 'Content-Disposition', 'attachment; filename="comments.xls"' );
        $c->stash->{'template'} = 'excel/comments.tt';
        return $c->detach('View::Excel');
    }
    if($view_mode eq 'json') {
        $c->stash->{'json'} = {
            'host'    => $c->stash->{'hostcomments'},
            'service' => $c->stash->{'servicecomments'},
        };
        return $c->detach('View::JSON');
    }
    return 1;
}

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my( $self, $c ) = @_;
    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';

    # services
    my $svc_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_svc'}   || 1;
    my $svc_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_svc'} || 1;
    my $svc_order      = "ASC";
    $svc_order = "DESC" if $svc_sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'service_description' ], 'host name' ],
        '2' => [ [ 'service_description' ],                'service name' ],
        '3' => [ [ 'entry_time' ],                         'entry time' ],
        '4' => [ [ 'author' ],                             'author' ],
        '5' => [ [ 'comment' ],                            'comment' ],
        '6' => [ [ 'start_time' ],                         'start time' ],
        '7' => [ [ 'end_time' ],                           'end time' ],
        '8' => [ [ 'fixed' ],                              'type' ],
        '9' => [ [ 'duration' ],                           'duration' ],
        '10' =>[ [ 'id' ],                                 'id' ],
        '11' =>[ [ 'triggered_by' ],                       'trigger id' ],
    };
    $svc_sortoption = 1 if !defined $sortoptions->{$svc_sortoption};
    $c->stash->{'svc_orderby'}  = $sortoptions->{$svc_sortoption}->[1];
    $c->stash->{'svc_orderdir'} = $svc_order;

    # hosts
    my $hst_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_hst'}   || 1;
    my $hst_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || 1;
    my $hst_order      = "ASC";
    $hst_order = "DESC" if $hst_sorttype == 2;
    $hst_sortoption = 1 if !defined $sortoptions->{$hst_sortoption};
    $c->stash->{'hst_orderby'}  = $sortoptions->{$hst_sortoption}->[1];
    $c->stash->{'hst_orderdir'} = $hst_order;

    $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => undef } ],
                                                               sort   => { $hst_order => $sortoptions->{$hst_sortoption}->[0] },
                                                              );
    $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => { '!=' => undef } } ],
                                                               sort   => { $svc_order => $sortoptions->{$svc_sortoption}->[0] },
                                                              );

    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->res->header( 'Content-Disposition', 'attachment; filename="downtimes.xls"' );
        $c->stash->{'template'} = 'excel/downtimes.tt';
        return $c->detach('View::Excel');
    }
    if($view_mode eq 'json') {
        $c->stash->{'json'} = {
            'host'    => $c->stash->{'hostdowntimes'},
            'service' => $c->stash->{'servicedowntimes'},
        };
        return $c->detach('View::JSON');
    }
    return 1;
}

##########################################################
# create the recurring downtimes page
sub _process_recurring_downtimes_page {
    my( $self, $c ) = @_;

    my $task   = $c->{'request'}->{'parameters'}->{'recurring'} || '';
    my $target = lc($c->{'request'}->{'parameters'}->{'target'} || 'service');

    # remove unnecessary values
    $c->{'request'}->{'parameters'}->{'hostgroup'}    = '' if $target ne 'hostgroup';
    $c->{'request'}->{'parameters'}->{'servicegroup'} = '' if $target ne 'servicegroup';
    $c->{'request'}->{'parameters'}->{'service'}      = '' if $target ne 'service';
    $c->{'request'}->{'parameters'}->{'host'}         = '' if($target ne 'service' and $target ne 'host');

    my $host         = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup    = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $service      = $c->{'request'}->{'parameters'}->{'service'}      || '';
    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';
    my $src          = $c->{'request'}->{'parameters'}->{'src'}          || '';
    my $nr           = $c->{'request'}->{'parameters'}->{'nr'};

    my $default_rd = Thruk::Utils::_get_default_recurring_downtime($c, $host, $service, $hostgroup, $servicegroup);
    $default_rd->{'target'} = $target;
    $src           =~ s/[^\w_\-\.]/_/gmx;

    if($task eq 'save') {
        my $rd = {
            'target'        => $target,
            'host'          => $host,
            'hostgroup'     => $hostgroup,
            'service'       => $service,
            'servicegroup'  => $servicegroup,
            'schedule'      => Thruk::Utils::get_cron_entries_from_param($c->{'request'}->{'parameters'}),
            'duration'      => $c->{'request'}->{'parameters'}->{'duration'}        || 5,
            'comment'       => $c->{'request'}->{'parameters'}->{'comment'}         || 'automatic downtime',
            'backends'      => $c->{'request'}->{'parameters'}->{'backends'}        || '',
            'childoptions'  => $c->{'request'}->{'parameters'}->{'childoptions'}    || 0,
            'fixed'         => exists $c->{'request'}->{'parameters'}->{'fixed'} ? $c->{'request'}->{'parameters'}->{'fixed'} : 1,
            'flex_range'    => $c->{'request'}->{'parameters'}->{'flex_range'}      || 720,
        };
        $c->stash->{rd} = $rd;
        my $failed = 0;
        if($self->_check_downtime_permissions($c, $rd) != 2) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no permission for this '.$rd->{'target'}.'!' });
            $failed = 1;
        }
        Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/downtimes/');
        if($src) {
            my $old_file = $c->config->{'var_path'}.'/downtimes/'.$src.'.tsk';
            my $old_rd   = Thruk::Utils::read_data_file($old_file);
            if($self->_check_downtime_permissions($c, $old_rd) == 2) {
                unlink($old_file) if -f $old_file;
            } else {
                $failed = 1;
            }
        }
        return _process_recurring_downtimes_page_edit($self, $c, $src, $default_rd) if $failed;
        my $file = $self->_get_data_file_name($c, $target, $host, $service, $hostgroup, $servicegroup, $nr);
        Thruk::Utils::write_data_file($file, $rd);
        $self->_update_cron_file($c);
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime saved' });
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
    }
    if($task eq 'add' or $task eq 'edit') {
        return if _process_recurring_downtimes_page_edit($self, $c, $src, $default_rd);
    }
    elsif($task eq 'remove') {
        my $file = $c->config->{'var_path'}.'/downtimes/'.$src.'.tsk';
        if(!$src and $nr) {
            $file = $self->_get_data_file_name($c, $target, $host, $service, $hostgroup, $servicegroup, $nr);
        }
        if(-s $file) {
            my $old_rd = Thruk::Utils::read_data_file($file);
            if($self->_check_downtime_permissions($c, $old_rd) != 2) {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'no such downtime!' });
            } else {
                unlink($file);
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime removed' });
            }
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such downtime!' });
        }
        $self->_update_cron_file($c);
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
    }

    $c->stash->{'downtimes'} = $self->_get_downtimes_list($c);
    $c->stash->{template}    = 'extinfo_type_6_recurring.tt';
    return 1;
}

##########################################################
sub _process_recurring_downtimes_page_edit {
    my($self, $c, $src, $default_rd) = @_;
    my $file = $c->config->{'var_path'}.'/downtimes/'.$src.'.tsk';
    $c->stash->{rd}->{'file'} = '';
    $c->stash->{can_edit}     = 1;
    if(-s $file) {
        $c->stash->{rd} = Thruk::Utils::read_data_file($file);
        my $perms = $self->_check_downtime_permissions($c, $c->stash->{rd});
        # check cmd permission for this downtime
        if($perms == 1) {
            $c->stash->{can_edit} = 0;
        }
        if($perms == 0) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such downtime!' });
            return;
        }
        $c->stash->{rd}->{'file'} = $src;
    }
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{rd}               = $default_rd unless defined $c->stash->{rd};
    for my $key (keys %{$default_rd}) {
        $c->stash->{rd}->{$key} = $default_rd->{$key}  unless defined $c->stash->{rd}->{$key};
    }
    $c->stash->{template} = 'extinfo_type_6_recurring_edit.tt';
    return 1;
}

##########################################################
# update downtimes cron
sub _update_cron_file {
    my( $self, $c ) = @_;

    # gather reporting send types from all reports
    my $cron_entries = [];
    my $downtimes = $self->_get_downtimes_list($c, 2);
    for my $d (@{$downtimes}) {
        next unless defined $d->{'schedule'};
        next unless scalar @{$d->{'schedule'}} > 0;
        for my $cr (@{$d->{'schedule'}}) {
            push @{$cron_entries}, [$self->_get_cron_entry($c, $d, $cr)];
        }
    }

    Thruk::Utils::update_cron_file($c, 'downtimes', $cron_entries);
    return;
}

##########################################################
# return list of downtimes
sub _get_downtimes_list {
    my($self, $c, $noauth, $host, $service) = @_;

    my @hostfilter    = (Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ));
    my @servicefilter = (Thruk::Utils::Auth::get_auth_filter( $c, 'services' ));
    if(!$noauth) {
        $noauth = 1 if(!$hostfilter[0] and !$servicefilter[0]);
    }
    unless($noauth) {
        if($service) {
            push @servicefilter, { -and => [ { description => $service }, { host_name => $host} ] };
        }
        elsif($host) {
            push @hostfilter, { name => $host };
        }
    }

    my($hosts, $services, $hostgroups, $servicegroups) = ({},{},{},{});
    my $host_data    = $c->{'db'}->get_hosts(    filter => \@hostfilter,    columns => [qw/name groups/]);
    my $service_data = $c->{'db'}->get_services( filter => \@servicefilter, columns => [qw/host_name description host_groups groups/] );
    $hosts    = Thruk::Utils::array2hash($host_data, 'name');
    $services = Thruk::Utils::array2hash($service_data,  'host_name', 'description');

    if($service) {
        $hostgroups    = Thruk::Utils::array2hash($services->{$host}->{$service}->{'host_groups'});
        $servicegroups = Thruk::Utils::array2hash($services->{$host}->{$service}->{'groups'});
    }
    elsif($host) {
        $hostgroups    = Thruk::Utils::array2hash($hosts->{$host}->{'groups'});
    }
    elsif(!$noauth) {
        for my $h (@{$host_data}) {
            $hosts->{$h->{'name'}} = 1;
            for my $g (@{$h->{'groups'}}) {
                $hostgroups->{$g} = 1;
            }
        }
        for my $s (@{$service_data}) {
            $service->{$s->{'host_name'}}->{$s->{'description'}} = 1;
            for my $g (@{$s->{'host_groups'}}) {
                $hostgroups->{$g} = 1;
            }
            for my $g (@{$s->{'groups'}}) {
                $servicegroups->{$g} = 1;
            }
        }
    }

    my $default_rd = Thruk::Utils::_get_default_recurring_downtime($c, $host, $service);
    my $downtimes = [];
    my @files = glob($c->config->{'var_path'}.'/downtimes/*.tsk');
    for my $dfile (@files) {
        next unless -f $dfile;
        my $d = Thruk::Utils::read_data_file($dfile);
        $d->{'file'} = $dfile;
        $d->{'file'} =~ s|^.*/||gmx;
        $d->{'file'} =~ s|\.tsk$||gmx;

        # set fallback target
        if(!$d->{'target'}) {
            $d->{'target'} = 'host';
            $d->{'target'} = 'service' if $d->{'service'};
        }

        # apply filter
        if($host or !$noauth) {
            if($d->{'target'} eq 'host') {
                next unless defined $hosts->{$d->{'host'}};
            }
            if($d->{'target'} eq 'service') {
                next if !$service;
                next unless defined $services->{$d->{'host'}}->{$d->{'service'}};
            }
            if($d->{'target'} eq 'servicegroup') {
                next if !$service;
                next unless defined $servicegroups->{$d->{'servicegroup'}};
            }
            if($d->{'target'} eq 'hostgroup') {
                next unless defined $hostgroups->{$d->{'hostgroup'}};
            }
        }

        # backend filter?
        my $backends = Thruk::Utils::list($d->{'backends'});
        if((!defined $noauth || $noauth != 2) and scalar @{$backends} > 0) {
            my $found = 0;
            $found = 1 if $backends->[0] eq ''; # no backends at all
            for my $b (@{$backends}) {
                next unless $c->{'stash'}->{'backend_detail'}->{$b};
                $found = 1 if $c->{'stash'}->{'backend_detail'}->{$b}->{'disabled'} != 2;
            }
            next unless $found;
        }

        # set some defaults
        for my $key (keys %{$default_rd}) {
            $d->{$key} = $default_rd->{$key} unless defined $d->{$key};
        }

        push @{$downtimes}, $d;
    }

    # sort by target & host & service
    @{$downtimes} = sort {    $a->{'target'}       cmp $b->{'target'}
                           or $a->{'host'}         cmp $b->{'host'}
                           or $a->{'service'}      cmp $b->{'service'}
                           or $a->{'servicegroup'} cmp $b->{'servicegroup'}
                           or $a->{'hostgroup'}    cmp $b->{'hostgroup'}
                         } @{$downtimes};

    return $downtimes;
}

##########################################################
# return cmd line for downtime
sub _get_cron_entry {
    my($self, $c, $downtime, $rd) = @_;

    my $cmd = $self->_get_downtime_cmd($c, $downtime);
    my $time = Thruk::Utils::get_cron_time_entry($rd);
    return($time, $cmd);
}

##########################################################
sub _get_downtime_cmd {
    my($self, $c, $downtime) = @_;
    # ensure proper cron.log permission
    open(my $fh, '>>', $c->config->{'var_path'}.'/cron.log');
    Thruk::Utils::IO::close($fh, $c->config->{'var_path'}.'/cron.log');
    my $cmd = sprintf("cd %s && %s '%s -a downtimetask=%s' >/dev/null 2>>%s/cron.log",
                            $c->config->{'project_root'},
                            $c->config->{'thruk_shell'},
                            $c->config->{'thruk_bin'},
                            $downtime->{'file'},
                            $c->config->{'var_path'},
                    );
    return $cmd;
}

##########################################################
# return filename for data file
sub _get_data_file_name {
    my($self, $c, $target, $host, $service, $hostgroup, $servicegroup, $nr) = @_;
    my $name;
    if($target eq 'host') {
        $name = 'hst_'.$host;
    }
    elsif($target eq 'service') {
        $name = 'svc_'.$host.'_'.$service;
    }
    elsif($target eq 'hostgroup') {
        $name = 'hg_'.$hostgroup;
    }
    elsif($target eq 'servicegroup') {
        $name = 'sg_'.$servicegroup;
    }
    confess("unknown type") unless $name;
    $name =~ s/[^\w_\-\.]/_/gmx;

    if(!defined $nr or $nr !~ m/^\d+$/mx) {
        $nr = 1;
        while(-f $c->config->{'var_path'}.'/downtimes/'.$name.'_'.$nr.'.tsk') {
            $nr++;
        }
    }

    return $c->config->{'var_path'}.'/downtimes/'.$name.'_'.$nr.'.tsk';
}

##########################################################
# create the host info page
sub _process_host_page {
    my( $self, $c ) = @_;
    my $host;

    my $backend = $c->{'request'}->{'parameters'}->{'backend'} || '';
    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/5') unless defined $hostname;
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi#host?host=".$hostname);
    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ] );

    return $c->detach('/error/index/5') unless defined $hosts;

    # we only got one host
    $host = $hosts->[0];

    # we have more and backend param is used
    if( scalar @{$hosts} == 1 and defined $backend ) {
        for my $h ( @{$hosts} ) {
            if( $h->{'peer_key'} eq $backend ) {
                $host = $h;
                last;
            }
        }
    }

    return $c->detach('/error/index/5') unless defined $host;

    my @backends;
    for my $h ( @{$hosts} ) {
        push @backends, $h->{'peer_key'};
    }
    $self->_set_backend_selector( $c, \@backends, $host->{'peer_key'} );

    $c->stash->{'host'} = $host;
    my $comments = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { 'DESC' => 'id' } );
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { 'DESC' => 'id' } );


    # shinken only
    $c->stash->{'show_impacts_link'}      = 0;
    $c->stash->{'show_rootproblems_link'} = 0;

    if($c->stash->{'enable_shinken_features'}) {
        # show the impacts link for problem hosts
        if($host->{'is_problem'}) {
            $c->stash->{'show_impacts_link'}      = 1;
        }
        # show the root problems of this impact
        if($host->{'is_impact'}) {
            $c->stash->{'show_rootproblems_link'} = 1;
        }
    }

    $c->stash->{'comments'}  = $comments;
    $c->stash->{'downtimes'} = $downtimes;

    # generate command line
    if($c->{'stash'}->{'show_full_commandline'} == 2 ||
       $c->{'stash'}->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ) ) {
        if(defined $host) {
            my $command            = $c->{'db'}->expand_command('host' => $host, 'source' => $c->config->{'show_full_commandline_source'} );
            $c->stash->{'command'} = $command;
        }
    }

    # object source
    $c->stash->{'source'} = '';
    my $custvars = Thruk::Utils::get_custom_vars($host);
    if(defined $custvars->{'SRC'}) {
        $c->stash->{'source'} = $custvars->{'SRC'};
    }

    # pnp graph?
    $c->stash->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $host);

    # other graphs?
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $host);
    
    # Hook to replace special character in hosts for Graphite 
    if ($c->stash->{'graph_url'} =~ /graphite|render/){
        my $new_hostname = $hostname;
        $new_hostname =~ s/[^\w-]/_/g;
        $c->stash->{'graph_url'} =~ s/$hostname/$new_hostname/g;
    }


    # recurring downtimes
    $c->stash->{'recurring_downtimes'} = $self->_get_downtimes_list($c, 1, $hostname);

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, $host);

    return 1;
}

##########################################################
# create the hostgroup cmd page
sub _process_hostgroup_cmd_page {
    my( $self, $c ) = @_;

    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'};
    return $c->detach('/error/index/5') unless defined $hostgroup;

    my $groups = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) , 'name' => $hostgroup ], limit => 1 );
    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'hostgroup'}       = $groups->[0];
    return 1;
}

##########################################################
# create the service info page
sub _process_service_page {
    my( $self, $c ) = @_;
    my $service;
    my $backend = $c->{'request'}->{'parameters'}->{'backend'} || '';

    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/15') unless defined $hostname;

    my $servicename = $c->{'request'}->{'parameters'}->{'service'};
    return $c->detach('/error/index/15') unless defined $servicename;

    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."thruk/cgi-bin/mobile.cgi#service?host=".$hostname."&service=".$servicename);

    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $servicename }, ] );

    return $c->detach('/error/index/15') unless defined $services;

    # we only got one service
    $service = $services->[0];

    # we have more and backend param is used
    if( scalar @{$services} == 1 and defined $services ) {
        for my $s ( @{$services} ) {
            if( $s->{'peer_key'} eq $backend ) {
                $service = $s;
                last;
            }
        }
    }

    return $c->detach('/error/index/15') unless defined $service;

    my @backends;
    for my $s ( @{$services} ) {
        push @backends, $s->{'peer_key'};
    }
    $self->_set_backend_selector( $c, \@backends, $service->{'peer_key'} );

    $c->stash->{'service'} = $service;

    my $comments = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { 'DESC' => 'id' } );
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { 'DESC' => 'id' } );
    $c->stash->{'comments'}  = $comments;
    $c->stash->{'downtimes'} = $downtimes;

    # shinken only
    $c->stash->{'show_impacts_link'}      = 0;
    $c->stash->{'show_rootproblems_link'} = 0;
    if($c->stash->{'enable_shinken_features'}) {
        # show the impacts link for problem hosts
        if($service->{'is_problem'}) {
            $c->stash->{'show_impacts_link'}      = 1;
        }
        # show the root problems of this impact
        if($service->{'is_impact'}) {
            $c->stash->{'show_rootproblems_link'} = 1;
        }
    }

    # generate command line
    if($c->{'stash'}->{'show_full_commandline'} == 2 ||
       $c->{'stash'}->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ) ) {
        my $hosts               = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ] );
        # we only got one host
        my $host = $hosts->[0];
        # we have more and backend param is used
        if( scalar @{$hosts} == 1 and defined $backend ) {
            for my $h ( @{$hosts} ) {
                if( $h->{'peer_key'} eq $backend ) {
                    $host = $h;
                    last;
                }
            }
        }
        $c->stash->{'command'}  = '';
        if(defined $host and defined $service) {
            my $command            = $c->{'db'}->expand_command('host' => $host, 'service' => $service, 'source' => $c->config->{'show_full_commandline_source'} );
            $c->stash->{'command'} = $command;
        }
    }

    # object source
    $c->stash->{'source'} = '';
    my $custvars = Thruk::Utils::get_custom_vars($service);
    if(defined $custvars->{'SRC'}) {
        $c->stash->{'source'} = $custvars->{'SRC'};
    }

    # pnp graph?
    $c->stash->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $service);

    # other graphs?
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $service);
    
    # Hook to replace special character in hosts and services for Graphite
    if ($c->stash->{'graph_url'} =~ /graphite|render/){
        my $new_servicename = $servicename;
        $new_servicename =~ s/[^\w-]/_/g;
        my $new_hostname = $hostname;
        $new_hostname =~ s/[^\w-]/_/g;
        $c->stash->{'graph_url'} =~ s/$hostname\.$servicename/$new_hostname\.$new_servicename/g;

    }


    # recurring downtimes
    $c->stash->{'recurring_downtimes'} = $self->_get_downtimes_list($c, 1, $hostname, $servicename);

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, $service);

    return 1;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my( $self, $c ) = @_;

    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'};
    return $c->detach('/error/index/5') unless defined $servicegroup;

    my $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), name => $servicegroup ], limit => 1);

    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'servicegroup'}       = $groups->[0];

    return 1;
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my( $self, $c ) = @_;

    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;

    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;

    my $sortoptions = {
        '1' => [ [ 'host_name', 'description' ], 'host name' ],
        '2' => [ 'description', 'service name' ],
        '4' => [ 'last_check',  'last check time' ],
        '7' => [ 'next_check',  'next check time' ],
    };
    $sortoption = 7 if !defined $sortoptions->{$sortoption};

    $c->{'db'}->get_scheduling_queue($c,  sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => 1 );

    $c->stash->{'order'}   = $order;
    $c->stash->{'sortkey'} = $sortoptions->{$sortoption}->[1];

    return 1;
}

##########################################################
# create the process info page
sub _process_process_info_page {
    my( $self, $c ) = @_;

    return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
    return 1;
}

##########################################################
# create the performance info page
sub _process_perf_info_page {
    my( $self, $c ) = @_;

    $c->stash->{'stats'}      = $c->{'db'}->get_performance_stats( services_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], hosts_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    $c->stash->{'perf_stats'} = $c->{'db'}->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );

    # add logfile cache statistics
    $c->stash->{'has_logcache'}   = 0;
    $c->stash->{'logcache_error'} = '';
    if($c->config->{'logcache'}) {
        eval {
            $c->stash->{'logcache_stats'} = $c->{'db'}->logcache_stats($c, 1);
            $c->stash->{'has_logcache'} = 1;
        };
        if($@) {
            $c->stash->{'logcache_error'} = $@;
            $c->stash->{'logcache_error'} =~ s/\ at\ .*?\ line\ \d+\.//gmx;
        }
    }

    return 1;
}

##########################################################
# show backend selector
sub _set_backend_selector {
    my( $self, $c, $backends, $selected ) = @_;
    my %backends = map { $_ => 1 } @{$backends};

    my @backends;
    my @possible_backends = $c->{'db'}->peer_key();
    for my $back (@possible_backends) {
        next if !defined $backends{$back};
        push @backends, $back;
    }

    $c->stash->{'matching_backends'} = \@backends;
    $c->stash->{'backend'}           = $selected;
    return 1;
}

##########################################################
# _check_downtime_permissions($c, $downtime)
# returns:
#   0 - no permission
#   1 - read-only
#   2 - write
sub _check_downtime_permissions {
    my($self, $c, $d) = @_;
    if(!$d->{'target'}) {
        $d->{'target'} = 'host';
        $d->{'target'} = 'service' if $d->{'service'};
    }
    if($d->{'target'} eq 'host') {
       return 2 if $c->check_cmd_permissions('host', $d->{'host'});
       return 1 if $c->check_permissions('host', $d->{'host'});
    }
    if($d->{'target'} eq 'hostgroup') {
       return 2 if $c->check_cmd_permissions('hostgroup', $d->{'hostgroup'});
       return 1 if $c->check_permissions('hostgroup', $d->{'hostgroup'});
    }
    if($d->{'target'} eq 'service') {
       return 2 if $c->check_cmd_permissions('service', $d->{'service'}, $d->{'host'});
       return 1 if $c->check_permissions('service', $d->{'service'}, $d->{'host'});
    }
    if($d->{'target'} eq 'servicegroup') {
       return 2 if $c->check_cmd_permissions('servicegroup', $d->{'servicegroup'});
       return 1 if $c->check_permissions('servicegroup', $d->{'servicegroup'});
    }
    return 0;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
