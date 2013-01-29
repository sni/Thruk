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
    my $task        = $c->{'request'}->{'parameters'}->{'recurring'}    || '';
    my $host        = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $service     = $c->{'request'}->{'parameters'}->{'service'}      || '';
    my $old_host    = $c->{'request'}->{'parameters'}->{'old_host'}     || '';
    my $old_service = $c->{'request'}->{'parameters'}->{'old_service'}  || '';

    my $default_rd = Thruk::Utils::_get_default_recurring_downtime($c, $host, $service);

    if($task eq 'save') {
        my $rd = {
            'host'          => $host,
            'service'       => $service,
            'schedule'      => Thruk::Utils::get_cron_entries_from_param($c->{'request'}->{'parameters'}),
            'duration'      => $c->{'request'}->{'parameters'}->{'duration'}        || 5,
            'comment'       => $c->{'request'}->{'parameters'}->{'comment'}         || '',
            'backends'      => $c->{'request'}->{'parameters'}->{'backends'}        || '',
            'childoptions'  => $c->{'request'}->{'parameters'}->{'childoptions'}    || 0,
            'fixed'         => exists $c->{'request'}->{'parameters'}->{'fixed'} ? $c->{'request'}->{'parameters'}->{'fixed'} : 1,
            'flex_range'    => $c->{'request'}->{'parameters'}->{'flex_range'}      || 720,
        };
        if($service) {
            if(!$c->check_cmd_permissions('service', $service, $host)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such service or no permission' });
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
            }
            if($old_service and !$c->check_cmd_permissions('service', $old_service, $old_host)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such service or no permission' });
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
            }
        }
        if($host) {
            if(!$c->check_cmd_permissions('host', $host)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such host or no permission' });
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
            }
            if($old_host and !$c->check_cmd_permissions('host', $host)) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such host or no permission' });
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
            }
        }
        Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/downtimes/');
        my $file = $self->_get_data_file_name($c, $host, $service);
        Thruk::Utils::write_data_file($file, $rd);
        if($old_host and ($old_host ne $host or $old_service ne $service)) {
            my $oldfile = $self->_get_data_file_name($c, $old_host, $old_service);
            unlink($oldfile) if -f $oldfile;
        }
        $self->_update_cron_file($c);
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime saved' });
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
    }
    if($task eq 'add_host' or $task eq 'add_service' or $task eq 'edit') {
        my $file = $self->_get_data_file_name($c, $host, $service);
        if(-s $file) {
            $c->stash->{rd} = Thruk::Utils::read_data_file($file);
        }
        $c->stash->{'no_auto_reload'} = 1;
        $c->stash->{'task'}   = $task;
        $c->stash->{rd}       = $default_rd unless defined $c->stash->{rd};
        for my $key (keys %{$default_rd}) {
            $c->stash->{rd}->{$key} = $default_rd->{$key}  unless defined $c->stash->{rd}->{$key};
        }
        $c->stash->{template} = 'extinfo_type_6_recurring_edit.tt';
    }
    elsif($task eq 'remove') {
        my $file = $self->_get_data_file_name($c, $host, $service);
        if(-s $file) {
            unlink($file);
        }
        $self->_update_cron_file($c);
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime removed' });
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/extinfo.cgi?type=6&recurring");
    } else {
        $c->stash->{'downtimes'} = $self->_get_downtimes_list($c);
        $c->stash->{template}    = 'extinfo_type_6_recurring.tt';
    }
    return 1;
}

##########################################################
# update downtimes cron
sub _update_cron_file {
    my( $self, $c ) = @_;

    # gather reporting send types from all reports
    my $cron_entries = [];
    my $downtimes = $self->_get_downtimes_list($c, 1);
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

    my($hosts, $services);
    unless($noauth) {
        my $host_data    = $c->{'db'}->get_host_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
        my $service_data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], columns => [qw/host_name description/] );
        $hosts    = Thruk::Utils::array2hash($host_data);
        $services = Thruk::Utils::array2hash($service_data,  'host_name', 'description');
    }

    my $default_rd = Thruk::Utils::_get_default_recurring_downtime($c, $host, $service);
    my $downtimes = [];
    my @pattern = glob($c->config->{'var_path'}.'/downtimes/*.tsk');
    if(defined $host) {
        my $file = $self->_get_data_file_name($c, $host, $service);
        @pattern = ($file);
    }
    for my $dfile (@pattern) {
        next unless -f $dfile;
        my $d = Thruk::Utils::read_data_file($dfile);
        $d->{'file'} = $dfile;
        unless($noauth) {
            if($d->{'service'}) {
                next unless defined $services->{$d->{'host'}}->{$d->{'service'}};
            } else {
                next unless defined $hosts->{$d->{'host'}};
            }
        }
        # set some defaults
        for my $key (keys %{$default_rd}) {
            $d->{$key} = $default_rd->{$key}  unless defined $d->{$key};
        }

        push @{$downtimes}, $d if defined $d;
    }

    # sort by host & service
    @{$downtimes} = sort { $a->{'host'} cmp $b->{'host'} or $a->{'service'} cmp $b->{'service'} } @{$downtimes};

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
    my $cmd = sprintf("cd %s && %s '%s -a downtimetask=%s' >/dev/null 2>%s/cron.log",
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
    my($self, $c, $host, $service) = @_;
    my $name = 'hst_'.$host;
    if($service) {
        $name = 'svc_'.$host.'_'.$service;
    }
    $name =~ s/[^\w_\-\.]/_/gmx;
    my $file = $c->config->{'var_path'}.'/downtimes/'.$name.'.tsk';
    return $file;
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

    # pnp graph?
    $c->stash->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $host);
    
     # graph
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $host);

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

    # pnp graph?
    $c->stash->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $service);
    
    # graph?
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $service);

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

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
