package Thruk::Controller::error;

use strict;
use warnings;
use Data::Dumper;
use Carp;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::error - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(1) :ActionClass('RenderView') {
    my ( $self, $c, $arg1 ) = @_;

    if(!defined $c) {
        confess("undefined c in error/index");
    }

    # status code must be != 200, otherwise compressed output will fail
    my $code = 500; # internal server error

    # override some errors for admins
    if(defined $arg1 and $arg1 == 15 and $c->check_user_roles('authorized_for_all_services')) {
        $arg1 = 18;
    }
    if(defined $arg1 and $arg1 == 5  and $c->check_user_roles('authorized_for_all_hosts')) {
        $arg1 = 17;
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
            'mess' => 'Error: Could not open CGI config file \''.Thruk->config->{'cgi_cfg'}.'\' for reading!',
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
            'mess' => 'No Backend available',
            'dscr' => 'None of the configured Backends could be reached, please have a look at the logfile for more information.',
            'code' => 500, # internal server error
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
            'dscr' => 'please specify at least one livestatus backend in your thruk_local.conf',
            'code' => 500, # internal server error
        },
        '15'  => {
            'mess' => 'It appears as though you do not have permission to view information for this service...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
            'code' => 403, # forbidden
        },
        '16'  => {
            'mess' => 'missing library',
            'dscr' => 'problems while loading graphics library, look at your logfile for details',
            'code' => 500, # internal server error
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
    };

    $arg1 = 0 unless defined $errors->{$arg1}->{'mess'};
    if($arg1 != 99) {
        $c->stash->{errorMessage}       = $errors->{$arg1}->{'mess'};
        $c->stash->{errorDescription}   = $errors->{$arg1}->{'dscr'};
        $code = $errors->{$arg1}->{'code'} if defined $errors->{$arg1}->{'code'};
    }

    Thruk->config->{'custom-error-message'}->{'error-template'}    = 'error.tt';
    Thruk->config->{'custom-error-message'}->{'response-status'}   = $code;
    $c->response->status($code);
    unless(defined $ENV{'TEST_ERROR'}) { # supress error logging in test mode
        if($code >= 500) {
            $c->log->error($errors->{$arg1}->{'mess'});
            $c->log->error("on page: ".$c->request->uri) if defined $c->request->uri;
        } else {
            $c->log->info($errors->{$arg1}->{'mess'});
        }
    }

    # clear errors to avoid invinite loops
    $c->clear_errors();

    ###############################
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    $c->stash->{'template'} = Thruk->config->{'custom-error-message'}->{'error-template'};

    ###############################
    # try to set the refresh
    if(defined $c->config->{'cgi_cfg'}->{'refresh_rate'} and (!defined $c->stash->{'no_auto_reload'} or $c->stash->{'no_auto_reload'} == 0)) {
        $c->stash->{'refresh_rate'} = $c->config->{'cgi_cfg'}->{'refresh_rate'};
    }

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
