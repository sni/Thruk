package Thruk::Controller::bp;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::bp - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(!$c->config->{'bp_modules_loaded'}) {
        require Data::Dumper;
        require Thruk::BP::Utils;
        # loading Clone makes BPs with filters lot faster
        eval {
            require Clone;
        };
        $c->config->{'bp_modules_loaded'} = 1;
    }

    my $action = $c->req->parameters->{'action'} || 'show';
    my $style  = $c->req->parameters->{'style'};
    if($style && $action ne 'list_objects') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    $c->stash->{title}                 = 'Business Process';
    $c->stash->{page}                  = 'status';
    $c->stash->{template}              = 'bp.tt';
    $c->stash->{subtitle}              = 'Business Process';
    $c->stash->{infoBoxTitle}          = 'Business Process';
    $c->stash->{'has_jquery_ui'}       = 1;
    $c->stash->{'disable_backspace'}   = 1;
    $c->stash->{editmode}              = 0;
    $c->stash->{testmode}              = $c->req->parameters->{'testmode'} || 0;
    $c->stash->{debug}                 = $c->req->parameters->{'debug'} || 0;
    $c->stash->{highlight_node}        = $c->req->parameters->{'node'} || '';
    $c->stash->{testmodes}             = {};
    $c->stash->{'objects_templates_file'} = $c->config->{'Thruk::Plugin::BP'}->{'objects_templates_file'} || '';
    $c->stash->{'objects_save_file'}      = $c->config->{'Thruk::Plugin::BP'}->{'objects_save_file'}      || '';
    my $format = $c->config->{'Thruk::Plugin::BP'}->{'objects_save_format'} || 'nagios';
    if($format ne 'icinga2') { $format = 'nagios'; }
    $c->stash->{'objects_save_format'}  = $format;
    my $id = $c->req->parameters->{'bp'} || '';
    if($id !~ m/^\d+$/mx and $id ne 'new') { $id = ''; }
    my $nodeid = $c->req->parameters->{'node'} || '';
    if($nodeid !~ m/^node\d+$/mx and $nodeid ne 'new') { $nodeid = ''; }

    # check roles
    my $allowed_for_edit = 0;
    if($c->check_user_roles("admin")) {
        $allowed_for_edit = 1;
    }
    $c->stash->{allowed_for_edit} = $allowed_for_edit;
    $c->stash->{allowed_for_edit} = 0 if $c->req->parameters->{'readonly'};
    $c->stash->{no_menu}          = $c->req->parameters->{'no_menu'} ? 1 : 0;

    $c->stash->{fav_custom_fun} = $c->config->{'Thruk::Plugin::BP'}->{'favorite_custom_function'} ? [split(/\s*;\s*/mx, $c->config->{'Thruk::Plugin::BP'}->{'favorite_custom_function'})] : [];

    # json actions
    if($allowed_for_edit) {
        if($action eq 'templates') {
            my $host_templates    = [];
            my $service_templates = [];
            # simple / fast template grep
            if($c->stash->{'objects_templates_file'} and -e $c->stash->{'objects_templates_file'}) {
                my $lasttype;
                open(my $fh, '<', $c->stash->{'objects_templates_file'}) or die("failed to open ".$c->stash->{'objects_templates_file'}.": ".$!);
                while(my $line = <$fh>) {
                    if($line =~ m/^\s*template\s+(Service|Host)\s+"([^"]+)"\s*\{/mx) {
                        $lasttype = lc($1);
                        if($lasttype eq 'host') {
                            push @{$host_templates}, $2;
                        }
                        if($lasttype eq 'service') {
                            push @{$service_templates}, $2;
                        }
                        next;
                    }
                    if($line =~ m/^\s*define\s+(.*?)(\s|{)/mx) {
                        $lasttype = $1;
                    }
                    if($line =~ m/^\s*name\s+(.*?)\s*(;|$)+$/mx) {
                        if($lasttype eq 'host') {
                            push @{$host_templates}, $1;
                        }
                        if($lasttype eq 'service') {
                            push @{$service_templates}, $1;
                        }
                    }
                }
            }
            my $json = [ { 'name' => "host templates", 'data' => $host_templates }, { 'name' => "service templates", 'data' => $service_templates } ];
            return $c->render(json => $json);
        }
    }

    # read / write actions
    if($id and $allowed_for_edit and ($action ne 'details' and $action ne 'refresh')) {
        $c->stash->{editmode} = 1;
        my $bps = Thruk::BP::Utils::load_bp_data($c, $id, $c->stash->{editmode});
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process', code => 404 });
            return _bp_start_page($c);
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'} = $bp;

        if($action eq 'commit') {
            if($c->config->{'demo_mode'}) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'save is disabled in demo mode.' });
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi?action=details&bp=".$id);
            }
            return unless Thruk::Utils::check_csrf($c);
            $bp->commit($c);
            $bps = Thruk::BP::Utils::load_bp_data($c);
            my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
            if($rc != 0) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "reload command failed\n".$msg });
            }
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process updated sucessfully' }) unless $rc != 0;
            my $bps = Thruk::BP::Utils::load_bp_data($c, $id); # load new process, otherwise we would update in edit mode
            $bps->[0]->update_status($c);
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi?action=details&bp=".$id);
        }
        elsif($action eq 'revert') {
            return unless Thruk::Utils::check_csrf($c);
            unlink($bp->{'editfile'});
            unlink($bp->{'datafile'}.'.edit');
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'changes canceled' });
            if(-e $bp->{'file'}) {
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi?action=details&bp=".$id);
            } else {
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi");
            }
        }
        elsif($action eq 'remove') {
            return unless Thruk::Utils::check_csrf($c);
            $bp->remove($c);
            $bps = Thruk::BP::Utils::load_bp_data($c);
            my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
            if($rc != 0) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "reload command failed\n".$msg });
            }
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully removed' }) unless $rc != 0;
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi");
        }
        elsif($action eq 'clone') {
            my($new_file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
            my $label = Thruk::BP::Utils::make_uniq_label($c, 'Clone of '.$bp->{'name'});
            $bp->set_label($c, $label);
            $bp->get_node('node1')->{'label'} = $label;
            $bp->set_file($c, $new_file);
            $bp->save($c);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully cloned' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi?action=details&edit=1&bp=".$newid);
        }
        elsif($action eq 'rename_node' and $nodeid) {
            if(!$bp->{'nodes_by_id'}->{$nodeid}) {
                my $json = { rc => 1, 'message' => 'ERROR: no such node' };
                return $c->render(json => $json);
            }
            my $label = Thruk::BP::Utils::clean_nasty($c->req->parameters->{'label'} || 'none');
            # first node renames business process itself too
            if($nodeid eq 'node1' and $bp->get_node('node1')->{'label'} ne $label) {
                $label = Thruk::BP::Utils::make_uniq_label($c, $label, $bp->{'id'});
                $bp->set_label($c, $label);
            }
            $bp->{'nodes_by_id'}->{$nodeid}->{'label'} = $label;
            $bp->save($c);
            my $json = { rc => 0, 'message' => 'OK' };
            return $c->render(json => $json);
        }
        elsif($action eq 'remove_node' and $nodeid) {
            if(!$bp->{'nodes_by_id'}->{$nodeid}) {
                my $json = { rc => 1, 'message' => 'ERROR: no such node' };
                return $c->render(json => $json);
            }
            $bp->remove_node($nodeid);
            $bp->save($c);
            $bp->update_status($c, 1);
            my $json = { rc => 0, 'message' => 'OK' };
            return $c->render(json => $json);
        }
        elsif($action eq 'edit_node' and $nodeid) {
            my $type = lc($c->req->parameters->{'bp_function'} || '');
            my $node = $bp->get_node($nodeid); # node from the 'node' parameter
            if(!$node) {
                my $json = { rc => 1, 'message' => 'ERROR: no such node' };
                return $c->render(json => $json);
            }

            my @arg;
            for my $x (1..10) {
                $arg[$x-1] = $c->req->parameters->{'bp_arg'.$x.'_'.$type} if defined $c->req->parameters->{'bp_arg'.$x.'_'.$type};
            }
            my $function = sprintf("%s(%s)", $type, Thruk::BP::Utils::join_args(\@arg));

            # check create first
            my $new = 0;
            if($c->req->parameters->{'bp_node_id'} eq 'new') {
                $new = 1;
                my $parent = $node;
                $node = Thruk::BP::Components::Node->new({
                                    'label'    => Thruk::BP::Utils::clean_nasty($c->req->parameters->{'bp_label_'.$type}),
                                    'function' => $function,
                                    'depends'  => [],
                });
                die('could not create node: '.Data::Dumper($c->req->parameters)) unless $node;
                die('got no parent'.Data::Dumper($c->req->parameters)) unless $parent;
                $bp->add_node($node);
                $parent->append_child($node);
            }

            # update children
            $node->{'depends'} = Thruk::Utils::list($c->req->parameters->{'bp_'.$id.'_selected_nodes'} || []);

            # save object creating attributes
            for my $key (qw/host service template notification_period event_handler max_check_attempts/) {
                $node->{$key} = $c->req->parameters->{'bp_'.$key} || '';
            }
            # node array options
            for my $key (qw/contactgroups contacts/) {
                $node->{$key} = [split(/\s*,\s*/mx, $c->req->parameters->{'bp_'.$key} || '')];
            }
            $node->{'create_obj'} = $c->req->parameters->{'bp_create_link'} || 0;

            # save node filter
            $node->{'filter'} = [];
            $bp->{'filter'}   = [];
            for my $f (grep(/^bp_filter_/mx, keys %{$c->req->parameters})) {
                my $val = $c->req->parameters->{$f};
                $f =~ s/^bp_filter_//gmx;
                if($val eq 'on') {
                    push @{$node->{'filter'}}, $f;
                }
                if($val eq 'global') {
                    push @{$bp->{'filter'}}, $f;
                }
            }

            my $label = Thruk::BP::Utils::clean_nasty($c->req->parameters->{'bp_label_'.$type} || 'none');
            # first node renames business process itself too
            if(!$new && $nodeid eq 'node1') {
                if($bp->get_node('node1')->{'label'} ne $label) {
                    $label = Thruk::BP::Utils::make_uniq_label($c, $label, $bp->{'id'});
                    $bp->set_label($c, $label);
                }
                $bp->{'template'} = $c->req->parameters->{'bp_host_template'} || '';
            }
            $node->{'label'} = $label;

            $node->_set_function({'function' => $function});

            # bp options
            for my $key (qw/rankDir state_type/) {
                $bp->{$key} = $c->req->parameters->{'bp_'.$key} || '';
            }

            $bp->save($c);
            $bp->update_status($c, 1);
            my $json = { rc => 0, 'message' => 'OK' };
            return $c->render(json => $json);
        }
    }

    # new business process
    if($action eq 'new') {
        Thruk::BP::Utils::clean_orphaned_edit_files($c, 86400);
        my($file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
        my $label = Thruk::BP::Utils::clean_nasty($c->req->parameters->{'bp_label'} || 'New Business Process');
        $label = Thruk::BP::Utils::make_uniq_label($c, $label);
        my $bp = Thruk::BP::Components::BP->new($c, $file, {
            'name'  => $label,
            'nodes' => [{
                'id'       => 'node1',
                'label'    => $label,
                'function' => 'Worst()',
                'depends'  => ['node2'],
            }, {
                'id'       => 'node2',
                'label'    => 'Example Node',
                'function' => 'Fixed("OK")',
            }],
        });
        $bp->set_label($c, $label);
        $bp->save();
        die("internal error") unless $bp;
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully created' });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi?action=details&edit=1&bp=".$newid);
    }

    # readonly actions
    if($id) {
        $c->stash->{editmode} = $c->req->parameters->{'edit'} || 0;
        $c->stash->{editmode} = 0 unless $allowed_for_edit;
        my $bps = Thruk::BP::Utils::load_bp_data($c, $id, $c->stash->{editmode});
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process', code => 404 });
            return _bp_start_page($c);
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'} = $bp;

        if($c->req->parameters->{'update'}) {
            $bp->update_status($c);
        }
        # try to find this bp on any system
        my $hosts = $c->{'db'}->get_hosts( filter => [ { 'name' => $bp->{'name'} } ] );
        $c->stash->{'bp_backend'} = '';
        if(scalar @{$hosts} > 0) {
            $c->stash->{'bp_backend'} = $hosts->[0]->{'peer_key'};
        }

        $c->stash->{'bp_custom_functions'} = Thruk::BP::Utils::get_custom_functions($c);
        $c->stash->{'bp_custom_filter'}    = Thruk::BP::Utils::get_custom_filter($c);

        if($action eq 'details') {
            if($c->req->parameters->{'view_mode'} and $c->req->parameters->{'view_mode'} eq 'json') {
                my $json = { $bp->{'id'} => $bp->TO_JSON() };
                return $c->render(json => $json);
            }
            $c->stash->{'auto_reload_fn'} = 'bp_refresh_bg';
            $c->stash->{'template'}       = 'bp_details.tt';
            return 1;
        }
        elsif($action eq 'refresh') {
            # test mode?
            if($c->stash->{testmode}) {
                $bp->{'testmode'} = 1;
                my $testmodes = {};
                for my $n (@{$bp->{'nodes'}}) {
                    my $state = $c->req->parameters->{$n->{'id'}};
                    if(defined $state) {
                        $testmodes->{$n->{'id'}} = $state;
                        $n->set_status($state, 'testmode', $bp, { testmode => 1 });
                    }
                }
                $c->stash->{testmodes} = $testmodes;
                $bp->update_status($c, 1); # only recalculate
            }
            $c->stash->{template} = '_bp_graph.tt';
            return 1;
        }
        if($action eq 'list_objects') {
            my $params = {};
            my $hst = 0;
            my $svc = 0;
            my $bp_lookup = {};
            ($params, $hst, $svc) = _bp_list_add_objects($c, $bp, $params, $hst, $svc, $bp_lookup);
            if($hst == 0 && $svc == 0) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'this business process has no references' });
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/bp.cgi?action=details&bp=".$id);
            }
            $params->{'title'} = $bp->{'name'};
            $params->{'style'} = 'combined';
            if($hst == 0) {
                # only service filter -> show service list only
                $params->{'style'} = 'detail';
                for my $key (keys %{$params}) {
                    my $newkey = $key;
                    $newkey =~ s/^svc_/dfl_/gmx;
                    $params->{$newkey} = delete $params->{$key};
                }
            }

            for my $key (keys %{$c->req->parameters}) {
                if($key !~ m/^(hoststatustypes|servicestatustypes)/mx) {
                    delete $c->req->parameters->{$key};
                }
            }
            for my $key (keys %{$params}) {
                $c->req->parameters->{$key} = $params->{$key};
            }
            require Thruk::Controller::status;
            return(Thruk::Controller::status::index($c));
        }
    }

    _bp_start_page($c);

    return 1;
}

##########################################################
sub _bp_start_page {
    my($c) = @_;

    $c->stash->{template}  = 'bp.tt';
    $c->stash->{editmode}  = 0;

    # load business processes
    my $drafts_too = $c->stash->{allowed_for_edit} ? 1 : 0;
    if($c->req->parameters->{'no_drafts'}) {
        $drafts_too = 0;
    }
    my $bps = Thruk::BP::Utils::load_bp_data($c, undef, undef, $drafts_too);
    $c->stash->{'bps'} = $bps;

    if($c->req->parameters->{'view_mode'} and $c->req->parameters->{'view_mode'} eq 'json') {
        my $json;
        if($c->req->parameters->{'format'} and $c->req->parameters->{'format'} eq 'search') {
            my $data = [];
            for my $bp (@{$bps}) {
                push @{$data}, $bp->{'name'};
            }
            $json = [ { 'name' => "business processs", 'data' => $data } ];
        } else {
            my $data = {};
            for my $bp (@{$bps}) {
                $data->{$bp->{'id'}} = $bp->TO_JSON();
            }
            $json = $data;
        }
        return $c->render(json => $json);
    }


    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################
sub _bp_list_add_objects {
    my($c, $bp, $params, $hst, $svc, $bp_lookup) = @_;
    $bp_lookup->{$bp->{'id'}} = 1;
    for my $n (@{$bp->{'nodes'}}) {
        if(lc $n->{'function'} eq 'status') {
            if($n->{'host'} and $n->{'service'}) {
                my $service = $n->{'service'};
                my $svc_op  = '=';
                if(Thruk::BP::Utils::looks_like_regex($service)) {
                    $service =~ s/^(b|w)://gmx;
                    $service = Thruk::Utils::convert_wildcards_to_regex($service);
                    $svc_op  = '~';
                }
                if($n->{'function_args'} && ref $n->{'function_args'} eq 'ARRAY' && $n->{'function_args'}->[2]) {
                    $svc_op  = $n->{'function_args'}->[2];
                }
                $params->{'svc_s'.$svc.'_type'}   = ['host', 'service'];
                $params->{'svc_s'.$svc.'_op'}     = ['=', $svc_op];
                $params->{'svc_s'.$svc.'_value'}  = [$n->{'host'}, $service];
                $svc++;
            }
            elsif($n->{'host'}) {
                $params->{'hst_s'.$hst.'_type'}   = 'host';
                $params->{'hst_s'.$hst.'_op'}     = '=';
                $params->{'hst_s'.$hst.'_value'}  = $n->{'host'};
                $hst++;
            }
        }
        elsif(lc $n->{'function'} eq 'groupstatus') {
            if($n->{'hostgroup'}) {
                $params->{'hst_s'.$hst.'_type'}   = 'hostgroup';
                $params->{'hst_s'.$hst.'_op'}     = '=';
                $params->{'hst_s'.$hst.'_value'}  = $n->{'hostgroup'};
                $hst++;

                $params->{'svc_s'.$svc.'_type'}   = 'hostgroup';
                $params->{'svc_s'.$svc.'_op'}     = '=';
                $params->{'svc_s'.$svc.'_value'}  = $n->{'hostgroup'};
                $svc++;
            }
            elsif($n->{'servicegroup'}) {
                $params->{'svc_s'.$svc.'_type'}   = 'servicegroup';
                $params->{'svc_s'.$svc.'_op'}     = '=';
                $params->{'svc_s'.$svc.'_value'}  = $n->{'servicegroup'};
                $svc++;
            }
        }
    }

    # check recursive for other linked business processes
    my $recursive_bps = {};
    my $livedata = $bp->bulk_fetch_live_data($c, 1);
    if($livedata->{'hosts'}) {
        for my $host (values %{$livedata->{'hosts'}}) {
            my $vars = Thruk::Utils::get_custom_vars($c, $host);
            if($vars->{'THRUK_BP_ID'} && !defined $bp_lookup->{$vars->{'THRUK_BP_ID'}}) {
                $recursive_bps->{$vars->{'THRUK_BP_ID'}} = 1;
            }
        }
    }
    if($livedata->{'services'}) {
        for my $name (keys %{$livedata->{'services'}}) {
            for my $service (values %{$livedata->{'services'}->{$name}}) {
                my $vars = Thruk::Utils::get_custom_vars($c, $service);
                if($vars->{'THRUK_BP_ID'} && !defined $bp_lookup->{$vars->{'THRUK_BP_ID'}}) {
                    $recursive_bps->{$vars->{'THRUK_BP_ID'}} = 1;
                }
            }
        }
    }
    for my $bp_id (sort keys %{$recursive_bps}) {
        my $link_bp = Thruk::BP::Utils::load_bp_data($c, $bp_id);
        $bp_lookup->{$bp_id} = 1;
        if(scalar @{$link_bp} == 1) {
            ($params, $hst, $svc) = _bp_list_add_objects($c, $link_bp->[0], $params, $hst, $svc, $bp_lookup);
        }
    }


    return($params, $hst, $svc);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
