package Thruk::Controller::bp;
use parent 'Catalyst::Controller';

use strict;
use warnings;
use Data::Dumper;
use Thruk 1.76;
use Thruk::BP::Utils;

use Carp;
use Config::General;

=head1 NAME

Thruk::Controller::bp - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

######################################
# add new menu item, but only if user has all of the
# requested roles
Thruk::Utils::Menu::insert_item('Reports', {
                                    'href'  => '/thruk/cgi-bin/bp.cgi',
                                    'name'  => 'Business Process',
                         });

# enable business process features if this plugin is loaded
Thruk->config->{'use_feature_bp'} = 1;

######################################

=head2 bp_cgi

page: /thruk/cgi-bin/bp.cgi

=cut
sub bp_cgi : Path('/thruk/cgi-bin/bp.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/bp/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{title}                 = 'Business Process';
    $c->stash->{page}                  = 'status';
    $c->stash->{template}              = 'bp.tt';
    $c->stash->{subtitle}              = 'Business Process';
    $c->stash->{infoBoxTitle}          = 'Business Process';
    $c->stash->{'has_jquery_ui'}       = 1;
    $c->stash->{editmode}              = 0;
    $c->stash->{testmode}              = $c->{'request'}->{'parameters'}->{'testmode'} || 0;
    $c->stash->{debug}                 = $c->{'request'}->{'parameters'}->{'debug'} || 0;
    $c->stash->{testmodes}             = {};
    $c->stash->{'objects_templates_file'} = $c->config->{'Thruk::Plugin::BP'}->{'objects_templates_file'} || '';
    $c->stash->{'objects_save_file'}      = $c->config->{'Thruk::Plugin::BP'}->{'objects_save_file'}      || '';
    my $id = $c->{'request'}->{'parameters'}->{'bp'} || '';
    if($id !~ m/^\d+$/mx and $id ne 'new') { $id = ''; }
    my $nodeid = $c->{'request'}->{'parameters'}->{'node'} || '';
    if($nodeid !~ m/^node\d+$/mx and $nodeid ne 'new') { $nodeid = ''; }

    # check roles
    my $allowed_for_edit = 0;
    if( $c->check_user_roles( "authorized_for_configuration_information")
        and $c->check_user_roles( "authorized_for_system_commands")) {
        $allowed_for_edit = 1;
    }
    $c->stash->{allowed_for_edit} = $allowed_for_edit;
    $c->stash->{allowed_for_edit} = 0 if $c->{'request'}->{'parameters'}->{'readonly'};
    $c->stash->{no_menu}          = $c->{'request'}->{'parameters'}->{'no_menu'} ? 1 : 0;

    my $action = $c->{'request'}->{'parameters'}->{'action'} || 'show';

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
            $c->stash->{'json'} = $json;
            return $c->forward('Thruk::View::JSON');
        }
    }

    # read / write actions
    if($id and $allowed_for_edit) {
        $c->stash->{editmode} = 1;
        my $bps = Thruk::BP::Utils::load_bp_data($c, $id, $c->stash->{editmode});
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process', code => 404 });
            return $self->_bp_start_page($c);
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'} = $bp;

        if($action eq 'commit') {
            if($c->config->{'demo_mode'}) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'save is disabled in demo mode.' });
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&bp=".$id);
            }
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
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&bp=".$id);
        }
        elsif($action eq 'revert') {
            unlink($bp->{'editfile'});
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'changes canceled' });
            if(-e $bp->{'file'}) {
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&bp=".$id);
            } else {
                return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi");
            }
        }
        elsif($action eq 'remove') {
            $bp->remove($c);
            $bps = Thruk::BP::Utils::load_bp_data($c);
            my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
            if($rc != 0) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => "reload command failed\n".$msg });
            }
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully removed' }) unless $rc != 0;
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi");
        }
        elsif($action eq 'clone') {
            my($new_file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
            my $label = Thruk::BP::Utils::make_uniq_label($c, 'Clone of '.$bp->{'name'});
            $bp->set_label($c, $label);
            $bp->get_node('node1')->{'label'} = $label;
            $bp->set_file($c, $new_file);
            $bp->save($c);
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully cloned' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&edit=1&bp=".$newid);
        }
        elsif($action eq 'rename_node' and $nodeid) {
            if(!$bp->{'nodes_by_id'}->{$nodeid}) {
                $c->stash->{'json'} = { rc => 1, 'message' => 'ERROR: no such node' };
                return $c->forward('Thruk::View::JSON');
            }
            my $label = Thruk::BP::Utils::clean_nasty($c->{'request'}->{'parameters'}->{'label'} || 'none');
            # first node renames business process itself too
            if($nodeid eq 'node1' and $bp->get_node('node1')->{'label'} ne $label) {
                $label = Thruk::BP::Utils::make_uniq_label($c, $label, $bp->{'id'});
                $bp->set_label($c, $label);
            }
            $bp->{'nodes_by_id'}->{$nodeid}->{'label'} = $label;
            $bp->save($c);
            $c->stash->{'json'} = { rc => 0, 'message' => 'OK' };
            return $c->forward('Thruk::View::JSON');
        }
        elsif($action eq 'remove_node' and $nodeid) {
            if(!$bp->{'nodes_by_id'}->{$nodeid}) {
                $c->stash->{'json'} = { rc => 1, 'message' => 'ERROR: no such node' };
                return $c->forward('Thruk::View::JSON');
            }
            $bp->remove_node($nodeid);
            $bp->save($c);
            $bp->update_status($c, 1);
            $c->stash->{'json'} = { rc => 0, 'message' => 'OK' };
            return $c->forward('Thruk::View::JSON');
        }
        elsif($action eq 'edit_node' and $nodeid) {
            my $type = lc($c->{'request'}->{'parameters'}->{'bp_function'} || '');
            my $node = $bp->get_node($nodeid); # node from the 'node' parameter
            if(!$node) {
                $c->stash->{'json'} = { rc => 1, 'message' => 'ERROR: no such node' };
                return $c->forward('Thruk::View::JSON');
            }

            my @arg;
            for my $x (1..10) {
                push @arg, $c->{'request'}->{'parameters'}->{'bp_arg'.$x.'_'.$type} if defined $c->{'request'}->{'parameters'}->{'bp_arg'.$x.'_'.$type};
            }
            my $function = sprintf("%s(%s)", $type, Thruk::BP::Utils::join_args(\@arg));

            # check create first
            my $new = 0;
            if($c->{'request'}->{'parameters'}->{'bp_node_id'} eq 'new') {
                $new = 1;
                my $parent = $node;
                $node = Thruk::BP::Components::Node->new({
                                    'label'    => Thruk::BP::Utils::clean_nasty($c->{'request'}->{'parameters'}->{'bp_label_'.$type}),
                                    'function' => $function,
                                    'depends'  => [],
                });
                die('could not create node: '.Dumper($c->{'request'}->{'parameters'})) unless $node;
                die('got no parent'.Dumper($c->{'request'}->{'parameters'})) unless $parent;
                $bp->add_node($node);
                $parent->append_child($node);
            }

            # update children
            my $depends = Thruk::Utils::list($c->{'request'}->{'parameters'}->{'bp_'.$id.'_selected_nodes'} || []);
            $node->resolve_depends($bp, $depends);

            # save object creating attributes
            for my $key (qw/host service template/) {
                $node->{$key} = $c->{'request'}->{'parameters'}->{'bp_'.$key} || '';
            }
            $node->{'create_obj'} = $c->{'request'}->{'parameters'}->{'bp_create_link'} || 0;


            my $label = Thruk::BP::Utils::clean_nasty($c->{'request'}->{'parameters'}->{'bp_label_'.$type} || 'none');
            # first node renames business process itself too
            if(!$new and $nodeid eq 'node1') {
                if($bp->get_node('node1')->{'label'} ne $label) {
                    $label = Thruk::BP::Utils::make_uniq_label($c, $label, $bp->{'id'});
                    $bp->set_label($c, $label);
                }
                $bp->{'template'} = $c->{'request'}->{'parameters'}->{'bp_host_template'} || '';
            }
            $node->{'label'} = $label;

            $node->_set_function({'function' => $function});

            # bp options
            for my $key (qw/rankDir state_type/) {
                $bp->{$key} = $c->{'request'}->{'parameters'}->{'bp_'.$key} || '';
            }

            $bp->save($c);
            $bp->update_status($c, 1);
            $c->stash->{'json'} = { rc => 0, 'message' => 'OK' };
            return $c->forward('Thruk::View::JSON');
        }
    }

    # new business process
    if($action eq 'new') {
        Thruk::BP::Utils::clean_orphaned_edit_files($c, 86400);
        my($file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
        my $label = Thruk::BP::Utils::clean_nasty($c->{'request'}->{'parameters'}->{'bp_label'} || 'New Business Process');
        $label = Thruk::BP::Utils::make_uniq_label($c, $label);
        my $bp = Thruk::BP::Components::BP->new($c, $file, {
            'name'  => $label,
            'nodes' => [{
                'label'    => $label,
                'function' => 'Worst()',
                'depends'  => ['Example Node'],
            }, {
                'label'    => 'Example Node',
                'function' => 'Fixed("OK")',
            }]
        });
        $bp->set_label($c, $label);
        die("internal error") unless $bp;
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully created' });
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&edit=1&bp=".$newid);
    }

    # readonly actions
    if($id) {
        $c->stash->{editmode} = $c->{'request'}->{'parameters'}->{'edit'} || 0;
        $c->stash->{editmode} = 0 unless $allowed_for_edit;
        my $bps = Thruk::BP::Utils::load_bp_data($c, $id, $c->stash->{editmode});
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process', code => 404 });
            return $self->_bp_start_page($c);
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'} = $bp;

        if(!defined $c->{'request'}->{'parameters'}->{'update'} or $c->{'request'}->{'parameters'}->{'update'}) {
            $bp->update_status($c);
        }
        # try to find this bp on any system
        my $hosts = $c->{'db'}->get_hosts( filter => [ { 'name' => $bp->{'name'} } ] );
        $c->stash->{'bp_backend'} = '';
        if(scalar @{$hosts} > 0) {
            $c->stash->{'bp_backend'} = $hosts->[0]->{'peer_key'};
        }

        if($action eq 'details') {
            if($c->{'request'}->{'parameters'}->{'view_mode'} and $c->{'request'}->{'parameters'}->{'view_mode'} eq 'json') {
                $c->stash->{'json'} = { $bp->{'id'} => $bp->TO_JSON() };
                return $c->forward('Thruk::View::JSON');
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
                    my $state = $c->{'request'}->{'parameters'}->{$n->{'id'}};
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
    }

    $self->_bp_start_page($c);

    return 1;
}

##########################################################
sub _bp_start_page {
    my($self, $c) = @_;

    $c->stash->{template} = 'bp.tt';
    $c->stash->{editmode} = 0;

    # load business processes
    my $bps = Thruk::BP::Utils::load_bp_data($c);
    $c->stash->{'bps'} = $bps;

    if($c->{'request'}->{'parameters'}->{'view_mode'} and $c->{'request'}->{'parameters'}->{'view_mode'} eq 'json') {
        if($c->{'request'}->{'parameters'}->{'format'} and $c->{'request'}->{'parameters'}->{'format'} eq 'search') {
            my $data = [];
            for my $bp (@{$bps}) {
                push @{$data}, $bp->{'name'};
            }
            $c->stash->{'json'} = [ { 'name' => "business processs", 'data' => $data } ];
        } else {
            my $data = {};
            for my $bp (@{$bps}) {
                $data->{$bp->{'id'}} = $bp->TO_JSON();
            }
            $c->stash->{'json'} = $data;
        }
        return $c->forward('Thruk::View::JSON');
    }


    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
