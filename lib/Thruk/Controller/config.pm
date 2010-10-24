package Thruk::Controller::config;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::config - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{title}            = 'Configuration';
    $c->stash->{infoBoxTitle}     = 'Configuration';
    $c->stash->{page}             = 'config';
    $c->stash->{template}         = 'config.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );

    my $type = $c->{'request'}->{'parameters'}->{'type'};
    $c->stash->{type}             = $type;
    return unless defined $type;

    # timeperiods
    if($type eq 'timeperiods') {
        my $data = $c->{'db'}->get_timeperiods(sort => 'name', remove_duplicates => 1);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_timeperiods.tt';
    }

    # commands
    if($type eq 'commands') {
        my $data = $c->{'db'}->get_commands(sort => 'name', remove_duplicates => 1);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_commands.tt';
    }

    # contacts
    elsif($type eq 'contacts') {
        my $data = $c->{'db'}->get_contacts(sort => 'name', remove_duplicates => 1);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_contacts.tt';
    }

    # contactgroups
    elsif($type eq 'contactgroups') {
        my $data = $c->{'db'}->get_contactgroups(sort => 'name', remove_duplicates => 1);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_contactgroups.tt';
    }

    # hosts
    elsif($type eq 'hosts') {
        my $data = $c->{'db'}->get_hosts(sort => 'name', remove_duplicates => 1);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_hosts.tt';
    }

    # services
    elsif($type eq 'services') {
        my $data = $c->{'db'}->get_services(sort => [ 'host_name', 'description' ], remove_duplicates => 1);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_services.tt';
    }

    # hostgroups
    elsif($type eq 'hostgroups') {
        my $data = $c->{'db'}->get_hostgroups(sort => 'name');
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_hostgroups.tt';
    }

    # servicegroups
    elsif($type eq 'servicegroups') {
        my $data = $c->{'db'}->get_servicegroups(sort => 'name');
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_servicegroups.tt';
    }

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
