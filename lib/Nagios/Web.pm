package Nagios::Web;

use 5.008000;
use strict;
use warnings;

use Catalyst::Runtime '5.70';
use Nagios::MKLivestatus;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use parent qw/Catalyst/;
use Catalyst qw/
                Authentication
                Authorization::Roles
                CustomErrorMessage
                ConfigLoader
                StackTrace
                Static::Simple/;
our $VERSION = '0.10_2';

# Configure the application.
#
# Note that settings in nagios_web.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config('name'                   => 'Nagios::Web',
                    'Plugin::ConfigLoader'   => { file => 'nagios_web.conf' },
                    'Plugin::Authentication' => {
                        default_realm => 'Nagios',
                        realms => {
                            Nagios => { credential => { class => 'Nagios'      },
                                        store      => { class => 'FromCGIConf' },
                            }
                        }
                    },
                    'custom-error-message' => {
                        'error-template'    => 'error.tt',
                        'response-status'   => 500,
                    },
                    'static' => {
                        'ignore_extensions' => [ qw/tpl tt tt2/ ],
                    },
 );


# Start the application
__PACKAGE__->setup();


=head1 NAME

Nagios::Web - Catalyst based application

=head1 SYNOPSIS

    script/nagios_web_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Nagios::Web::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
