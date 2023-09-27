package Thruk::Controller::extinfo;

use warnings;
use strict;

use Thruk::Action::AddDefaults ();
use Thruk::Backend::Manager ();
use Thruk::UserAgent ();
use Thruk::Utils::Auth ();
use Thruk::Utils::External ();
use Thruk::Utils::Status ();

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

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_DEFAULTS);

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
    elsif( $type eq 'dtree' ) {
        return(_process_dtree_page($c));
    }
    elsif(!Thruk::Backend::Manager::looks_like_number($type) || $type == 0 ) {
        $infoBoxTitle = 'Process Information';
        return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
        $c->stash->{template} = 'extinfo_type_0.tt';
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
    } else {
        return $c->detach('/error/index/25');
    }

    $c->stash->{infoBoxTitle} = $infoBoxTitle;
    Thruk::Utils::ssi_include($c);

    Thruk::Action::AddDefaults::set_custom_title($c);

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
        '10'=> [ [ 'peer_name' ],                          'site' ],
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
        '12' =>[ [ 'peer_name' ],                          'site' ],
    };

    return $sortoptions->{$option};
}

##########################################################
# create the comments page
sub _process_comments_page {
    my($c) = @_;
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';

    my $sorttype   = $c->req->parameters->{'sorttype'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption'} || 1;
    my $order      = "ASC";
    $order         = "DESC" if $sorttype eq "2";
    $sortoption    = 1 if !defined _get_comment_sort_option($sortoption);

    $c->stash->{'data_sorted'} = { type => $sorttype, option => $sortoption };

    $c->stash->{'host'}       = $c->req->parameters->{'host'}    // "";
    $c->stash->{'service'}    = $c->req->parameters->{'service'} // "";
    $c->stash->{'pattern'}    = $c->req->parameters->{'pattern'} // "";

    my $filter = [];
    if($c->stash->{'host'})    { push @{$filter}, { host_name           => $c->stash->{'host'} }; }
    if($c->stash->{'service'}) { push @{$filter}, { service_description => $c->stash->{'service'} }; }
    if($c->stash->{'pattern'}) {
        push @{$filter}, { '-or' => [
            { host_name           => { '~~' => $c->stash->{'pattern'} } },
            { service_description => { '~~' => $c->stash->{'pattern'} } },
            { comment             => { '~~' => $c->stash->{'pattern'} } },
            { author              => { '~~' => $c->stash->{'pattern'} } },
        ]};
    }
    $c->stash->{'has_filter'} = scalar @{$filter} > 0 ? 1 : 0;

    my $comments = $c->db->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), $filter ],
                                        sort   => { $order => _get_comment_sort_option($sortoption)->[0] },
                                        pager  => 1,
                                       );

    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c, [''], 'comment');
        $c->res->headers->header( 'Content-Disposition', 'attachment; filename="comments.xls"' );
        $c->stash->{'template'} = 'excel/comments.tt';
        $c->stash->{'data'}     = $comments;
        return $c->render_excel();
    }
    if($view_mode eq 'json') {
        return $c->render(json => $comments);
    }

    # add extra information required to set hostname / service description
    if($c->config->{'host_name_source'} || $c->config->{'service_description_source'}) {
        _set_host_extra_info_from_com_down($c, $comments);
        _set_service_extra_info_from_com_down($c, $comments);
    }

    return 1;
}

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my( $c ) = @_;
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';

    my $sorttype   = $c->req->parameters->{'sorttype'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption'} || 1;
    my $order      = "ASC";
    $order         = "DESC" if $sorttype == 2;
    $sortoption    = 1 if !defined _get_downtime_sort_option($sortoption);

    $c->stash->{'data_sorted'} = { type => $sorttype, option => $sortoption };

    $c->stash->{'host'}       = $c->req->parameters->{'host'}    // "";
    $c->stash->{'service'}    = $c->req->parameters->{'service'} // "";
    $c->stash->{'pattern'}    = $c->req->parameters->{'pattern'} // "";

    my $filter = [];
    if($c->stash->{'host'})    { push @{$filter}, { host_name           => $c->stash->{'host'} }; }
    if($c->stash->{'service'}) { push @{$filter}, { service_description => $c->stash->{'service'} }; }
    if($c->stash->{'pattern'}) {
        push @{$filter}, { '-or' => [
            { host_name           => { '~~' => $c->stash->{'pattern'} } },
            { service_description => { '~~' => $c->stash->{'pattern'} } },
            { comment             => { '~~' => $c->stash->{'pattern'} } },
            { author              => { '~~' => $c->stash->{'pattern'} } },
        ]};
    }
    $c->stash->{'has_filter'} = scalar @{$filter} > 0 ? 1 : 0;

    my $downtimes  = $c->db->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), $filter ],
                                           sort   => { $order => _get_downtime_sort_option($sortoption)->[0] },
                                           pager  => 1,
                                       );

    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c, [''], 'downtime');
        $c->res->headers->header( 'Content-Disposition', 'attachment; filename="downtimes.xls"' );
        $c->stash->{'template'} = 'excel/downtimes.tt';
        $c->stash->{'data'}     = $downtimes;
        return $c->render_excel();
    }
    if($view_mode eq 'json') {
        return $c->render(json => $downtimes);
    }

    # add extra information required to set hostname / service description
    if($c->config->{'host_name_source'} || $c->config->{'service_description_source'}) {
        _set_host_extra_info_from_com_down($c, $downtimes);
        _set_service_extra_info_from_com_down($c, $downtimes);
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
        return unless Thruk::Utils::check_csrf($c);
        my $backends = Thruk::Base::list($c->req->parameters->{'d_backends'} // []);
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
            'edited_by'     => $c->stash->{'remote_user'},
            'last_changed'  => time(),
            'created_by'    => $c->stash->{'remote_user'},
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

        my $old_file;
        if($nr && !$failed) {
            $old_file  = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
            if(-s $old_file) {
                my $old_rd = Thruk::Utils::read_data_file($old_file);
                if(Thruk::Utils::RecurringDowntimes::check_downtime_permissions($c, $old_rd) != 2) {
                    $failed = 1;
                } else {
                    $rd->{'created_by'} = $old_rd->{'created_by'};
                }
            }
        }
        return _process_recurring_downtimes_page_edit($c, $nr, $default_rd, $rd) if $failed;
        my $file = $old_file || Thruk::Utils::RecurringDowntimes::get_data_file_name($c);
        Thruk::Utils::RecurringDowntimes::write_downtime($c, $file, $rd);
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
        return unless Thruk::Utils::check_csrf($c);
        my $numbers = [];
        if($c->req->parameters->{'selected_ids'}) {
            $numbers = [map({
                my $name = $_;
                $name =~ s/^recurring_//mx;
                $name;
            } split(/\s*,\s*/mx, $c->req->parameters->{'selected_ids'}))];
        } else {
            $numbers = [$nr];
        }
        for my $nr (@{$numbers}) {
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
        }
        Thruk::Utils::RecurringDowntimes::update_cron_file($c);
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=6&recurring");
    }
    elsif($task eq 'fix') {
        return unless Thruk::Utils::check_csrf($c);
        my $file = $c->config->{'var_path'}.'/downtimes/'.$nr.'.tsk';
        Thruk::Utils::RecurringDowntimes::fix_downtime($c, $file);
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
            $c->stash->{rd} = Thruk::Utils::RecurringDowntimes::read_downtime($c, $file, undef, undef, undef, undef, undef, undef, undef, 0);
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
    my $hosts = $c->db->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ], extra_columns => [qw/long_plugin_output contacts/] );

    return $c->detach('/error/index/5') if(!defined $hosts || !defined $hosts->[0]);

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

    $host->{'depends'}        = Thruk::Utils::merge_host_dependencies($host->{'depends_exec'}, $host->{'depends_notify'});
    $host->{'depends_exec'}   = Thruk::Utils::merge_host_dependencies($host->{'depends_exec'});
    $host->{'depends_notify'} = Thruk::Utils::merge_host_dependencies($host->{'parents'}, $host->{'depends_notify'});

    # comments
    my $cmt_sorttype   = $c->req->parameters->{'sorttype_cmt'}   || 2;
    my $cmt_sortoption = $c->req->parameters->{'sortoption_cmt'} || 3;
    my $cmt_order      = "ASC";
    $cmt_order = "DESC" if $cmt_sorttype == 2;
    $cmt_sortoption = 1 if !defined _get_comment_sort_option($cmt_sortoption);
    $c->stash->{'cmt_orderby'}    = _get_comment_sort_option($cmt_sortoption)->[1];
    $c->stash->{'cmt_orderdir'}   = $cmt_order;
    $c->stash->{'sortoption_cmt'} = $c->req->parameters->{'sortoption_cmt'} || '';

    $c->stash->{'comments'}  = $c->db->get_comments(
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

    $c->stash->{'downtimes'} = $c->db->get_downtimes(
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
            my $command            = $c->db->expand_command('host' => $host, 'source' => $c->config->{'show_full_commandline_source'} );
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

    # show info about a stale host
    my($nodes, $edges) = ({}, []);
    _fill_dependencies($c, $host, $nodes, $edges);
    $c->stash->{'stale_hint'}   = _check_stale_check($c, $host, $nodes);
    $c->stash->{'parent_nodes'} = $nodes;

    return 1;
}

##########################################################
# create the hostgroup cmd page
sub _process_hostgroup_cmd_page {
    my( $c ) = @_;

    my $hostgroup = $c->req->parameters->{'hostgroup'};
    return $c->detach('/error/index/5') unless defined $hostgroup;

    my $groups = $c->db->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) , 'name' => $hostgroup ], limit => 1 );
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

    my $services = $c->db->get_services(
            filter        => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ),
                               { 'host_name' => $hostname },
                               { 'description' => $servicename },
                             ],
            extra_columns => [qw/long_plugin_output contacts/],
    );

    return $c->detach('/error/index/15') if(!defined $services || !defined $services->[0]);

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
    $service->{'depends'}         = Thruk::Utils::merge_service_dependencies($service, $service->{'parents'}, $service->{'depends_exec'}, $service->{'depends_notify'});
    $service->{'depends_exec'}    = Thruk::Utils::merge_service_dependencies($service, $service->{'depends_exec'});
    $service->{'depends_notify'}  = Thruk::Utils::merge_service_dependencies($service, $service->{'depends_notify'});
    $service->{'depends_parents'} = Thruk::Utils::merge_service_dependencies($service, $service->{'parents'});

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

    $c->stash->{'comments'} = $c->db->get_comments(
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

    $c->stash->{'downtimes'} = $c->db->get_downtimes(
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
       ($c->stash->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ))) {
        $c->stash->{'command'} = $c->db->expand_command('host' => $service, 'service' => $service, 'source' => $c->config->{'show_full_commandline_source'} );
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

    # show info about a stale service
    my($nodes, $edges) = ({}, []);
    _fill_dependencies($c, $service, $nodes, $edges);
    $c->stash->{'stale_hint'}   = _check_stale_check($c, $service, $nodes);
    $c->stash->{'parent_nodes'} = $nodes;

    return 1;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my( $c ) = @_;

    my $servicegroup = $c->req->parameters->{'servicegroup'};
    return $c->detach('/error/index/5') unless defined $servicegroup;

    my $groups = $c->db->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), name => $servicegroup ], limit => 1);

    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'servicegroup'}       = $groups->[0];

    return 1;
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my( $c ) = @_;

    my $style = $c->req->parameters->{'style'} || 'queue';
    if($style ne 'queue') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    # do the filtering
    my($hostfilter, $servicefilter) = Thruk::Utils::Status::do_filter($c, undef, undef, 1);
    return if $c->stash->{'has_error'};

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

    $c->db->get_scheduling_queue($c,
                                 hostfilter     => $hostfilter,
                                 servicefilter  => $servicefilter,
                                 sort           => { $order => $sortoptions->{$sortoption}->[0] },
                                 pager          => 1,
                                );

    Thruk::Utils::Status::set_default_stash($c);
    $c->stash->{'data_sorted'} = { type => $sorttype, option => $sortoption };
    $c->stash->{'style'}       = 'queue';
    $c->stash->{'substyle'}    = 'service';
    $c->stash->{'show_substyle_selector'} = 0;
    $c->stash->{'extra_params'} = [{ "name" => "type", "value" => "7" }];

    return 1;
}

##########################################################
# create the process info page
sub _process_process_info_page {
    my( $c ) = @_;

    return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");

    my $list_mode = $c->req->parameters->{'list'};
    if($c->stash->{'backends'} && scalar @{$c->stash->{'backends'}} > 5) {
        $list_mode = 'list' unless defined $list_mode;
        my $backends = [];
        for my $key (@{$c->stash->{'backends'}}) {
            push @{$backends}, {
                peer_key  => $key,
                peer_name => $c->stash->{'backend_detail'}->{$key}->{'name'},
                section   => $c->stash->{'backend_detail'}->{$key}->{'section'},
            };
        }
        $backends = Thruk::Backend::Manager::sort_result($c, $backends, { 'ASC' => [ 'section', 'peer_name' ] });
        $c->stash->{'backends'} = [];
        for my $p (@{$backends}) {
            push @{$c->stash->{'backends'}}, $p->{'peer_key'};
        }
    }
    $c->stash->{'list_mode'} = $list_mode // 'details';

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
        if($c->req->parameters->{'cluster'}) {
            return _process_perf_info_cluster_page($c);
        }
    }

    # logcache statistics
    if(    $c->check_user_roles("authorized_for_configuration_information")
       and $c->check_user_roles("authorized_for_system_information")) {
        if($c->req->parameters->{'logcachedetails'}) {
            return _process_perf_info_logcache_details($c);
        }
    }

    $c->stash->{'stats'}      = $c->db->get_performance_stats( services_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], hosts_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    $c->stash->{'perf_stats'} = $c->db->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );

    # add logfile cache statistics
    $c->stash->{'has_logcache'}   = 0;
    $c->stash->{'logcache_error'} = '';
    if($c->config->{'logcache'}) {
        eval {
            my $stats = [sort { $a->{'name'} cmp $b->{'name'} } values %{$c->db->logcache_stats($c, 1)}];
            $c->stash->{'logcache_stats'} = $stats;
            $c->stash->{'has_logcache'} = 1;
        };
        if($@) {
            $c->stash->{'logcache_error'} = $@;
            $c->stash->{'logcache_error'} =~ s/\ at\ .*?\ line\ \d+\.//gmx;
        }
    }

    # add lmd cache statistics
    if($ENV{'THRUK_USE_LMD'}) {
        # sort them the same way as lmd stats
        $c->stash->{'lmd_stats'} = [sort { $a->{'name'} cmp $b->{'name'} } @{$c->db->lmd_stats($c)}];
    }

    return 1;
}

##########################################################
# create the performance info cluster page
sub _process_perf_info_cluster_page {
    my($c) = @_;
    $c->cluster->load_statefile();
    if(defined $c->req->parameters->{'maint'}) {
        return unless Thruk::Utils::check_csrf($c);
        my $node = $c->cluster->{'nodes_by_id'}->{$c->req->parameters->{'node'}};
        if(!$node) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such cluster node', code => 404 });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=4&cluster=1");
        }
        if($c->req->parameters->{'maint'}) {
            $c->cluster->maint($node, time());
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => sprintf('cluster node %s put into maintenance mode', $node->{'hostname'}) });
        } else {
            $c->cluster->maint($node, 0);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => sprintf('maintenance mode for cluster node %s removed', $node->{'hostname'}) });
        }
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=4&cluster=1");
    }
    $c->stash->{template} = 'extinfo_type_4_cluster_status.tt';
    return 1;
}

##########################################################
# create the dependency tree page
sub _process_dtree_page {
    my($c) = @_;

    my $hostname    = $c->req->parameters->{'host'}    // '';
    my $servicename = $c->req->parameters->{'service'} // '';

    my $obj;
    if($servicename) {
        my $services = $c->db->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $servicename } ]);
        $obj = $services->[0];
    } else {
        my $hosts = $c->db->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ]);
        $obj = $hosts->[0];
    }

    my($nodes, $edges) = ({}, []);
    _fill_dependencies($c, $obj, $nodes, $edges);

    $c->stash->{'edges'}           = $edges;
    $c->stash->{'nodes'}           = _dtree_nodes($nodes);

    $c->stash->{'host'}            = $hostname;
    $c->stash->{'service'}         = $servicename;
    $c->stash->{'title'}           = 'Dependency Tree';
    $c->stash->{'infoBoxTitle'}    = 'Dependency Tree';
    return 1;
}

##########################################################
sub _fill_dependencies {
    my($c, $obj, $nodes, $edges) = @_;
    return unless defined $obj;

    my($depends, $name, $id);
    if($obj->{'description'}) {
        $name = $obj->{'host_name'}.';'.$obj->{'description'};
        return if $nodes->{$name};
        $depends = Thruk::Utils::merge_service_dependencies($obj, [[$obj->{'host_name'}]], $obj->{'parents'}, $obj->{'depends_exec'}, $obj->{'depends_notify'});
        $nodes->{$name} = $obj;
    } else {
        $name = $obj->{'name'};
        return if $nodes->{$name};
        $depends = Thruk::Utils::merge_host_dependencies($obj->{'parents'}, $obj->{'depends_notify'}, $obj->{'depends_exec'});
        $nodes->{$name} = $obj;
    }
    $id = "n".(scalar keys %{$nodes});
    $obj->{'node_id'} = $id;

    for my $dep (@{$depends}) {
        $dep = Thruk::Utils::list($dep);
        if(scalar @{$dep} == 1) {
            # host dependency
            my $depname = $dep->[0];
            my $hst = $nodes->{$depname};
            if(!$hst) {
                my $hosts = $c->db->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), name => $depname ] );
                $hst = $hosts->[0];
            }
            _fill_dependencies($c, $hst, $nodes, $edges);
            push @{$edges}, { from => $id, to => $hst->{'node_id'} };
        } else {
            # service dependency
            my $depname = $dep->[0].';'.$dep->[1];
            my $svc = $nodes->{$depname};
            if(!$svc) {
                my $services = $c->db->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $dep->[0] }, { 'description' => $dep->[1] } ]);
                $svc = $services->[0];
            }
            _fill_dependencies($c, $svc, $nodes, $edges);
            push @{$edges}, { from => $id, to => $svc->{'node_id'} };
        }
    }

    return;
}

##########################################################
sub _dtree_nodes {
    my($objs) = @_;
    my $nodes = [];
    for my $key (sort keys %{$objs}) {
        my $o = $objs->{$key};
        my($name, $state);
        my $data = {
            peer_key => $o->{'peer_key'},
        };
        my $shape = "ellipse";
        if($o->{'description'}) {
            $name = $o->{'host_name'}.' - '.$o->{'description'};
            if(!$o->{'has_been_checked'}) { $state = "pending"; }
            elsif($o->{'state'} == 0)     { $state = "ok"; }
            elsif($o->{'state'} == 1)     { $state = "warning"; }
            elsif($o->{'state'} == 2)     { $state = "critical"; }
            elsif($o->{'state'} == 3)     { $state = "unknown"; }
            $data = {
                host_name   => $o->{'host_name'},
                description => $o->{'description'},
            };
        } else {
            $name  = $o->{'name'};
            $shape = "box";
            if(!$o->{'has_been_checked'}) { $state = "pending"; }
            elsif($o->{'state'} == 0)     { $state = "up"; }
            elsif($o->{'state'} == 1)     { $state = "down"; }
            elsif($o->{'state'} == 2)     { $state = "unreachable"; }
            $data = {
                host_name   => $o->{'name'},
            };
        }
        push @{$nodes}, {
            id    => $o->{'node_id'},
            label => $name,
            color => {
                background => 'var(--badge-'.$state.'-bg)',
                hover => {
                    border => 'var(--border-active)',
                    background => 'var(--badge-'.$state.'-bg)',
                },
            },
            font => {
                color => 'var(--badge-'.$state.'-fg)',
            },
            shape => $shape,
            data => $data,
        };
    }
    return($nodes);
}

##########################################################
sub _check_stale_check {
    my($c, $obj, $nodes) = @_;

    # not yet checked at all
    return(0) unless $obj->{'has_been_checked'};

    # active checks disabled?
    return(0) unless $obj->{'active_checks_enabled'};

    # active checks?
    return(0) unless $obj->{'check_type'} == 0;

    return(0) unless $obj->{'in_check_period'};

    # do dependencies exist
    return(0) unless(scalar @{$obj->{'depends_exec'}||[]} > 0 || scalar @{$obj->{'parents'}||[]} > 0);

    my $peer_key       = $obj->{'peer_key'};
    my $check_interval = $obj->{'check_interval'} * $c->stash->{'pi_detail'}->{$peer_key}->{'interval_length'};

    # wait at least twice of the normal check interval
    if($obj->{'last_check'} > time() - $check_interval * 2) {
        return(0);
    }

    # did any of the parents fail?
    my $worst = 0;
    for my $parent (values %{$nodes}) {
        $worst = $parent->{'state'} if $parent->{'state'} > $worst;
    }
    return(0) if $worst == 0;

    return(1);
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
        theme       => $c->req->parameters->{'theme'},
        font_color  => $c->req->parameters->{'font_color'},
        bg_color    => $c->req->parameters->{'background_color'},
    }));
    return 1 if $c->{'rendered'};
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
    my $possible_backends = $c->db->peer_key();
    for my $back (@{$possible_backends}) {
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
    local $ENV{'HTTPS_PROXY'} = undef if exists $ENV{'HTTPS_PROXY'};
    local $ENV{'HTTP_PROXY'}  = undef if exists $ENV{'HTTP_PROXY'};
    my $ua = Thruk::UserAgent->new({}, $c->config);
    $ua->timeout(10);
    Thruk::UserAgent::disable_verify_hostname($ua);
    $ua->max_redirect(0);
    # pass through authentication
    my $cookie = $c->cookies('thruk_auth');
    $ua->default_header('Cookie' => 'thruk_auth='.$cookie.'; HttpOnly') if $cookie;
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

##########################################################
# create the performance info logcache details
sub _process_perf_info_logcache_details {
    my($c) = @_;
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{infoBoxTitle}     = "Logcache Statistics";

    my $peer_key = $c->req->parameters->{'logcachedetails'};
    my $peer     = $c->db->get_peer_by_key($peer_key);
    if(!$peer) {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such backend' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=4");
    }
    if(!$c->config->{'logcache'} || !$peer->{'logcache'}) {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'logcache is disabled' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=4");
    }

    my $action = $c->req->parameters->{'submit'};
    if($action) {
        return unless Thruk::Utils::check_csrf($c);
        if($action eq 'update' || $action eq 'clean' || $action eq 'compact') {
            return(Thruk::Utils::External::cmd($c, {
                cmd            => $c->config->{'thruk_bin'}." logcache $action -v --local -b $peer_key 2>&1",
                message        => 'logcache will be '.$action.'ed...',
                forward        => 'extinfo.cgi?type=4&logcachedetails='.$peer_key,
                show_output    => 1,
            }));
        }
        if($action eq 'optimize') {
            return(Thruk::Utils::External::cmd($c, {
                cmd            => $c->config->{'thruk_bin'}." logcache optimize -v -f --local -b $peer_key 2>&1",
                message        => 'logcache will be optimized...',
                forward        => 'extinfo.cgi?type=4&logcachedetails='.$peer_key,
                show_output    => 1,
            }));
        }
    }

    return if Thruk::Utils::External::render_page_in_background($c);

    my $logcache_stats = $c->db->logcache_stats($c, 1, [$peer_key]);
    if(!$logcache_stats->{$peer_key}) {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'failed to fetch logcache statistics' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/extinfo.cgi?type=4");
    }
    $c->stash->{'logcache_stats'} = $logcache_stats->{$peer_key};
    $c->stash->{'logcache_types'} = $peer->logcache()->_logcache_stats_types($c, "type", [$peer_key])->[0]->{'types'};
    $c->stash->{'logcache_class'} = $peer->logcache()->_logcache_stats_types($c, "class", [$peer_key])->[0]->{'types'};
    require Thruk::Backend::Provider::Mysql;
    my $db_classes = Thruk::Base::hash_invert($Thruk::Backend::Provider::Mysql::db_classes);
    for my $t (@{$c->stash->{'logcache_class'}}) {
        $t->{'param'} = $t->{'class'} // '';
        $t->{'type'}  = $db_classes->{$t->{'class'}} // $t->{'class'};
    }
    for my $t (@{$c->stash->{'logcache_types'}}) {
        $t->{'param'} = $t->{'type'} // '';
    }

    $c->stash->{peer}     = $peer;
    $c->stash->{peer_key} = $peer_key;
    $c->stash->{template} = 'extinfo_type_4_logcache_details.tt';
    return 1;
}

##########################################################
sub _set_host_extra_info_from_com_down {
    my($c, $comments) = @_;

    my $uniq = {};
    for my $com (@{$comments}) {
        $uniq->{$com->{'host_name'}} = 1;
    }
    my @uniq = sort keys %{$uniq};
    my $hostfilter = [];
    if(scalar @uniq <= 100) {
        my @hostfilter;
        for my $hst (@uniq) {
            push @hostfilter, {'name' => $hst};
        }
        $hostfilter = Thruk::Utils::combine_filter('-or', \@hostfilter);
    }

    my $data = $c->db->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'comments' => {'!=' => '' } }, $hostfilter ] );
    my $hosts = {};
    for my $d (@{$data}) {
        $hosts->{$d->{'name'}} = $d;
    }
    $c->stash->{'host_extra_info'} = $hosts;
    return;
}

##########################################################
sub _set_service_extra_info_from_com_down {
    my($c, $comments) = @_;

    my $uniq = {};
    for my $com (@{$comments}) {
        $uniq->{$com->{'host_name'}} = 1;
    }
    my @uniq = sort keys %{$uniq};
    my $hostfilter = [];
    if(scalar @uniq <= 100) {
        my @hostfilter;
        for my $hst (@uniq) {
            push @hostfilter, {'host_name' => $hst};
        }
        $hostfilter = Thruk::Utils::combine_filter('-or', \@hostfilter);
    }

    my $data = $c->db->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'comments' => {'!=' => '' } }, $hostfilter ] );
    my $services = {};
    for my $d (@{$data}) {
        $services->{$d->{'host_name'}}->{$d->{'description'}} = $d;
    }
    $c->stash->{'service_extra_info'} = $services;
    return;
}

##########################################################

1;
