package Thruk::Controller::extinfo;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::extinfo - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index {
    my( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    my $type = $c->req->parameters->{'type'} || 0;

    if(!$c->config->{'extinfo_modules_loaded'}) {
        require Thruk::Utils::RecurringDowntimes;
        $c->config->{'extinfo_modules_loaded'} = 1;
    }

    $c->stash->{title}        = 'Extended Information';
    $c->stash->{page}         = 'extinfo';
    $c->stash->{template}     = 'extinfo_type_' . $type . '.tt';

    my $infoBoxTitle;
    if( $type eq 'grafana' ) {
        return(_process_grafana_page($c));
    }
    elsif( $type == 0 ) {
        $infoBoxTitle = 'Process Information';
        return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
        _process_process_info_page($c);
    }
    elsif( $type == 1 ) {
        $infoBoxTitle = 'Host Information';
        return unless _process_host_page($c);
    }
    elsif( $type == 2 ) {
        $infoBoxTitle = 'Service Information';
        return unless _process_service_page($c);
    }
    elsif( $type == 3 ) {
        $infoBoxTitle = 'All Host and Service Comments';
        _process_comments_page($c);
    }
    elsif( $type == 4 ) {
        $infoBoxTitle = 'Performance Information';
        _process_perf_info_page($c);
    }
    elsif( $type == 5 ) {
        $infoBoxTitle = 'Hostgroup Information';
        _process_hostgroup_cmd_page($c);
    }
    elsif( $type == 6 ) {
        if(exists $c->req->parameters->{'recurring'}) {
            $infoBoxTitle = 'Recurring Downtimes';
            _process_recurring_downtimes_page($c);
        } else {
            $infoBoxTitle = 'All Host and Service Scheduled Downtime';
            _process_downtimes_page($c);
        }
    }
    elsif( $type == 7 ) {
        $infoBoxTitle = 'Check Scheduling Queue';
        _process_scheduling_page($c);
    }
    elsif( $type == 8 ) {
        $infoBoxTitle = 'Servicegroup Information';
        _process_servicegroup_cmd_page($c);
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
    my( $option ) = @_;

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
    my( $option ) = @_;

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
    my( $c ) = @_;
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';

    # services
    my $svc_sorttype   = $c->req->parameters->{'sorttype_svc'}   || 1;
    my $svc_sortoption = $c->req->parameters->{'sortoption_svc'} || 1;
    my $svc_order      = "ASC";
    $svc_order = "DESC" if $svc_sorttype == 2;
    $svc_sortoption = 1 if !defined _get_comment_sort_option($svc_sortoption);
    $c->stash->{'svc_orderby'}    = _get_comment_sort_option($svc_sortoption)->[1];
    $c->stash->{'svc_orderdir'}   = $svc_order;
    $c->stash->{'sortoption_svc'} = $c->req->parameters->{'sortoption_svc'} || '';

    # hosts
    my $hst_sorttype   = $c->req->parameters->{'sorttype_hst'}   || 1;
    my $hst_sortoption = $c->req->parameters->{'sortoption_hst'} || 1;
    my $hst_order      = "ASC";
    $hst_order = "DESC" if $hst_sorttype == 2;
    $hst_sortoption = 1 if !defined _get_comment_sort_option($hst_sortoption);
    $c->stash->{'hst_orderby'}    = _get_comment_sort_option($hst_sortoption)->[1];
    $c->stash->{'hst_orderdir'}   = $hst_order;
    $c->stash->{'sortoption_hst'} = $c->req->parameters->{'sortoption_hst'} || '';

    $c->stash->{'hostcomments'}    = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => undef } ],
                                                               sort   => { $hst_order => _get_comment_sort_option($hst_sortoption)->[0] },
                                                             );
    $c->stash->{'servicecomments'} = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => { '!=' => undef } } ],
                                                               sort   => { $svc_order => _get_comment_sort_option($svc_sortoption)->[0] },
                                                             );

    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c, ['host_', 'service_'], 'comment');
        $c->res->headers->header( 'Content-Disposition', 'attachment; filename="comments.xls"' );
        $c->stash->{'template'} = 'excel/comments.tt';
        return $c->render_excel();
    }
    if($view_mode eq 'json') {
        my $json = {
            'host'    => $c->stash->{'hostcomments'},
            'service' => $c->stash->{'servicecomments'},
        };
        return $c->render(json => $json);
    }
    return 1;
}

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my( $c ) = @_;
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';

    # services
    my $svc_sorttype   = $c->req->parameters->{'sorttype_svc'}   || 1;
    my $svc_sortoption = $c->req->parameters->{'sortoption_svc'} || 1;
    my $svc_order      = "ASC";
    $svc_order = "DESC" if $svc_sorttype == 2;
    $svc_sortoption = 1 if !defined _get_downtime_sort_option($svc_sortoption);
    $c->stash->{'svc_orderby'}    = _get_downtime_sort_option($svc_sortoption)->[1];
    $c->stash->{'svc_orderdir'}   = $svc_order;
    $c->stash->{'sortoption_svc'} = $c->req->parameters->{'sortoption_svc'} || '';

    # hosts
    my $hst_sorttype   = $c->req->parameters->{'sorttype_hst'}   || 1;
    my $hst_sortoption = $c->req->parameters->{'sortoption_hst'} || 1;
    my $hst_order      = "ASC";
    $hst_order = "DESC" if $hst_sorttype == 2;
    $hst_sortoption = 1 if !defined _get_downtime_sort_option($hst_sortoption);
    $c->stash->{'hst_orderby'}    = _get_downtime_sort_option($hst_sortoption)->[1];
    $c->stash->{'hst_orderdir'}   = $hst_order;
    $c->stash->{'sortoption_hst'} = $c->req->parameters->{'sortoption_hst'} || '';

    $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => undef } ],
                                                                 sort   => { $hst_order => _get_downtime_sort_option($hst_sortoption)->[0] },
                                                               );
    $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => { '!=' => undef } } ],
                                                                 sort   => { $svc_order => _get_downtime_sort_option($svc_sortoption)->[0] },
                                                               );

    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c, ['host_', 'service_'], 'downtime');
        $c->res->headers->header( 'Content-Disposition', 'attachment; filename="downtimes.xls"' );
        $c->stash->{'template'} = 'excel/downtimes.tt';
        return $c->render_excel();
    }
    if($view_mode eq 'json') {
        my $json = {
            'host'    => $c->stash->{'hostdowntimes'},
            'service' => $c->stash->{'servicedowntimes'},
        };
        return $c->render(json => $json);
    }
    return 1;
}

##########################################################
# create the recurring downtimes page
sub _process_recurring_downtimes_page {
    my( $c ) = @_;

    my $task   = $c->req->parameters->{'recurring'} || '';
    my $target = lc($c->req->parameters->{'target'} || 'service');

    # remove unnecessary values
    $c->req->parameters->{'hostgroup'}    = '' if $target ne 'hostgroup';
    $c->req->parameters->{'servicegroup'} = '' if $target ne 'servicegroup';
    $c->req->parameters->{'service'}      = '' if $target ne 'service';
    $c->req->parameters->{'host'}         = '' if($target ne 'service' and $target ne 'host');

    my $host         = $c->req->parameters->{'host'}         || '';
    my $hostgroup    = $c->req->parameters->{'hostgroup'}    || '';
    my $service      = $c->req->parameters->{'service'}      || '';
    my $servicegroup = $c->req->parameters->{'servicegroup'} || '';
    my $nr           = $c->req->parameters->{'nr'};

    my $default_rd = Thruk::Utils::RecurringDowntimes::get_default_recurring_downtime($c, $host, $service, $hostgroup, $servicegroup);
    $default_rd->{'target'} = $target;

    if($task eq 'save') {
        my $backends = [];
        if($c->req->parameters->{'d_backends'}) {
            $backends = ref $c->req->parameters->{'d_backends'} eq 'ARRAY' ? $c->req->parameters->{'d_backends'} : [$c->req->parameters->{'d_backends'}];
        }
        my $rd = {
            'target'        => $target,
            'host'          => [split/\s*,\s*/mx,$host],
            'hostgroup'     => [split/\s*,\s*/mx,$hostgroup],
            'service'       => [split/\s*,\s*/mx,$service],
            'servicegroup'  => [split/\s*,\s*/mx,$servicegroup],
            'schedule'      => Thruk::Utils::get_cron_entries_from_param($c->req->parameters),
            'duration'      => $c->req->parameters->{'duration'}        || 5,
            'comment'       => $c->req->parameters->{'comment'}         || 'automatic downtime',
            'backends'      => $backends,
            'childoptions'  => $c->req->parameters->{'childoptions'}    || 0,
            'fixed'         => exists $c->req->parameters->{'fixed'} ? $c->req->parameters->{'fixed'} : 1,
            'flex_range'    => $c->req->parameters->{'flex_range'}      || 720,
        };
        for my $t (qw/host hostgroup servicegroup/) {
            $rd->{$t} = [sort {lc $a cmp lc $b} @{$rd->{$t}}];
        }
        $rd->{'verbose'} = 1 if $c->req->parameters->{'verbose'};
        $c->stash->{rd} = $rd;
        my $failed = 0;

        # check permissions
        if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $rd) != 2) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no permission for this '.$rd->{'target'}.'!' });
            $failed = 1;
        }

        # does this downtime makes sense?
        if(    $target eq 'service'      && !$host) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'host cannot be empty!' });
            $failed = 1;
        }
        if(   ($target eq 'host'         && !$host)
           or ($target eq 'service'      && !$service)
           or ($target eq 'servicegroup' && !$servicegroup)
           or ($target eq 'hostgroup'    && !$hostgroup)
        ) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => $target.' cannot be empty!' });
            $failed = 1;
        }

        Thruk::Utils::IO::mkdir($c->config->{'var_path'}.'/downtimes/');
        my $old_file;
        if($nr && !$failed) {
            $old_file  = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
            if(-s $old_file) {
                my $old_rd = Thruk::Utils::read_data_file($old_file);
                if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $old_rd) != 2) {
                    $failed = 1;
                }
            }
        }
        return _process_recurring_downtimes_page_edit($c, $nr, $default_rd, $rd) if $failed;
        my $file = $old_file || Thruk::Utils::RecurringDowntimes::get_data_file_name($c);
        Thruk::Utils::write_data_file($file, $rd);
        Thruk::Utils::RecurringDowntimes::update_cron_file($c);

        # do quick self check
        Thruk::Utils::RecurringDowntimes::check_downtime($c, $rd, $file);

        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'recurring downtime saved' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=6&recurring");
    }
    if($task eq 'add' or $task eq 'edit') {
        return if _process_recurring_downtimes_page_edit($c, $nr, $default_rd);
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
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=6&recurring");
    }

    $c->stash->{'downtimes'} = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 1, 1);
    $c->stash->{template}    = 'extinfo_type_6_recurring.tt';
    return 1;
}

##########################################################
sub _process_recurring_downtimes_page_edit {
    my($c, $nr, $default_rd, $rd) = @_;
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
    my( $c ) = @_;
    my $host;

    my $backend = $c->req->parameters->{'backend'} || '';
    my $hostname = $c->req->parameters->{'host'};
    return $c->detach('/error/index/5') unless defined $hostname;
    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi#host?host=".$hostname);
    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ], extra_columns => [qw/long_plugin_output contacts/] );

    return $c->detach('/error/index/5') unless defined $hosts;

    # we only got one host
    $host = $hosts->[0];

    # we have more and backend param is used
    if( scalar @{$hosts} == 1 and $backend ) {
        for my $h ( @{$hosts} ) {
            if( $h->{'peer_key'} eq $backend ) {
                $host = $h;
                last;
            }
        }
    }
    elsif( scalar @{$hosts} == 1) {
        $c->stash->{'param_backend'} = $host->{'peer_key'};
    }

    return $c->detach('/error/index/5') unless defined $host;

    my @backends;
    for my $h ( @{$hosts} ) {
        push @backends, $h->{'peer_key'};
    }
    _set_backend_selector( $c, \@backends, $host->{'peer_key'} );

    $c->stash->{'host'} = $host;

    # comments
    my $cmt_sorttype   = $c->req->parameters->{'sorttype_cmt'}   || 2;
    my $cmt_sortoption = $c->req->parameters->{'sortoption_cmt'} || 3;
    my $cmt_order      = "ASC";
    $cmt_order = "DESC" if $cmt_sorttype == 2;
    $cmt_sortoption = 1 if !defined _get_comment_sort_option($cmt_sortoption);
    $c->stash->{'cmt_orderby'}    = _get_comment_sort_option($cmt_sortoption)->[1];
    $c->stash->{'cmt_orderdir'}   = $cmt_order;
    $c->stash->{'sortoption_cmt'} = $c->req->parameters->{'sortoption_cmt'} || '';

    $c->stash->{'comments'}  = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { $cmt_order => _get_comment_sort_option($cmt_sortoption)->[0] } );

    # downtimes
    my $dtm_sorttype   = $c->req->parameters->{'sorttype_dtm'}   || 2;
    my $dtm_sortoption = $c->req->parameters->{'sortoption_dtm'} || 3;
    my $dtm_order      = "ASC";
    $dtm_order = "DESC" if $dtm_sorttype == 2;
    $dtm_sortoption = 1 if !defined _get_comment_sort_option($dtm_sortoption);
    $c->stash->{'dtm_orderby'}    = _get_comment_sort_option($dtm_sortoption)->[1];
    $c->stash->{'dtm_orderdir'}   = $dtm_order;
    $c->stash->{'sortoption_dtm'} = $c->req->parameters->{'sortoption_dtm'} || '';

    $c->stash->{'downtimes'} = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { $dtm_order => _get_comment_sort_option($dtm_sortoption)->[0] } );

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
    $c->stash->{'pnp_url'}    = Thruk::Utils::get_pnp_url($c, $host);
    $c->stash->{'pnp_source'} = $custvars->{'GRAPH_SOURCE'} || '0';

    # grafana graph?
    $c->stash->{'histou_url'}    = Thruk::Utils::get_histou_url($c, $host);
    $c->stash->{'histou_source'} = $custvars->{'GRAPH_SOURCE'} || $c->config->{'grafana_default_panelId'} || '1';

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
    my( $c ) = @_;

    my $hostgroup = $c->req->parameters->{'hostgroup'};
    return $c->detach('/error/index/5') unless defined $hostgroup;

    my $groups = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) , 'name' => $hostgroup ], limit => 1 );
    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'hostgroup'}       = $groups->[0];
    return 1;
}

##########################################################
# create the service info page
sub _process_service_page {
    my( $c ) = @_;
    my $service;
    my $backend = $c->req->parameters->{'backend'} || '';

    my $hostname = $c->req->parameters->{'host'};
    return $c->detach('/error/index/15') unless defined $hostname;

    my $servicename = $c->req->parameters->{'service'};
    return $c->detach('/error/index/15') unless defined $servicename;

    return if Thruk::Utils::choose_mobile($c, $c->stash->{'url_prefix'}."cgi-bin/mobile.cgi#service?host=".$hostname."&service=".$servicename);

    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $servicename } ], extra_columns => [qw/long_plugin_output contacts/] );

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
    _set_backend_selector( $c, \@backends, $service->{'peer_key'} );

    $c->stash->{'service'} = $service;

    # comments
    my $cmt_sorttype   = $c->req->parameters->{'sorttype_cmt'}   || 2;
    my $cmt_sortoption = $c->req->parameters->{'sortoption_cmt'} || 3;
    my $cmt_order      = "ASC";
    $cmt_order = "DESC" if $cmt_sorttype == 2;
    $cmt_sortoption = 1 if !defined _get_comment_sort_option($cmt_sortoption);
    $c->stash->{'cmt_orderby'}    = _get_comment_sort_option($cmt_sortoption)->[1];
    $c->stash->{'cmt_orderdir'}   = $cmt_order;
    $c->stash->{'sortoption_cmt'} = $c->req->parameters->{'sortoption_cmt'} || '';

    $c->stash->{'comments'} = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { $cmt_order => _get_comment_sort_option($cmt_sortoption)->[0] } );

    # downtimes
    my $dtm_sorttype   = $c->req->parameters->{'sorttype_dtm'}   || 2;
    my $dtm_sortoption = $c->req->parameters->{'sortoption_dtm'} || 3;
    my $dtm_order      = "ASC";
    $dtm_order = "DESC" if $dtm_sorttype == 2;
    $dtm_sortoption = 1 if !defined _get_comment_sort_option($dtm_sortoption);
    $c->stash->{'dtm_orderby'}    = _get_comment_sort_option($dtm_sortoption)->[1];
    $c->stash->{'dtm_orderdir'}   = $dtm_order;
    $c->stash->{'sortoption_dtm'} = $c->req->parameters->{'sortoption_dtm'} || '';

    $c->stash->{'downtimes'} = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { $dtm_order => _get_comment_sort_option($dtm_sortoption)->[0] } );

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
    $c->stash->{'pnp_url'}    = Thruk::Utils::get_pnp_url($c, $service);
    $c->stash->{'pnp_source'} = $custvars->{'GRAPH_SOURCE'} || '0';

    # grafana graph?
    $c->stash->{'histou_url'}    = Thruk::Utils::get_histou_url($c, $service);
    $c->stash->{'histou_source'} = $custvars->{'GRAPH_SOURCE'} || $c->config->{'grafana_default_panelId'} || '1';

    # other graphs?
    $c->stash->{'graph_url'} = Thruk::Utils::get_graph_url($c, $service);

    # recurring downtimes
    $c->stash->{'recurring_downtimes'} = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 1, $hostname, $servicename);

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, {'host' => $service, 'service' => $service, add_host => 1});

    return 1;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my( $c ) = @_;

    my $servicegroup = $c->req->parameters->{'servicegroup'};
    return $c->detach('/error/index/5') unless defined $servicegroup;

    my $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), name => $servicegroup ], limit => 1);

    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'servicegroup'}       = $groups->[0];

    return 1;
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my( $c ) = @_;

    my $sorttype   = $c->req->parameters->{'sorttype'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption'} || 7;

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
    my( $c ) = @_;

    return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    if($view_mode eq 'json') {
        my $merged = {};
        for my $name (qw/pi_detail backend_detail/) {
            for my $key (keys %{$c->stash->{$name}}) {
                for my $attr (keys %{$c->stash->{$name}->{$key}}) {
                    $merged->{$key}->{$attr} = $c->stash->{$name}->{$key}->{$attr};
                }
            }
        }
        return $c->render(json => $merged);
    }
    return 1;
}

##########################################################
# create the performance info page
sub _process_perf_info_page {
    my( $c ) = @_;

    # apache statistics
    $c->stash->{'apache_status'} = [];
    if(    $c->check_user_roles("authorized_for_configuration_information")
       and $c->check_user_roles("authorized_for_system_information")) {
        my $apache = $c->req->parameters->{'apache'};

        # autodetect omd apaches
        if(scalar keys %{$c->config->{'apache_status'}} == 0 && $ENV{'OMD_ROOT'}) {
            my $root      = $ENV{'OMD_ROOT'};
            my($siteport) = (`grep CONFIG_APACHE_TCP_PORT $root/etc/omd/site.conf` =~ m/(\d+)/mx);
            my($ssl)      = (`grep CONFIG_APACHE_MODE     $root/etc/omd/site.conf` =~ m/'(\w+)'/mx);
            my $proto     = $ssl eq 'ssl' ? 'https' : 'http';
            $c->config->{'apache_status'} = {
                'Site'   => $proto.'://127.0.0.1:'.$siteport.'/server-status',
                'System' => $proto.'://127.0.0.1/server-status',
            };
        }

        for my $name (keys %{$c->config->{'apache_status'}}) {
            push @{$c->stash->{'apache_status'}}, $name;
        }

        if($apache and $c->config->{'apache_status'}->{$apache}) {
            _apache_status($c, $apache, $c->config->{'apache_status'}->{$apache});
            $c->stash->{template} = 'extinfo_type_4_apache_status.tt';
            return 1;
        }
    }

    # cluster statistics
    if(    $c->check_user_roles("authorized_for_configuration_information")
       and $c->check_user_roles("authorized_for_system_information")) {
        if($c->req->parameters->{'cluster'} && $c->cluster->is_clustered) {
            return _process_perf_info_cluster_page($c);
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

    # add lmd cache statistics
    $c->stash->{'has_lmd'} = 0;
    if($c->config->{'use_lmd_core'}) {
        $c->stash->{'has_lmd'}   = 1;
        $c->stash->{'lmd_stats'} = $c->{'db'}->lmd_stats($c);
    }

    return 1;
}

##########################################################
# create the performance info cluster page
sub _process_perf_info_cluster_page {
    my( $c ) = @_;

    my $clusternodes = Thruk::Utils::array2hash($c->cluster->{'nodes'});
    if($c->req->parameters->{'state'}) {
        my $nodeurl = $c->req->parameters->{'node'};
        if(!$clusternodes->{$nodeurl}) {
            return $c->render(json => { ok => 0, error => "no such node" });
        }
        my($state, $reponsetime, undef) = $c->cluster->ping($nodeurl);
        return $c->render(json => { ok => $state, response_time => sprintf("%.3f", $reponsetime) });
    }

    $c->stash->{template} = 'extinfo_type_4_cluster_status.tt';
    return 1;
}

##########################################################
# create the grafana page
sub _process_grafana_page {
    my($c) = @_;

    my $format = $c->req->parameters->{'format'} || 'png';
    $c->res->body(Thruk::Utils::get_perf_image($c, {
        host        => $c->req->parameters->{'host'},
        service     => $c->req->parameters->{'service'},
        start       => $c->req->parameters->{'from'},
        end         => $c->req->parameters->{'to'},
        width       => $c->req->parameters->{'width'} || 800,
        height      => $c->req->parameters->{'height'} || 300,
        source      => $c->req->parameters->{'source'} || 1,
        format      => $format,
        show_title  => !$c->req->parameters->{'disablePanelTitle'},
        show_legend => $c->req->parameters->{'legend'} // 1,
    }));
    $c->{'rendered'} = 1;
    if($format eq 'png') {
        $c->res->headers->content_type('image/png');
    }
    elsif($format eq 'pdf') {
        $c->res->headers->content_type('application/pdf');
    }
    return 1;
}

##########################################################
# show backend selector
sub _set_backend_selector {
    my( $c, $backends, $selected ) = @_;
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
    my $cookie = $c->cookie('thruk_auth');
    $ua->default_header('Cookie' => 'thruk_auth='.$cookie->value) if $cookie;
    $ua->default_header('Authorization' => $c->req->header('authorization')) if $c->req->header('authorization');
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

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
