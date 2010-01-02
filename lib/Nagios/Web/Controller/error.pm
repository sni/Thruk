package Nagios::Web::Controller::error;

use strict;
use warnings;
use Data::Dumper;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::error - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(1) {
    my ( $self, $c, $arg1 ) = @_;

    # if there is no cgi config, always return the cgi error
    if(!defined $c->{'cgi_cfg'} or scalar keys %{$c->{'cgi_cfg'}} == 0) { $arg1 = 4; }

    my $code = 200;

    my $errors = {
        '99'  => {
            'mess' => '',
            'dscr' => '',
        },
        '0'  => {
            'mess' => 'unknown error: '.$arg1,
            'dscr' => 'this is a internal error',
            'code' => 500,
        },
        '1'  => {
            'mess' => 'It appears as though you do not have permission to view process information...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
        },
        '2'  => {
            'mess' => 'It appears as though you do not have permission to view the log file...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
        },
        '3'  => {
            'mess' => 'Sorry Dave, I can\'t let you do that...',
            'dscr' => 'It seems that you have chosen to not use the authentication functionality of the CGIs.<br><br>I don\'t want to be personally responsible for what may happen as a result of allowing unauthorized users to issue commands to Nagios,so you\'ll have to disable this safeguard if you are really stubborn and want to invite trouble.<br><br><strong>Read the section on CGI authentication in the HTML documentation to learn how you can enable authentication and why you should want to.',
        },
        '4'  => {
            'mess' => 'Error: Could not open CGI config file \''.Nagios::Web->config->{'cgi_cfg'}.'\' for reading!',
            'dscr' => 'Here are some things you should check in order to resolve this error:</p><p></p><ol><li>Make sure you\'ve installed a CGI config file in its proper location.  See the error message about for details on where the CGI is expecting to find the configuration file.  A sample CGI configuration file (named <b>cgi.cfg</b>) can be found in the <b>sample-config/</b> subdirectory of the Nagios source code distribution. </li><li>Make sure the user your web server is running as has permission to read the CGI config file.</li></ol><p></p><p>Make sure you read the documentation on installing and configuring Nagios thoroughly before continuing.  If all else fails, try sending a message to one of the mailing lists.  More information can be found at <a href="http://www.nagios.org">http://www.nagios.org</a>.</p> ',
            'code' => 500,
        },
        '5'  => {
            'mess' => 'It appears as though you do not have permission to view information for this host...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
        },
        '6'  => {
            'mess' => 'Error: No command was specified',
            'dscr' => '',
        },
        '7'  => {
            'mess' => 'You are requesting to execute an unknown command. Shame on you!',
            'dscr' => '',
        },
        '8'  => {
            'mess' => 'It appears as though you do not have permission to view the configuration information you requested...',
            'dscr' => 'If you believe this is an error, check the HTTP server authentication requirements for accessing this CGI<br>and check the authorization options in your CGI configuration file.',
        },
        '9'  => {
            'mess' => 'No Backend available',
            'dscr' => 'None of the configured Backends could be reached, please have a look at the logfile for more information.',
            'code' => 500,
        },
        '10' => {
            'mess' => 'You are not authorized.',
            'dscr' => 'It seems like you are not authorized.',
        },
        '11' => {
            'mess' => 'It appears as though you do not have permission to send commands...',
            'dscr' => 'If you believe this is an error, check the configuration.',
        },
        '12' => {
            'mess' => 'Sorry, I can\'t let you do that...',
            'dscr' => 'This command has been disabled by configuration and therefor cannot be executed.',
        },
    };

    $arg1 = 0 unless defined $errors->{$arg1}->{'mess'};
    if($arg1 != 99) {
        $c->stash->{errorMessage}       = $errors->{$arg1}->{'mess'};
        $c->stash->{errorDescription}   = $errors->{$arg1}->{'dscr'};
        $code = $errors->{$arg1}->{'code'} if defined $errors->{$arg1}->{'code'};
    }

    Nagios::Web->config->{'custom-error-message'}->{'error-template'}    = 'error.tt';
    Nagios::Web->config->{'custom-error-message'}->{'response-status'}   = $code;
    if($code == 500) {
        #$c->error($errors->{$arg1}->{'mess'});
        $c->log->error($errors->{$arg1}->{'mess'});
    } else {
        $c->log->info($errors->{$arg1}->{'mess'});
    }

    ###############################
    if($c->user_exists) {
        $c->stash->{'remote_user'}  = $c->user->get('username');
    } else {
        $c->stash->{'remote_user'}  = '?';
    }

    $c->stash->{'template'} = Nagios::Web->config->{'custom-error-message'}->{'error-template'};
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
