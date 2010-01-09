package Thruk::Controller::cmd;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Template;
use Time::HiRes qw( usleep );

=head1 NAME

Thruk::Controller::cmd - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{title}          = "External Command Interface";
    $c->stash->{infoBoxTitle}   = "External Command Interface";
    $c->stash->{no_auto_reload} = 1;
    $c->stash->{page}           = 'cmd';

    # check if authorization is enabled
    if($c->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->{'cgi_cfg'}->{'use_ssl_authentication'} == 0) {
        $c->detach('/error/index/3');
    }

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

    # command disabled by config?
    my $not_allowed = Thruk->config->{'command_disabled'};
    if(defined $not_allowed) {
        my %command_disabled;
        if(ref $not_allowed eq 'ARRAY') {
            for my $num (@{$not_allowed}) {
                $command_disabled{$num} = 1;
            }
        } else {
            $command_disabled{$not_allowed} = 1;
        }
        if(defined $command_disabled{$cmd_typ}) {
            $c->detach('/error/index/12');
        }
    }

    # read only user?
    $c->detach('/error/index/11') if $c->check_user_roles('is_authorized_for_read_only');

    my $cmd_mod = $c->{'request'}->{'parameters'}->{'cmd_mod'};

    # command commited?
    if(defined $cmd_mod and $self->_do_send_command($c)) {
        # success page is already displayed
    } else {
        # no command submited, view commands page
        if($cmd_typ == 55 or $cmd_typ == 56) {
            $c->stash->{'hostdowntimes'}    = $c->{'live'}->selectall_arrayref("GET downtimes\n".Thruk::Helper::get_auth_filter($c, 'downtimes')."\nFilter: service_description = \nColumns: id host_name start_time", { Slice => {} });
            $c->stash->{'servicedowntimes'} = $c->{'live'}->selectall_arrayref("GET downtimes\n".Thruk::Helper::get_auth_filter($c, 'downtimes')."\nFilter: service_description != \nColumns: id host_name start_time service_description", { Slice => {} });
        }

        my @possible_backends       = $c->{'live'}->peer_key();
        $c->stash->{'backends'}     = \@possible_backends;
        $c->stash->{'backend'}      = $c->{'request'}->{'parameters'}->{'backend'} || '';

        my $comment_author          = $c->user->username;
        $comment_author             = $c->user->alias if defined $c->user->alias;
        $c->stash->{comment_author} = $comment_author;
        $c->stash->{referer}        = $c->{'request'}->{'parameters'}->{'referer'} || $c->{'request'}->{'headers'}->{'referer'} || '';
        $c->stash->{cmd_tt}         = 'cmd.tt';
        $c->stash->{template}       = 'cmd/cmd_typ_'.$cmd_typ.'.tt';
    }
}


######################################
# sending commands
sub _do_send_command {
    my ( $self, $c ) = @_;

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

    # locked author names?
    if($c->{'cgi_cfg'}->{'lock_author_names'}) {
        my $author = $c->user->username;
        $author    = $c->user->alias if defined $c->user->alias;
        $c->{'request'}->{'parameters'}->{'com_author'} = $author;
    }

    my $tt  = Template->new($c->{'View::TT'});
    my $cmd = '';
    $tt->process( 'cmd/cmd_typ_'.$cmd_typ.'.tt', { c => $c, cmd_tt => 'cmd_line.tt' }, \$cmd ) || die $tt->error();
    $cmd =~ s/^\s+//gmx;
    $cmd =~ s/\s+$//gmx;

    # unknown command given?
    $c->detach('/error/index/7') unless defined $cmd;

    # unauthorized?
    $c->detach('/error/index/8') unless $cmd ne '';

    # check for required fields
    my($form,@errors);
    $tt->process( 'cmd/cmd_typ_'.$cmd_typ.'.tt', { c => $c, cmd_tt => '_get_content.tt' }, \$form ) || die $tt->error();
    if(my @matches = $form =~ m/class='(optBoxRequiredItem|optBoxItem)'>(.*?):<\/td>.*?input\s+type='.*?'\s+name='(.*?)'/gmx ) {
        while(scalar @matches > 0) {
            my $req  = shift @matches;
            my $name = shift @matches;
            my $key  = shift @matches;
            if($req eq 'optBoxRequiredItem' and ( !defined $c->{'request'}->{'parameters'}->{$key} or $c->{'request'}->{'parameters'}->{$key} =~ m/^\s*$/mx)) {
                push @errors, { message => $name.' is a required field' };
            }
        }
        if(scalar @errors > 0) {
            delete $c->{'request'}->{'parameters'}->{'cmd_mod'};
            $c->stash->{'form_errors'} = \@errors;
            return(0);
        }
    }

    # is a backend selected?
    my $backends          = $c->{'request'}->{'parameters'}->{'backend'};
    my @possible_backends = $c->{'live'}->peer_key();
    if(scalar @possible_backends > 1 and !defined $backends) {
            delete $c->{'request'}->{'parameters'}->{'cmd_mod'};
            push @errors, { message => 'please select a backend' };
            $c->stash->{'form_errors'} = \@errors;
            return(0);
    }

    # send the command
    $cmd = "COMMAND [".time()."] $cmd";
    $c->log->info("sending: $cmd");
    if(defined $backends) {
        $c->log->debug("sending to backends: ".Dumper($backends));
        $c->{'live'}->do($cmd, { Backends => $backends });
    } else {
        $c->{'live'}->do($cmd);
    }

    # view our success page or redirect to referer
    my $referer = $c->{'request'}->{'parameters'}->{'referer'} || '';
    if($referer ne '') {
        # wait 0.3 seconds, so the command is probably already processed
        usleep(300000);
        $c->redirect($referer);
    } else {
        $c->stash->{template} = 'cmd_success.tt';
    }
    return(1);
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
