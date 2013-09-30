package Thruk::Controller::bp;
use parent 'Catalyst::Controller';

use strict;
use warnings;
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
    $c->stash->{page}                  = 'bp';
    $c->stash->{template}              = 'bp.tt';
    $c->stash->{subtitle}              = 'Business Process';
    $c->stash->{infoBoxTitle}          = 'Business Process';
    $c->stash->{'has_jquery_ui'}       = 1;
    $c->stash->{editmode}              = 0;
    my $id = $c->{'request'}->{'parameters'}->{'bp'} || '';
    if($id !~ m/^\d+$/mx and $id ne 'new') { $id = ''; }
    my $nodeid = $c->{'request'}->{'parameters'}->{'node'} || '';
    if($nodeid !~ m/^node\d+$/mx and $nodeid ne 'new') { $nodeid = ''; }

    my $allowed_for_edit = 1;

    my $action = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    if($id) {
        $c->stash->{editmode} = $c->{'request'}->{'parameters'}->{'edit'} || 0;
        $c->stash->{editmode} = 0 unless $allowed_for_edit;

        my $bps = Thruk::BP::Utils::load_bp_data($c, $id, $c->stash->{editmode});
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi");
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'}     = $bp;

        if($action eq 'details') {
            $c->stash->{'auto_reload_fn'} = 'bp_refresh_bg';
            $c->stash->{template} = 'bp_details.tt';
            return 1;
        }
        elsif($action eq 'refresh' and $id) {
            $bp->update_status($c);
            $c->stash->{template} = '_bp_graph.tt';
            return 1;
        }
    }

    if($id and $allowed_for_edit) {
        $c->stash->{editmode} = 1;
        my $bps = Thruk::BP::Utils::load_bp_data($c, $id, $c->stash->{editmode});
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi");
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'}     = $bp;

        if($action eq 'commit') {
            $bp->commit($c);
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process updated sucessfully' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&bp=".$id);
        }
        elsif($action eq 'revert') {
            unlink($bp->{'editfile'});
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'changes canceled' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&bp=".$id);
        }
        elsif($action eq 'remove') {
            $bp->remove($c);
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully removed' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi");
        }
        elsif($action eq 'clone') {
            my($new_file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
            $bp->set_file($new_file);
            $bp->{'name'} = 'Clone of '.$bp->{'name'};
            $bp->get_node('node1')->{'label'} = $bp->{'name'};
            $bp->save($c);
            $bp->commit($c);
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully cloned' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&edit=1&bp=".$newid);
        }
        elsif($action eq 'rename_node' and $nodeid) {
            if(!$bp->{'nodes_by_id'}->{$nodeid}) {
                $c->stash->{'text'} = 'ERROR: no such node';
                $c->stash->{template} = 'passthrough.tt';
                return 1;
            }
            $bp->{'nodes_by_id'}->{$nodeid}->{'label'} = $c->{'request'}->{'parameters'}->{'label'};
            # first node renames business process itself too
            if($nodeid eq 'node1') {
                $bp->{'name'} = $c->{'request'}->{'parameters'}->{'label'};
            }
            $bp->save($c);
            $c->stash->{'text'} = 'OK';
            $c->stash->{template} = 'passthrough.tt';
            return 1;
        }
        elsif($action eq 'remove_node' and $nodeid) {
            if(!$bp->{'nodes_by_id'}->{$nodeid}) {
                $c->stash->{'text'} = 'ERROR: no such node';
                $c->stash->{template} = 'passthrough.tt';
                return 1;
            }
            $bp->remove_node($nodeid);
            $bp->save($c);
            $c->stash->{'text'} = 'OK';
            $c->stash->{template} = 'passthrough.tt';
            return 1;
        }
        elsif($action eq 'edit_node' and $nodeid) {
            my $sub = $c->{'request'}->{'parameters'}->{'sub'} || '';
            if($sub eq 'connections') {
                my $node = $bp->get_node($nodeid);
                my $depends = Thruk::Utils::list($c->{'request'}->{'parameters'}->{'bp_'.$id.'_selected_nodes'} || []);
                $node->resolve_depends($bp, $depends);
                $bp->save($c);
                $c->stash->{'text'} = 'OK';
                $c->stash->{template} = 'passthrough.tt';
                return 1;
            }
            my $parent = $bp->get_node($nodeid);
            my @arg;
            for my $x (1..10) {
                push @arg, $c->{'request'}->{'parameters'}->{'bp_arg'.$x} if defined $c->{'request'}->{'parameters'}->{'bp_arg'.$x};
            }
            my $function = sprintf("%s(%s)", $c->{'request'}->{'parameters'}->{'function'}, Thruk::BP::Utils::join_args(\@arg));
            my $node;
            if($c->{'request'}->{'parameters'}->{'bp_node_id'} eq 'new') {
                $node = Thruk::BP::Components::Node->new({
                                    'label'    => $c->{'request'}->{'parameters'}->{'bp_label'},
                                    'function' => $function,
                                    'depends'  => [],
                });
                $bp->add_node($node);
                $parent->append_child($node);
            } else {
                $node = $parent;
                $node->{'label'} = $c->{'request'}->{'parameters'}->{'bp_label'};
                $node->_set_function({'function' => $function});
            }
            $bp->save($c);
            $c->stash->{'text'} = 'OK';
            $c->stash->{template} = 'passthrough.tt';
            return 1;
        }
    }

    # new business process
    if($action eq 'new') {
        my($file, $newid) = Thruk::BP::Utils::next_free_bp_file($c);
        my $label = $c->{'request'}->{'parameters'}->{'bp_label'} || 'New Business Process';
        my $bp = Thruk::BP::Components::BP->new($file, {
            'name'  => $label,
            'node'  => [{
                'label'    => $label,
                'function' => 'Worst()',
                'depends'  => ['Example Node'],
            }, {
                'label'    => 'Example Node',
                'function' => 'Fixed("OK")',
            }]
        });
        Thruk::BP::Utils::update_cron_file($c); # check cronjob
        Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'business process sucessfully created' });
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi?action=details&bp=".$newid);
    }

    # load business processes
    my $bps = Thruk::BP::Utils::load_bp_data($c);
    $c->stash->{'bps'} = $bps;

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
