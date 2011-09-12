package Catalyst::Authentication::Store::FromCGIConf;

use strict;
use warnings;

use Carp;
use Catalyst::Authentication::User::Hash;
use Scalar::Util qw( blessed );
use base qw/Class::Accessor::Fast/;

sub new {
    my ( $class, $config, $app, $realm) = @_;

    my $self = {};
    bless $self, $class;
    return $self;
}

sub from_session {
    my ( $self, $c, $username ) = @_;
    return $username if ref $username;
    return($self->find_user( { username => $username } ));
}

sub find_user {
    my ( $self, $userinfo, $c ) = @_;

    my $username = $userinfo->{'username'};

    my $user = {
            'username' => $username,
            'roles'    => [],
    };

    # add roles from cgi_conf
    my $possible_roles = [
                      'authorized_for_all_host_commands',
                      'authorized_for_all_host_actions',
                      'authorized_for_all_hosts',
                      'authorized_for_all_service_actions',
                      'authorized_for_all_service_commands',
                      'authorized_for_all_services',
                      'authorized_for_configuration_information',
                      'authorized_for_system_commands',
                      'authorized_for_system_information',
					  'authorized_for_host_commands',
                      'authorized_for_service_commands',
                      'authorized_for_host_actions',
                      'authorized_for_service_actions'
                    ];

    for my $role (@{$possible_roles}) {
		if ($role eq 'authorized_for_all_host_actions') {
			if(! defined $c->config->{'cgi_cfg'}->{$role} and ! defined $c->config->{'cgi_cfg'}->{'authorized_for_host_actions'}) {
				$c->config->{'cgi_cfg'}->{$role} = $c->config->{'cgi_cfg'}->{'authorized_for_all_host_commands'};
			}
		}
		if ($role eq 'authorized_for_all_service_actions') {
			if(! defined $c->config->{'cgi_cfg'}->{$role} and ! defined $c->config->{'cgi_cfg'}->{'authorized_for_service_actions'}) {
				$c->config->{'cgi_cfg'}->{$role} = $c->config->{'cgi_cfg'}->{'authorized_for_all_host_commands'};
			}
		}
		
        if(defined $c->config->{'cgi_cfg'}->{$role}) {
            my %contacts = map { $_ => 1 } split/,/mx, $c->config->{'cgi_cfg'}->{$role};
            foreach my $el (sort keys %contacts) {
                my $contactgroup = $c->{'db'}->get_contactgroups(sort => 'name', remove_duplicates => 1, filter => [ name => $el]);
                # if $role is a contactgroup
                next if (!defined($contactgroup->[0]->{'members'}));
                my $member = $contactgroup->[0]->{'members'};
                foreach my $contac (@{$member}) {
				    # Add role if username is a member of contactgroup
                    push @{$user->{'roles'}}, $role if ( $user->{'username'} eq $contac);
                }
            }
            push @{$user->{'roles'}}, $role if ( defined $contacts{$username} or defined $contacts{'*'});
        }
		
    }
    return bless $user, "Catalyst::Authentication::User::Hash";
}


sub user_supports {
    my $self = shift;

    # choose a random user
    scalar keys %{ $self->userhash };
    ( undef, my $user ) = each %{ $self->userhash };

    return($user->supports(@_));
}


__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Store::FromCGIConf - Minimal authentication store with roles from the cgi.cfg

=head1 SYNOPSIS

    use Catalyst::Authentication::Store::FromCGIConf;

    use Catalyst qw/
        Authentication
    /;

    __PACKAGE__->config( 'Plugin::Authentication' =>
                    {
                        default_realm => 'members',
                        realms => {
                            members => {
                                credential => { class => 'Thruk'       },
                                store      => { class => 'FromCGIConf' }
                            }
                        }
                    }
    );


=head1 DESCRIPTION

This authentication store uses the role definitions from the cgi.cfg

You will need to include the Authentication plugin, and at least one Credential
plugin to use this Store.

=head1 CONFIGURATION

=over 4

=item class

The classname used for the store. This is part of
L<Catalyst::Plugin::Authentication> and is the method by which
Catalyst::Authentication::Store::FromCGIConf is loaded as the
user store. For this module to be used, this must be set to
'FromCGIConf'.

=back

=head1 METHODS

There are no publicly exported routines in the Minimal store (or indeed in
most authentication stores)  However, below is a description of the routines
required by L<Catalyst::Plugin::Authentication> for all authentication stores.

=head2 new( $config, $app, $realm )

Constructs a new store object, which uses the user element of the supplied config
hash ref as it's backing structure.

=head2 find_user( $authinfo, $c )

Keys the hash by the 'username' element in the authinfo hash and returns the user.

If the return value is unblessed it will be blessed as
L<Catalyst::Authentication::User::Hash>.

=head2 from_session( $id )

Delegates to C<get_user>.

=head2 user_supports( )

Chooses a random user from the hash and delegates to it.

=head2 get_user( )

Deprecated

=head2 setup( )

=cut
