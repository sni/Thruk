package Thruk::Controller::config;

use warnings;
use strict;

use Thruk::Action::AddDefaults ();

=head1 NAME

Thruk::Controller::config - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);

    $c->stash->{title}            = 'Configuration';
    $c->stash->{infoBoxTitle}     = 'Configuration';
    $c->stash->{page}             = 'config';
    $c->stash->{'no_auto_reload'} = 1;

    return $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );

    my $type = $c->req->parameters->{'type'} || "hosts";
    $c->stash->{type} = $type;

    # timeperiods
    if($type eq 'timeperiods') {
        $c->db->get_timeperiods(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{template} = 'config_timeperiods.tt';
    }

    # commands
    elsif($type eq 'commands') {
        $c->db->get_commands(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{template} = 'config_commands.tt';
    }

    # contacts
    elsif($type eq 'contacts') {
        $c->db->get_contacts(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{template} = 'config_contacts.tt';
    }

    # contactgroups
    elsif($type eq 'contactgroups') {
        $c->db->get_contactgroups(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{template} = 'config_contactgroups.tt';
    }

    # hosts
    elsif($type eq 'hosts') {
        my $filter;
        if(defined $c->req->parameters->{'jump2'}) {
            $filter = [ { 'name' => $c->req->parameters->{'jump2'} } ];
        }
        $c->db->get_hosts(sort => 'name', remove_duplicates => 1, pager => 1, extra_columns => ['contacts', 'contact_groups'], filter => $filter );
        # use obfuscated command later
        for my $hst (@{$c->stash->{'data'}}) {
            $hst->{'_check_command'} = $c->db->expand_command('host' => $hst, 'source' => $c->config->{'show_full_commandline_source'} );
        }
        $c->stash->{template} = 'config_hosts.tt';
    }

    # services
    elsif($type eq 'services') {
        my $filter;
        if( defined $c->req->parameters->{'jump2'} and defined $c->req->parameters->{'jump3'} ) {
            $filter = [ { 'host_name' => $c->req->parameters->{'jump2'}, 'description' => $c->req->parameters->{'jump3'} } ];
        }
        $c->db->get_services(sort => [ 'host_name', 'description' ], remove_duplicates => 1, pager => 1, extra_columns => ['contacts', 'contact_groups'], filter => $filter);
        # use obfuscated command later
        for my $svc (@{$c->stash->{'data'}}) {
            $svc->{'_check_command'} = $c->db->expand_command('host' => $svc, 'service' => $svc, 'source' => $c->config->{'show_full_commandline_source'} );
        }
        $c->stash->{template} = 'config_services.tt';
    }

    # hostgroups
    elsif($type eq 'hostgroups') {
        $c->db->get_hostgroups(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{template} = 'config_hostgroups.tt';
    }

    # servicegroups
    elsif($type eq 'servicegroups') {
        $c->db->get_servicegroups(sort => 'name', remove_duplicates => 1, pager => 1);
        $c->stash->{template} = 'config_servicegroups.tt';
    }
    else {
        Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such type', code => 404 });
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/config.cgi");
    }

    $c->stash->{jump} = $c->req->parameters->{'jump'} || '';

    return 1;
}


1;
