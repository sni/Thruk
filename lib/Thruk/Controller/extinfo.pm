package Thruk::Controller::extinfo;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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

    if(!$c->config->{'extinfo_modules_loaded'}) {
        require Thruk::Utils::RecurringDowntimes;
        $c->config->{'extinfo_modules_loaded'} = 1;
    }

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

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}

##########################################################
# SUBS
##########################################################

##########################################################
# get comment sort options
sub _get_comment_sort_option {
    my( $self, $option ) = @_;

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

    return $sortoptions->{$option};
}

##########################################################
# get downtime sort options
sub _get_downtime_sort_option {
    my( $self, $option ) = @_;

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

    return $sortoptions->{$option};
}

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
    $svc_sortoption = 1 if !defined $self->_get_comment_sort_option($svc_sortoption);
    $c->stash->{'svc_orderby'}    = $self->_get_comment_sort_option($svc_sortoption)->[1];
    $c->stash->{'svc_orderdir'}   = $svc_order;
    $c->stash->{'sortoption_svc'} = $c->{'request'}->{'parameters'}->{'sortoption_svc'} || '';

    # hosts
    my $hst_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_hst'}   || 1;
    my $hst_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || 1;
    my $hst_order      = "ASC";
    $hst_order = "DESC" if $hst_sorttype == 2;
    $hst_sortoption = 1 if !defined $self->_get_comment_sort_option($hst_sortoption);
    $c->stash->{'hst_orderby'}    = $self->_get_comment_sort_option($hst_sortoption)->[1];
    $c->stash->{'hst_orderdir'}   = $hst_order;
    $c->stash->{'sortoption_hst'} = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || '';

    $c->stash->{'hostcomments'}    = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => undef } ],
                                                               sort   => { $hst_order => $self->_get_comment_sort_option($hst_sortoption)->[0] },
                                                             );
    $c->stash->{'servicecomments'} = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => { '!=' => undef } } ],
                                                               sort   => { $svc_order => $self->_get_comment_sort_option($svc_sortoption)->[0] },
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
        return $c->detach('Thruk::View::JSON');
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
    $svc_sortoption = 1 if !defined $self->_get_downtime_sort_option($svc_sortoption);
    $c->stash->{'svc_orderby'}    = $self->_get_downtime_sort_option($svc_sortoption)->[1];
    $c->stash->{'svc_orderdir'}   = $svc_order;
    $c->stash->{'sortoption_svc'} = $c->{'request'}->{'parameters'}->{'sortoption_svc'} || '';

    # hosts
    my $hst_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_hst'}   || 1;
    my $hst_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || 1;
    my $hst_order      = "ASC";
    $hst_order = "DESC" if $hst_sorttype == 2;
    $hst_sortoption = 1 if !defined $self->_get_downtime_sort_option($hst_sortoption);
    $c->stash->{'hst_orderby'}    = $self->_get_downtime_sort_option($hst_sortoption)->[1];
    $c->stash->{'hst_orderdir'}   = $hst_order;
    $c->stash->{'sortoption_hst'} = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || '';

    $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => undef } ],
                                                                 sort   => { $hst_order => $self->_get_downtime_sort_option($hst_sortoption)->[0] },
                                                               );
    $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => { '!=' => undef } } ],
                                                                 sort   => { $svc_order => $self->_get_downtime_sort_option($svc_sortoption)->[0] },
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
        return $c->detach('Thruk::View::JSON');
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
    my $nr           = $c->{'request'}->{'parameters'}->{'nr'};

    my $default_rd = Thruk::Utils::RecurringDowntimes::get_default_recurring_downtime($c, $host, $service, $hostgroup, $servicegroup);
    $default_rd->{'target'} = $target;

    if($task eq 'save') {
        my $backends = [];
        if($c->{'request'}->{'parameters'}->{'d_backends'}) {
            $backends = ref $c->{'request'}->{'parameters'}->{'d_backends'} eq 'ARRAY' ? $c->{'request'}->{'parameters'}->{'d_backends'} : [$c->{'request'}->{'parameters'}->{'d_backends'}];
        }
        my $rd = {
            'target'        => $target,
            'host'          => [split/\s*,\s*/mx,$host],
            'hostgroup'     => [split/\s*,\s*/mx,$hostgroup],
            'service'       => $service,
            'servicegroup'  => [split/\s*,\s*/mx,$servicegroup],
            'schedule'      => Thruk::Utils::get_cron_entries_from_param($c->{'request'}->{'parameters'}),
            'duration'      => $c->{'request'}->{'parameters'}->{'duration'}        || 5,
            'comment'       => $c->{'request'}->{'parameters'}->{'comment'}         || 'automatic downtime',
            'backends'      => $backends,
            'childoptions'  => $c->{'request'}->{'parameters'}->{'childoptions'}    || 0,
            'fixed'         => exists $c->{'request'}->{'parameters'}->{'fixed'} ? $c->{'request'}->{'parameters'}->{'fixed'} : 1,
            'flex_range'    => $c->{'request'}->{'parameters'}->{'flex_range'}      || 720,
        };
        for my $t (qw/host hostgroup servicegroup/) {
            $rd->{$t} = [sort {lc $a cmp lc $b} @{$rd->{$t}}];
        }
        $rd->{'verbose'} = 1 if $c->{'request'}->{'parameters'}->{'verbose'};
        $c->stash->{rd} = $rd;
        my $failed = 0;

        # check permissions
        if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $rd) != 2) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no permission for this '.$rd->{'target'}.'!' });
            $failed = 1;
        }

        # does this downtime makes sense?
        if(    $target eq 'service'      and !$host) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'host cannot be empty!' });
            $failed = 1;
        }
        if(   ($target eq 'host'         and !$host)
           or ($target eq 'service'      and !$service)
           or ($target eq 'servicegroup' and !$servicegroup)
           or ($target eq 'hostgroup'    and !$hostgroup)
        ) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => $target.' cannot be empty!' });
            $failed = 1;
        }

        Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/downtimes/');
        my $old_file;
        if($nr and !$failed) {
            $old_file  = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
            if(-s $old_file) {
                my $old_rd = Thruk::Utils::read_data_file($old_file);
                if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $old_rd) != 2) {
                    $failed = 1;
                }
            }
        }
        return $self->_process_recurring_downtimes_page_edit($c, $nr, $default_rd, $rd) if $failed;
        my $file = $old_file || Thruk::Utils::RecurringDowntimes::get_data_file_name($c);
        Thruk::Utils::write_data_file($file, $rd);
        Thruk::Utils::RecurringDowntimes::update_cron_file($c);
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime saved' });
        return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=6&recurring");
    }
    if($task eq 'add' or $task eq 'edit') {
        return if $self->_process_recurring_downtimes_page_edit($c, $nr, $default_rd);
    }
    elsif($task eq 'remove') {
        my $file = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
        if(-s $file) {
            my $old_rd = Thruk::Utils::read_data_file($file);
            if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $old_rd) != 2) {
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'no such downtime!' });
            } else {
                unlink($file);
                Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime removed' });
            }
        } else {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such downtime!' });
        }
        Thruk::Utils::RecurringDowntimes::update_cron_file($c);
        return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=6&recurring");
    }

    $c->stash->{'downtimes'} = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 1, 1);
    $c->stash->{template}    = 'extinfo_type_6_recurring.tt';
    return 1;
}

##########################################################
sub _process_recurring_downtimes_page_edit {
    my($self, $c, $nr, $default_rd, $rd) = @_;
    $c->stash->{'has_jquery_ui'} = 1;

    $c->stash->{rd}->{'file'} = '';
    $c->stash->{can_edit}     = 1;
    if($nr) {
        my $file = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
        if(-s $file) {
            $c->stash->{rd} = Thruk::Utils::read_data_file($file);
            my $perms = Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $c->stash->{rd});
            # check cmd permission for this downtime
            if($perms == 1) {
                $c->stash->{can_edit} = 0;
            }
            if($perms == 0) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such downtime!' });
                return;
            }
            $c->stash->{rd}->{'file'} = $nr;
        }
    }
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{rd}               = $default_rd unless defined $c->stash->{rd};
    for my $key (keys %{$default_rd}) {
        $c->stash->{rd}->{$key} = $default_rd->{$key}  unless defined $c->stash->{rd}->{$key};
    }
    # change existing, not yet saved downtime
    if($rd) {
        for my $key (keys %{$rd}) {
            $c->stash->{rd}->{$key} = $rd->{$key};
        }
    }
    $c->stash->{template} = 'extinfo_type_6_recurring_edit.tt';
    return 1;
}

##########################################################
# create the host info page
sub _process_host_page {
    my( $self, $c ) = @_;
    my $host;

    my $backend = $c->{'request'}->{'parameters'}->{'backend'} || '';
    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/5') unless defined $hostname;
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi#host?host=".$hostname);
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

    # comments
    my $cmt_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_cmt'}   || 2;
    my $cmt_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_cmt'} || 3;
    my $cmt_order      = "ASC";
    $cmt_order = "DESC" if $cmt_sorttype == 2;
    $cmt_sortoption = 1 if !defined $self->_get_comment_sort_option($cmt_sortoption);
    $c->stash->{'cmt_orderby'}    = $self->_get_comment_sort_option($cmt_sortoption)->[1];
    $c->stash->{'cmt_orderdir'}   = $cmt_order;
    $c->stash->{'sortoption_cmt'} = $c->{'request'}->{'parameters'}->{'sortoption_cmt'} || '';

    $c->stash->{'comments'}  = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { $cmt_order => $self->_get_comment_sort_option($cmt_sortoption)->[0] } );

    # downtimes
    my $dtm_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_dtm'}   || 2;
    my $dtm_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_dtm'} || 3;
    my $dtm_order      = "ASC";
    $dtm_order = "DESC" if $dtm_sorttype == 2;
    $dtm_sortoption = 1 if !defined $self->_get_comment_sort_option($dtm_sortoption);
    $c->stash->{'dtm_orderby'}    = $self->_get_comment_sort_option($dtm_sortoption)->[1];
    $c->stash->{'dtm_orderdir'}   = $dtm_order;
    $c->stash->{'sortoption_dtm'} = $c->{'request'}->{'parameters'}->{'sortoption_dtm'} || '';

    $c->stash->{'downtimes'} = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { $dtm_order => $self->_get_comment_sort_option($dtm_sortoption)->[0] } );

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

    # generate command line
    if($c->stash->{'show_full_commandline'} == 2 ||
       $c->stash->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ) ) {
        if(defined $host) {
            my $command            = $c->{'db'}->expand_command('host' => $host, 'source' => $c->config->{'show_full_commandline_source'} );
            $c->stash->{'command'} = $command;
        }
    }

    # object source
    my $custvars = Thruk::Utils::get_custom_vars($c, $host);
    $c->stash->{'source'}  = $custvars->{'SRC'}  || '';
    $c->stash->{'source2'} = $custvars->{'SRC2'} || '';
    $c->stash->{'source3'} = $custvars->{'SRC3'} || '';

    # pnp graph?
    $c->stash->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $host);

    # other graphs?
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $host);

    # recurring downtimes
    $c->stash->{'recurring_downtimes'} = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 1, $hostname);

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, {'host' => $host});

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

    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi#service?host=".$hostname."&service=".$servicename);

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

    # comments
    my $cmt_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_cmt'}   || 2;
    my $cmt_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_cmt'} || 3;
    my $cmt_order      = "ASC";
    $cmt_order = "DESC" if $cmt_sorttype == 2;
    $cmt_sortoption = 1 if !defined $self->_get_comment_sort_option($cmt_sortoption);
    $c->stash->{'cmt_orderby'}    = $self->_get_comment_sort_option($cmt_sortoption)->[1];
    $c->stash->{'cmt_orderdir'}   = $cmt_order;
    $c->stash->{'sortoption_cmt'} = $c->{'request'}->{'parameters'}->{'sortoption_cmt'} || '';

    $c->stash->{'comments'} = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { $cmt_order => $self->_get_comment_sort_option($cmt_sortoption)->[0] } );

    # downtimes
    my $dtm_sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_dtm'}   || 2;
    my $dtm_sortoption = $c->{'request'}->{'parameters'}->{'sortoption_dtm'} || 3;
    my $dtm_order      = "ASC";
    $dtm_order = "DESC" if $dtm_sorttype == 2;
    $dtm_sortoption = 1 if !defined $self->_get_comment_sort_option($dtm_sortoption);
    $c->stash->{'dtm_orderby'}    = $self->_get_comment_sort_option($dtm_sortoption)->[1];
    $c->stash->{'dtm_orderdir'}   = $dtm_order;
    $c->stash->{'sortoption_dtm'} = $c->{'request'}->{'parameters'}->{'sortoption_dtm'} || '';

    $c->stash->{'downtimes'} = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { $dtm_order => $self->_get_comment_sort_option($dtm_sortoption)->[0] } );

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
    if($c->stash->{'show_full_commandline'} == 2 ||
       $c->stash->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ) ) {
        if(defined $service) {
            my $command            = $c->{'db'}->expand_command('host' => $service, 'service' => $service, 'source' => $c->config->{'show_full_commandline_source'} );
            $c->stash->{'command'} = $command;
        }
    }

    # object source
    my $custvars = Thruk::Utils::get_custom_vars($c, $service);
    $c->stash->{'source'}  = $custvars->{'SRC'}  || '';
    $c->stash->{'source2'} = $custvars->{'SRC2'} || '';
    $c->stash->{'source3'} = $custvars->{'SRC3'} || '';

    # pnp graph?
    $c->stash->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $service);

    # other graphs?
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $service);

    # recurring downtimes
    $c->stash->{'recurring_downtimes'} = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 1, $hostname, $servicename);

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, {'host' => $service, 'service' => $service});

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

    # apache statistics
    $c->stash->{'apache_status'} = [];
    if(    $c->check_user_roles("authorized_for_configuration_information")
       and $c->check_user_roles("authorized_for_system_information")) {
        my $apache = $c->{'request'}->{'parameters'}->{'apache'};

        for my $name (keys %{$c->config->{'apache_status'}}) {
            push @{$c->stash->{'apache_status'}}, $name;
        }

        if($apache and $c->config->{'apache_status'}->{$apache}) {
            _apache_status($c, $apache, $c->config->{'apache_status'}->{$apache});
            $c->stash->{template} = 'extinfo_type_4_apache_status.tt';
            return 1;
        }
    }

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
# get apache status
sub _apache_status {
    my($c, $name, $url) = @_;
    require Thruk::UserAgent;
    my $ua = Thruk::UserAgent->new($c->config);
    $ua->timeout(10);
    $ua->agent("thruk");
    $ua->ssl_opts('verify_hostname' => 0 );
    $ua->max_redirect(0);
    # pass through authentication
    my $cookie = $c->request->cookie('thruk_auth');
    $ua->default_header('Cookie' => 'thruk_auth='.$cookie->value) if $cookie;
    $ua->default_header('Authorization' => $c->{'request'}->{'headers'}->{'authorization'}) if $c->{'request'}->{'headers'}->{'authorization'};
    my $res = $ua->get($url);
    if($res->code == 200) {
        my $content = $res->content;
        $content =~ s|<html>||gmx;
        $content =~ s|<head>.*?<\/head>||gmxs;
        $content =~ s|<body>||gmx;
        $content =~ s|<\/body>||gmx;
        $content =~ s|<\/html>||gmx;
        $content =~ s|<h1>Apache\s+Server\s+Status\s+for\s+.*?</h1>|<h1>$name Apache Server Status</h1>|gmx;
        $c->stash->{content} = $content;
    } else {
        $c->stash->{content}  = 'not available: '.$res->code;
    }
    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
