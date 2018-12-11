package Thruk::Controller::error;

use strict;
use warnings;
use Carp qw/cluck confess longmess/;

=head1 NAME

Thruk::Controller::error - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

    predefined errors:

        return $c->detach('/error/index/<nr>');


    custom errors:

        $c->stash->{errorMessage}       = "short error";
        $c->stash->{errorDescription}   = "error description";
        return $c->detach('/error/index/99');

=head1 METHODS

=cut

=head2 index

=cut

sub index {
    my ( $c, $arg1 ) = @_;

    if(!defined $arg1 && defined $c->stash->{'err'}) {
        $arg1 = $c->stash->{'err'};
    }
    if(!defined $arg1 && defined $c->req->parameters->{'error'}) {
        $arg1 = $c->req->parameters->{'error'};
    }
    if(!defined $c) {
        confess("undefined c in error/index");
    }

    Thruk::Action::AddDefaults::begin($c) unless $c->stash->{'root_begin'};
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_SAFE_DEFAULTS) unless defined $c->stash->{'defaults_added'};

    $c->{'errored'}           = 1;
    $c->stash->{errorDetails} = '' unless $c->stash->{errorDetails};

    ###############################
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    # status code must be != 200, otherwise compressed output will fail
    my $code = 500; # internal server error

    # override some errors for admins
    if(defined $arg1 and $arg1 =~ m/^\d+$/mx) {
        if($arg1 == 15 and $c->check_user_roles('authorized_for_all_services')) {
            $arg1 = 18;
        }
        if($arg1 == 5  and $c->check_user_roles('authorized_for_all_hosts')) {
            $arg1 = 17;
        }
    }

    # internal error but all backends failed redirects to "no backend available"
    if("$arg1" eq "13" # can be alphanumeric sometimes
       and defined $c->stash->{'num_selected_backends'}
       and (ref $c->stash->{'failed_backends'} eq 'HASH')
       and (scalar keys %{$c->stash->{'failed_backends'}} >= $c->stash->{'num_selected_backends'})
       and (scalar keys %{$c->stash->{'failed_backends'}} > 0)) {
        $arg1 = 9;
    }

    my $errors = {
        '99'  => {
            'mess' => '',
            'dscr' => '',
        },
        '0'  => {
            'mess' => 'unknown error: '.$arg1,
            'dscr' => 'this is a internal error',
            'code' => 500, # internal server error
        },
        '1'  => {
            'mess' => 'It appears as though you do not have permission to view process information...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
        '2'  => {
            'mess' => 'It appears as though you do not have permission to view the log file...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
        '3'  => {
            'mess' => 'Sorry Dave, I can\'t let you do that...',
            'dscr' => 'It seems that you have chosen to not use the authentication functionality of the CGIs.<br><br>I don\'t want to be personally responsible for what may happen as a result of allowing unauthorized users to issue commands to your Monitoring, so you\'ll have to disable this safeguard if you are really stubborn and want to invite trouble.',
            'code' => 403, # forbidden
        },
        '4'  => {
            'mess' => 'Error: Could not open CGI config file \''.Thruk->config->{'cgi.cfg'}.'\' for reading!',
            'dscr' => 'Here are some things you should check in order to resolve this error:<br><ol><li>Make sure you\'ve installed a CGI config file in its proper location.  See the error message about for details on where the CGI is expecting to find the configuration file. A CGI configuration file (named <b>cgi.cfg</b>) is shipped with your Thruk distribution. </li></ol>',
            'code' => 500, # internal server error
        },
        '5'  => {
            'mess' => 'It appears as though you do not have permission to view information for this host...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
        '6'  => {
            'mess' => 'Error: No command was specified',
            'dscr' => '',
            'code' => 403, # forbidden
        },
        '7'  => {
            'mess' => 'You are requesting to execute an unknown command. Shame on you!',
            'dscr' => '',
            'code' => 403, # forbidden
        },
        '8'  => {
            'mess' => 'It appears as though you do not have permission to view the configuration information you requested...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
        '9'  => {
            'mess'    => 'No Backend available',
            'dscr'    => 'None of the configured Backends could be reached, please have a look at the logfile for detailed information and make sure the core is up and running.',
            'details' => _get_connection_details($c),
            'code'    => 500, # internal server error
        },
        '10' => {
            'mess' => 'You are not authorized.',
            'dscr' => 'It seems like you are not authorized.',
            'code' => 403, # forbidden
        },
        '11' => {
            'mess' => 'It appears as though you do not have permission to send commands...',
            'dscr' => 'If you believe this is an error, check the configuration.',
            'code' => 403, # forbidden
        },
        '12' => {
            'mess' => 'Sorry, I can\'t let you do that...',
            'dscr' => 'This command has been disabled by configuration and therefor cannot be executed.',
            'code' => 403, # forbidden
        },
        '13'  => {
            'mess' => 'internal server error',
            'dscr' => 'please have a look at your log file',
            'code' => 500, # internal server error
        },
        '14'  => {
            'mess' => 'missing backend configuration',
            'dscr' => 'please specify at least one backend in your thruk_local.conf<br>Please read the <a href="http://www.thruk.org/documentation/install.html" target="_blank">setup instructions</a>.',
            'code' => 500, # internal server error
        },
        '15'  => {
            'mess' => 'It appears as though you do not have permission to view information for this service...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
        '17'  => {
            'mess' => 'This host does not exist...',
            'dscr' => 'If you believe this is an error, check your monitoring configuration and make sure all backends are connected.',
            'code' => 404, # not found
        },
        '18'  => {
            'mess' => 'This service does not exist...',
            'dscr' => 'If you believe this is an error, check your monitoring configuration and make sure all backends are connected.',
            'code' => 404, # not found
        },
        '19'  => {
            'mess' => 'not a valid date',
            'dscr' => 'this is not a valid date',
            'code' => 500, # internal server error
        },
        '21'  => {
            'mess' => 'This plugin is not available or enabled',
            'dscr' => 'If you believe this is an error, check the documentation for this plugin',
            'code' => 404, # not found
        },
        '22'  => {
            'mess' => 'No such job',
            'dscr' => 'Job could not be found.',
            'code' => 404, # not found
        },
        '23'  => {
            'mess' => 'Background Job Failed',
            'dscr' => 'background job failed, look at your logfile for details',
            'code' => 500, # internal server error
        },
        '24'  => {
            'mess' => 'Security Alert',
            'dscr' => 'This request is not allowed, details can be found in the thruk.log.',
            'code' => 403, # forbidden
        },
        '25'  => {
            'mess' => 'This page does not exist...',
            'dscr' => 'If you believe this is an error, check your configuration and your logfiles.',
            'code' => 404, # not found
        },
        '26'  => {
            'mess' => 'It appears as though you do not have permission to view this information...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
    };

    $arg1 = 0 unless defined $errors->{$arg1}->{'mess'};
    if($arg1 != 99) {
        $c->stash->{errorMessage}       = $errors->{$arg1}->{'mess'};
        $c->stash->{errorDescription}   = $errors->{$arg1}->{'dscr'};
        $c->stash->{errorDetails}      .= $errors->{$arg1}->{'details'} if defined $errors->{$arg1}->{'details'};
        $code = $errors->{$arg1}->{'code'} if defined $errors->{$arg1}->{'code'};
    }

    if($c->config->{'thruk_debug'}) {
        $c->stash->{errorDetails} .= join('<br>', @{$c->error});
    }

    unless(defined $ENV{'TEST_ERROR'}) { # supress error logging in test mode
        if($code >= 500) {
            $c->log->error("***************************");
            $c->log->error($errors->{$arg1}->{'mess'});
            if($c->stash->{errorDetails}) {
                for my $row (split(/\n|<br>/mx, $c->stash->{errorDetails})) {
                    $c->log->error($row);
                }
            }
            $c->log->error(sprintf("on page: %s\n", $c->req->url)) if defined $c->req->url;
            $c->log->error(sprintf("User: %s\n", $c->stash->{'remote_user'}));
        } else {
            $c->log->debug($errors->{$arg1}->{'mess'});
        }
    }

    if($arg1 == 13 and $c->config->{'show_error_reports'}) {
        for my $error ( @{ $c->error } ) {
            $c->stash->{'stacktrace'} .= $error;
        }
        $c->stash->{'stacktrace'} .= "\n".longmess();
    }

    # clear errors to avoid invinite loops
    $c->clear_errors();

    $c->stash->{'template'} = 'error.tt';

    ###############################
    # try to set the refresh
    if(defined $c->config->{'cgi_cfg'}->{'refresh_rate'} && (!defined $c->stash->{'no_auto_reload'} || $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->config->{'cgi_cfg'}->{'refresh_rate'};
    }

    $c->stash->{'title'}        = "Error"  unless defined $c->stash->{'title'} and $c->stash->{'title'} ne '';
    $c->stash->{'page'}         = "status" unless defined $c->stash->{'page'};
    $c->stash->{'infoBoxTitle'} = "Error"  unless defined $c->stash->{'infoBoxTitle'} and $c->stash->{'infoBoxTitle'} eq '';

    $c->stash->{'navigation'}  = "";
    if($c->config->{'use_frames'} == 0) {
        Thruk::Utils::Menu::read_navigation($c);
    }

    # return errer as json for rest api calls
    if($c->req->path_info =~ m%^/thruk/r/%mx || $c->req->header('X-Thruk-Auth-Key')) {
        if($Thruk::Utils::CLI::verbose && $Thruk::Utils::CLI::verbose >= 2) {
            cluck($c->stash->{errorMessage});
        }
        return $c->render(json => {
            failed      => Cpanel::JSON::XS::true,
            message     => $c->stash->{errorMessage},
            details     => $c->stash->{errorDetails},
            description => $c->stash->{errorDescription},
            code        => $code,
        });
    }

    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
        Thruk::Utils::CLI::_error($c->stash->{errorMessage});
        Thruk::Utils::CLI::_error($c->stash->{errorDescription});
        Thruk::Utils::CLI::_error($c->stash->{errorDetails}) if $c->stash->{errorDetails};
        Thruk::Utils::CLI::_error($c->stash->{stacktrace})   if $c->stash->{stacktrace};
        if($Thruk::Utils::CLI::verbose) {
            cluck($c->stash->{errorMessage});
        }
    }

    $c->stash->{errorDetails} = Thruk::Utils::Filter::escape_html($c->stash->{errorDetails}) if $c->stash->{errorDetails};

    # going back on error pages is ok
    $c->stash->{'disable_backspace'} = 0;

    # do not download errors
    $c->res->headers->header('Content-Disposition', '');
    $c->res->headers->content_type('');

    # do not cache errors
    $c->res->code($code);
    $c->res->headers->last_modified(time);
    $c->res->headers->expires(time - 3600);
    $c->res->headers->header(cache_control => "public, max-age=0");

    # return error as json
    if($c->req->headers->{'accept'} && $c->req->headers->{'accept'} =~ m/application\/json/mx) {
        return $c->render(json => {
            failed      => Cpanel::JSON::XS::true,
            error       => $c->stash->{errorMessage},
            details     => $c->stash->{errorDetails},
            description => $c->stash->{errorDescription},
            code        => $code,
        });
    }

    $c->{'rendered'} = 0; # force rerendering
    return 1;
}

sub _get_connection_details {
    my $c      = shift;
    my $detail = '';

    if($c->stash->{'lmd_error'}) {
        return "lmd error - ".$c->stash->{'lmd_error'};
    }

    for my $pd (keys %{$c->stash->{'backend_detail'}}) {
        next if $c->stash->{'backend_detail'}->{$pd}->{'disabled'} == 2; # hide hidden backends
        $detail .= $c->stash->{'backend_detail'}->{$pd}->{'name'}.': '.($c->stash->{'failed_backends'}->{$pd} || $c->stash->{'backend_detail'}->{$pd}->{'last_error'} || '').' ('.($c->stash->{'backend_detail'}->{$pd}->{'addr'} || '').")\n";
    }
    return $detail;
}

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
