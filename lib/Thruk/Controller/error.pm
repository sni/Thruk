package Thruk::Controller::error;

use warnings;
use strict;
use Carp qw/confess longmess/;
use Cpanel::JSON::XS ();

use Thruk::Action::AddDefaults ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::error - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

    predefined errors:

        return $c->detach('/error/index/<nr>');

    detailed errors:
        return $c->detach_error({
            msg         => "main error",
            descr       => "more descriptive details",
            code        => http code,
            log         => 0|1, #  force logging
            skip_escape => 0|1, # skip html escape of data
        });


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
    if((!defined $arg1 || $arg1 eq '/thruk/cgi-bin/error.cgi' ) && defined $c->req->parameters->{'error'}) {
        $arg1 = $c->req->parameters->{'error'};
    }
    if(!defined $c) {
        confess("undefined c in error/index");
    }

    $c->{'errored'} = 1;

    $c->stash->{no_tt_trim} = 1;

    Thruk::Action::AddDefaults::begin($c) unless $c->stash->{'root_begin'};
    Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS) unless defined $c->stash->{'defaults_added'};

    $c->stash->{errorDetails} = '' unless $c->stash->{errorDetails};

    ###############################
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
        $c->stash->{'show_nav'}     = 0;
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
       && defined $c->stash->{'num_selected_backends'}
       && (ref $c->stash->{'failed_backends'} eq 'HASH')
       && defined $c->stash->{'selected_backends'}
       && (ref $c->stash->{'selected_backends'} eq 'ARRAY')
       && (scalar keys %{$c->stash->{'failed_backends'}} >= $c->stash->{'num_selected_backends'})
       && (scalar keys %{$c->stash->{'failed_backends'}} > 0)) {
        my $all_down = 1;
        for my $key (@{$c->stash->{'selected_backends'}}) {
            if(!$c->stash->{'failed_backends'}->{$key}) {
                $all_down = 0;
                last;
            }
        }
        $arg1 = 9 if $all_down;
    }

    my $errors = {
        '99'  => {
            'mess' => '',
            'dscr' => '',
        },
        '100'  => {
            'mess' => 'bad request',
            'dscr' => 'It appears as you send a bad request.',
            'code' => 400, # bad request
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
            'mess' => 'Error: Could not open CGI config file \''.Thruk::Base->config->{'cgi.cfg'}.'\' for reading!',
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
            'dscr'    => 'None of the selected Backends could be reached, please have a look at the logfile for detailed information and make sure the core is up and running.',
            'details' => _get_connection_details($c),
            'code'    => 503, # Service Unavailable
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
        '24'  => {
            'mess'    => 'CSRF Security Alert',
            'dscr'    => 'Using this formular requires a POST with a valid CSRF token or an API key.',
            'code'    => 403, # forbidden
            'log_req' => 1,
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
        '27'  => {
            'mess'    => 'Wrong Authentication Key',
            'dscr'    => 'It seems like you are using an non-existing or invalid API key.',
            'code'    => 403, # forbidden
        },
        '28'  => {
            'mess'    => 'Authentication by secret key requires X-Thruk-Auth-User header',
            'dscr'    => 'When authenticating by the secret key via X-Thruk-Auth-Key header, you need to set the X-Thruk-Auth-User header as well.',
            'code'    => 400, # bad request
        },
    };

    $arg1 = 0 unless defined $errors->{$arg1}->{'mess'};
    if($arg1 != 99) {
        $c->stash->{errorMessage}       = $errors->{$arg1}->{'mess'};
        $c->stash->{errorDescription}   = $errors->{$arg1}->{'dscr'};
        $c->stash->{errorDetails}      .= $errors->{$arg1}->{'details'} if defined $errors->{$arg1}->{'details'};
        $code = $errors->{$arg1}->{'code'} if defined $errors->{$arg1}->{'code'};
    }

    my $errorDetails = join("\n", @{$c->error});
    $c->stash->{errorDebugInfo} = '' unless $c->stash->{errorDebugInfo};

    # redirected from $c->detach_error()
    my $log_req;
    if($c->stash->{'error_data'}) {
        $c->stash->{'raw_error_data'} = Thruk::Utils::dclone($c->stash->{'error_data'});
        if(!$c->stash->{'error_data'}->{'skip_escape'}) {
            my $stack = delete $c->stash->{'error_data'}->{'stacktrace'};
            Thruk::Utils::Filter::html_escape_recursive($c->stash->{'error_data'});
            $c->stash->{'error_data'}->{'skip_escape'} = 1;
            $c->stash->{'error_data'}->{'stacktrace'}  = $stack if $stack;
        }
        $c->stash->{errorMessage}       = $c->stash->{'error_data'}->{'msg'};
        $c->stash->{errorDescription}   = $c->stash->{'error_data'}->{'descr'} // "";
        $code                           = $c->stash->{'error_data'}->{'code'}  // 500;
        $log_req                        = $c->stash->{'error_data'}->{'log'} if defined $c->stash->{'error_data'}->{'log'};
        $c->stash->{errorDebugInfo}     = $c->stash->{'error_data'}->{'debug_information'} if $c->stash->{'error_data'}->{'debug_information'};
        $c->stash->{'stacktrace'}      .= $c->stash->{'error_data'}->{'stacktrace'} if $c->stash->{'error_data'}->{'stacktrace'};
    }

    if($arg1 == 13 and $c->config->{'show_error_reports'}) {
        for my $error ( @{ $c->error } ) {
            $c->stash->{'stacktrace'} .= $error;
        }
        $c->stash->{'stacktrace'} .= "\n".longmess("stacktrace from error controller") unless $c->stash->{'stacktrace'} =~ m/Thruk.pm/gmx;
    }

    if(!$c->stash->{'stacktrace'} && $c->stash->{'thruk_author'}) {
        $c->stash->{'stacktrace'} .= Carp::longmess("stacktrace from error controller");
    }

    unless(defined $ENV{'TEST_ERROR'}) { # supress error logging in test mode
        if($code == 503 && $c->stash->{errorDetails} =~ m/connecting\./mx) {
            # check if all lmd backends are in connecting state
            _warn("cannot process request, all backends are in state 'connecting'.");
            $c->stash->{errorDescription} .= "\nplease try again in a  few seconds.";
        }
        elsif((!defined $log_req || $log_req) && ($code >= 500 || $errors->{$arg1}->{'log_req'} || $log_req)) {
            Thruk::Utils::log_error_with_details($c, $c->stash->{errorMessage}, $c->stash->{errorDescription}, $c->stash->{errorDetails}, $errorDetails, $c->stash->{errorDebugInfo});
            $log_req = 0; # do not log twice
        } else {
            _debug($errors->{$arg1}->{'mess'} || $c->stash->{errorMessage});
            _debug($c->stash->{errorDescription}) if $c->stash->{errorDescription};
            _debug($c->stash->{errorDebugInfo})   if $c->stash->{errorDebugInfo};
        }
    }

    if(Thruk::Base->debug) {
        $c->stash->{errorDetails} .= "\n" if $c->stash->{errorDetails};
        $c->stash->{errorDetails} .= $errorDetails;
    }

    # clear errors to avoid invinite loops
    $c->clear_errors();

    $c->stash->{'template'} = 'error.tt';

    ###############################
    # try to set the refresh
    if(defined $c->config->{'refresh_rate'} && (!defined $c->stash->{'no_auto_reload'} || $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->config->{'refresh_rate'};
    }
    if($arg1 == 13) {
        $c->stash->{'no_auto_reload'}        = 1;
        $c->stash->{'refresh_rate'}          = 0;
        $c->stash->{'hide_backends_chooser'} = 1;
    }

    $c->stash->{'title'}        = "Error"  unless defined $c->stash->{'title'} and $c->stash->{'title'} ne '';
    $c->stash->{'page'}         = "status" unless defined $c->stash->{'page'};
    $c->stash->{'real_page'}    = 'error';
    $c->stash->{'infoBoxTitle'} = "Error"  unless $c->stash->{'infoBoxTitle'};

    $c->stash->{'navigation'}  = "";
    Thruk::Utils::Menu::read_navigation($c);

    # do not cache errors
    $c->res->code($code);
    $c->res->headers->last_modified(time);
    $c->res->headers->expires(time - 3600);
    $c->res->headers->header(cache_control => "public, max-age=0");

    # return error as json for rest api calls
    if($c->want_json_response()) {
        if(Thruk::Base->verbose >= 2) {
            Carp::cluck($c->stash->{errorMessage});
        }
        my $json = {
            failed      => Cpanel::JSON::XS::true,
            message     => $c->stash->{errorMessage},
            code        => $code,
        };
        $json->{'details'}     = $c->stash->{errorDetails}     if $c->stash->{errorDetails};
        $json->{'description'} = $c->stash->{errorDescription} if $c->stash->{errorDescription};
        return $c->render(json => $json);
    }

    if(Thruk::Base->mode_cli() && (!defined $log_req || $log_req)) {
        _error($c->stash->{'raw_error_data'}->{'msg'} // $c->stash->{errorMessage});
        _error($c->stash->{'raw_error_data'}->{'descr'} // $c->stash->{errorDescription});
        _error($c->stash->{errorDetails}) if $c->stash->{errorDetails};
        _error($c->stash->{stacktrace})   if $c->stash->{stacktrace};
        if(Thruk::Base->verbose) {
            Carp::cluck("stacktrace:");
        }
    }

    # going back on error pages is ok
    $c->stash->{'disable_backspace'} = 0;

    if(!$c->stash->{'hide_backends_chooser'}) {
        $c->stash->{'hide_backends_chooser'} = ref $c->stash->{'sites'} ne 'ARRAY' ? 1 : 0;
    }

    # do not download errors
    $c->res->headers->header('Content-Disposition', '');
    $c->res->headers->content_type('');

    $c->{'rendered'} = 0; # force rerendering
    return 1;
}

sub _get_connection_details {
    my($c) = @_;
    my $detail = '';

    if($c->stash->{'lmd_error'}) {
        return "lmd error - ".$c->stash->{'lmd_error'};
    }

    my $listed = {};
    my $selected = Thruk::Base::array2hash($c->stash->{'selected_backends'});
    for my $pd (sort keys %{$c->stash->{'failed_backends'}}) {
        my $peer = $c->db->get_peer_by_key($pd);
        my $name = $pd;
        if($peer) {
            $name = $peer->{'name'};
        }
        $listed->{$pd} = 1;
        $detail .= sprintf("%-10s: %-6s %s (addr: %s)\n",
                                $name,
                                _state2txt($c->stash->{'backend_detail'}->{$pd}->{'state'}),
                                ($c->stash->{'failed_backends'}->{$pd}//''),
                                $peer->{'addr'},
                    );
    }

    for my $pd (sort keys %{$c->stash->{'backend_detail'}}) {
        next if $c->stash->{'backend_detail'}->{$pd}->{'disabled'} == 2; # hide hidden backends
        next if $listed->{$pd};
        next unless $selected->{$pd};
        $detail .= sprintf("%-10s: %-6s %s (addr: %s)\n",
                                ($c->stash->{'backend_detail'}->{$pd}->{'name'} // $pd),
                                _state2txt($c->stash->{'backend_detail'}->{$pd}->{'state'}),
                                ($c->stash->{'failed_backends'}->{$pd} || $c->stash->{'backend_detail'}->{$pd}->{'last_error'} || ''),
                                ($c->stash->{'backend_detail'}->{$pd}->{'addr'} || ''),
                    );
    }
    return $detail;
}

sub _state2txt {
    my($state) = @_;
    if($state == 1) {
        return("DOWN");
    }
    return("OK");
}

1;
