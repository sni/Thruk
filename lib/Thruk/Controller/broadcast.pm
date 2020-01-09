package Thruk::Controller::broadcast;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::broadcast - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(defined $c->req->parameters->{'action'}) {
        my $action = $c->req->parameters->{'action'};
        if($action eq 'dismiss') {
            Thruk::Utils::Broadcast::update_dismiss($c, $c->req->parameters->{'panorama'});
            return $c->render(json => {'status' => 'ok'});
        }
    }

    # user allowed to manage broadcasts?
    if(!$c->check_user_roles('authorized_for_broadcasts')) {
        return $c->detach('/error/index/8');
    }

    $c->stash->{'page'}            = 'extinfo';
    $c->stash->{has_jquery_ui}     = 1;
    $c->stash->{disable_backspace} = 1;
    $c->stash->{'no_auto_reload'}  = 1;
    $c->stash->{'title'}           = 'Broadcasts';
    $c->stash->{'infoBoxTitle'}    = 'Broadcasts';
    $c->stash->{no_tt_trim}        = 1;

    Thruk::Utils::ssi_include($c, 'broadcast');

    if(defined $c->req->parameters->{'action'}) {
        my $action = $c->req->parameters->{'action'};
        if($action eq 'edit' || $action eq 'clone') {
            my $id = $c->req->parameters->{'id'} // '';
            my $broadcast;
            if($id eq 'new') {
                $broadcast = Thruk::Utils::Broadcast::get_default_broadcast($c);
            } else {
                my $broadcasts = Thruk::Utils::Broadcast::get_broadcasts($c, 1, $id);
                if($broadcasts->[0]) {
                    $broadcast = $broadcasts->[0];
                } else {
                    $broadcast = Thruk::Utils::Broadcast::get_default_broadcast($c);
                }
            }
            if($action eq 'clone') {
                $broadcast->{'author'}      = $c->stash->{'remote_user'};
                $broadcast->{'authoremail'} = $c->user ? $c->user->{'email'} : 'none';
                $broadcast->{'template'} = 0;
                delete $broadcast->{'basefile'};
            }
            $broadcast->{'id'} = $broadcast->{'basefile'} || 'new';
            $c->stash->{template}  = 'broadcast_edit.tt';
            $c->stash->{broadcast} = $broadcast;
            return 1;
        }
        if($action eq 'delete') {
            my $id = $c->req->parameters->{'id'};
            if($id =~ m/^[\.\/]+/mx) {
                Thruk::Utils::set_message( $c, 'fail_message', 'Broadcast cannot be removed with that name' );
            } else {
                unlink($c->config->{'var_path'}.'/broadcast/'.$id);
                Thruk::Utils::set_message( $c, 'success_message', 'Broadcast removed' );
            }
            return $c->redirect_to('broadcast.cgi');
        }
        if($action eq 'save') {
            # don't store in demo mode
            if($c->config->{'demo_mode'}) {
                Thruk::Utils::set_message( $c, 'fail_message', 'saving broadcasts is disabled in demo mode');
                return $c->redirect_to('broadcast.cgi');
            }

            my $broadcast = {};
            my $id = $c->req->parameters->{'id'};
            if($id eq 'new') {
                $id = POSIX::strftime('%Y-%m-%d-'.$c->stash->{'remote_user'}.'.json', localtime);
                my $x  = 1;
                while(-e $c->config->{'var_path'}.'/broadcast/'.$id) {
                    $id = POSIX::strftime('%Y-%m-%d-'.$c->stash->{'remote_user'}.'_'.$x.'.json', localtime);
                    $x++;
                }
            }
            if($id =~ m/^[\.\/]+/mx) {
                Thruk::Utils::set_message( $c, 'fail_message', 'Broadcast cannot be saved with that name' );
                return $c->redirect_to('broadcast.cgi');
            }
            $broadcast = Thruk::Utils::Broadcast::update_broadcast_from_param($c, $broadcast);

            Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/broadcast/');
            Thruk::Utils::IO::json_lock_store($c->config->{'var_path'}.'/broadcast/'.$id, $broadcast, { pretty => 1, changed_only => 1 });

            Thruk::Utils::set_message( $c, 'success_message', 'Broadcast saved' );
            return $c->redirect_to('broadcast.cgi');
        }
    }

    $c->stash->{template}       = 'broadcast.tt';
    $c->stash->{all_broadcasts} = Thruk::Utils::Broadcast::get_broadcasts($c, 1);

    return 1;
}

##########################################################

1;
