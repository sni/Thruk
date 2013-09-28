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
    my $id = $c->{'request'}->{'parameters'}->{'bp'} || '';
    if($id !~ m/^\d+$/mx) { $id = ''; }
    my $nodeid = $c->{'request'}->{'parameters'}->{'node'} || '';
    if($nodeid !~ m/^node\d+$/mx) { $nodeid = ''; }

    my $action = $c->{'request'}->{'parameters'}->{'action'} || 'show';
    if($id) {
        my $bps = Thruk::BP::Utils::load_bp_data($c, $id);
        if(scalar @{$bps} != 1) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such business process' });
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/bp.cgi");
        }
        my $bp = $bps->[0];
        $c->stash->{'bp'} = $bp;

        if($action eq 'details') {
            $c->stash->{'no_auto_reload'} = 1;
            $c->stash->{template} = 'bp_details.tt';
            return 1;
        }
        elsif($action eq 'refresh' and $id) {
            $bp->update_status($c);
            $c->stash->{template} = '_bp_graph.tt';
            return 1;
        }
        elsif($action eq 'rename_node' and $id && $nodeid) {
            $bp->{'nodes_by_id'}->{$nodeid}->{'label'} = $c->{'request'}->{'parameters'}->{'label'};
            $bp->save();
            $c->stash->{'text'} = 'OK';
            $c->stash->{template} = 'passthrough.tt';
            return 1;
        }
        elsif($action eq 'remove_node' and $id && $nodeid) {
            $bp->remove_node($nodeid);
            $bp->save();
            $bp->save_runtime();
            $c->stash->{'text'} = 'OK';
            $c->stash->{template} = 'passthrough.tt';
            return 1;
        }
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
