package Thruk::Utils::Auth;

=head1 NAME

Thruk::Utils::Auth - Authorization Utilities for Thruk

=head1 DESCRIPTION

Authorization Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;


##############################################
=head1 METHODS

=cut

##############################################

=head2 get_auth_filter

  my $filter_string = get_auth_filter('hosts');

returns a filter which can be used for authorization

=cut
sub get_auth_filter {
    my($c, $type, $strict) = @_;
    $strict = 0 unless defined $strict;

    return if $type eq 'status';

    confess("no backend!") unless defined $c->{'db'};

    # if authentication is completly disabled
    if($c->config->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} == 0) {
        return;
    }

    # no user at all, for example when used by cli
    unless ($c->user_exists) {
        return;
    }

    if($strict and $type ne 'hosts' and $type ne 'services') {
        croak("strict authorization not implemented for: ".$type);
    }

    # host authorization
    if($type eq 'hosts') {
        if(!$strict && $c->check_user_roles('authorized_for_all_hosts')) {
            return();
        }
        return('contacts' => { '>=' => $c->user->get('username') });
    }

    # hostgroups authorization
    elsif($type eq 'hostgroups') {
        return();
    }

    # service authorization
    elsif($type eq 'services') {
        if(!$strict && $c->check_user_roles('authorized_for_all_services')) {
            return();
        }
        if($c->config->{'use_strict_host_authorization'}) {
            return('contacts' => { '>=' => $c->user->get('username') });
        } else {
            return('-or' => [ 'contacts'      => { '>=' => $c->user->get('username') },
                              'host_contacts' => { '>=' => $c->user->get('username') },
                            ],
                  );
        }
    }

    # servicegroups authorization
    elsif($type eq 'servicegroups') {
        return();
    }

    # servicegroups authorization
    elsif($type eq 'timeperiods') {
        return();
    }

    # contactgroups authorization
    elsif($type eq 'contactgroups') {
        return();
    }

    # comments / downtimes authorization
    elsif($type eq 'comments' or $type eq 'downtimes') {
        my @filter;

        if(    $c->check_user_roles('authorized_for_all_services')
           and $c->check_user_roles('authorized_for_all_hosts')) {
            return;
        }

        if($c->check_user_roles('authorized_for_all_services')) {
            push @filter, { 'service_description' => { '!=' => undef } };
        } else {
            push @filter, '-and' => [ 'service_contacts'    => { '>=' => $c->user->get('username') },
                                      'service_description' => { '!=' => undef },
                                    ];
        }

        if($c->check_user_roles('authorized_for_all_hosts')) {
            push @filter, { 'service_description' => undef };
        } else {
            if(Thruk->config->{'use_strict_host_authorization'}) {
                push @filter, '-and ' => [ 'host_contacts'       => { '>=' => $c->user->get('username') },
                                           'service_description' => undef,
                                         ];
            } else {
                push @filter, { 'host_contacts' => { '>=' => $c->user->get('username') }};
            }
        }
        return Thruk::Utils::combine_filter('-or', \@filter);
    }

    # logfile authorization
    elsif($type eq 'log') {
        my @filter;
        my $log_filter = { filter => undef };

        if(    $c->check_user_roles('authorized_for_all_services')
           and $c->check_user_roles('authorized_for_all_hosts')
           and $c->check_user_roles('authorized_for_system_information')) {
            return({ auth_filter => $log_filter}) if $c->config->{'logcache'};
            return;
        }

        $log_filter->{'username'} = $c->user->get('username');

        # service log entries
        if($c->check_user_roles('authorized_for_all_services')) {
            $log_filter->{'authorized_for_all_services'} = 1;
            # allowed for all services related log entries
            push @filter, { 'service_description' => { '!=' => undef } };
        }
        else {
            push @filter, { '-and' => [
                              'current_service_contacts' => { '>=' => $c->user->get('username') },
                              'service_description'      => { '!=' => undef },
                          ]}
        }

        # host log entries
        if($c->check_user_roles('authorized_for_all_hosts')) {
            $log_filter->{'authorized_for_all_hosts'} = 1;
            # allowed for all host related log entries
            push @filter, { '-and' => [ 'service_description' => undef,
                                        'host_name'           => { '!=' => undef } ],
                          };
        }
        else {
            if(Thruk->config->{'use_strict_host_authorization'}) {
                $log_filter->{'strict'} = 1;
                # only allowed for the host itself, not the services
                push @filter, { -and => [ 'current_host_contacts' => { '>=' => $c->user->get('username') }, { 'service_description' => undef }]};
            } else {
                # allowed for all hosts and its services
                push @filter, { 'current_host_contacts' => { '>=' => $c->user->get('username') } };
            }
        }

        # other log entries
        if($c->check_user_roles('authorized_for_system_information')) {
            $log_filter->{'authorized_for_system_information'} = 1;
            # everything not related to a specific host or service
            push @filter, { '-and' => [ 'service_description' => undef, 'host_name' => undef ]};
        }

        # combine all filter by OR
        $log_filter->{'filter'} = {'-or' => \@filter};
        return({ auth_filter => $log_filter}) if $c->config->{'logcache'};
        return($log_filter->{'filter'});
    }
    elsif($type eq 'contact') {
        if($c->check_user_roles('authorized_for_configuration_information')) {
            return();
        }
        return('name' => $c->user->get('username'));
    }

    else {
        confess("type $type not supported");
    }

    confess("cannot authorize query");
}


1;
