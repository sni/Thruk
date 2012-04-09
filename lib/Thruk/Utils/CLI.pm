package Thruk::Utils::CLI;

=head1 NAME

Thruk::Utils::CLI - Utilities Collection for CLI Tool

=head1 DESCRIPTION

Utilities Collection for CLI Tool

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper;
use LWP::UserAgent;
use JSON::XS;

##############################################

=head1 METHODS

=head2 new

  new()

create CLI Tool object

=cut
sub new {
    my($class, $options) = @_;
    my $self  = {
        'opt' => $options,
    };
    bless $self, $class;
    $ENV{'THRUK_SRC'} = 'CLI';

    return $self;
}

##############################################
sub _run {
    my($self) = @_;
    my $credential = '';
    my $result = $self->_request($credential, $self->{'opt'}->{'remoteurl'}, $self->{'opt'});
    unless(defined $result) {
        my($c, $failed) = $self->_dummy_c();
        if($failed) {
            print "command failed";
            return 1;
        }
        $result = _from_local($c, $self->{'opt'})
    }
    print $result->{'output'};
    return $result->{'rc'};
}

##############################################
sub _request {
    my($self, $credential, $url, $options) = @_;
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->post($url, {
        data => encode_json({
            credential => $credential,
            options    => $options,
        })
    });
    if($response->is_success) {
        my $data_str = $response->decoded_content;
        my $data     = decode_json($data_str);
        return $data;
    }
    return;
}

##############################################
sub _from_fcgi {
    my($c, $data_str) = @_;
    my $data = decode_json($data_str);

    # TODO: check credentials
    return encode_json(_run_commands($c, $data->{'options'}));
}

##############################################
sub _from_local {
    my($c, $options) = @_;
    # verify that we are running with the right user
    require Thruk;
    Thruk->import();
    my $var_path = Thruk->config->{'var_path'} || './var';
    my $uid = (stat $var_path)[4];
    if(!defined $uid) {
        print("Broken installation, could not stat ".$var_path." \n");
        exit 1;
    }
    if($> != $uid) {
        print("Wrong user! Please run as user: ".getpwuid($uid)."\n");
        exit 1;
    }
    $ENV{'NO_EXTERNAL_JOBS'} = 1;
    return _run_commands($c, $options);
}

##############################################
sub _run_commands {
    my($c, $opt) = @_;
    my $data = {
        'output' => '',
        'rc'     => 0,
    };
    if(defined $opt->{'listbackends'}) {
        $data->{'output'} = _listbackends($c);
    }

    if(defined $opt->{'url'}) {
        if($opt->{'url'} =~ m|^\w+\.cgi|gmx) {
            $opt->{'url'} = '/thruk/cgi-bin/'.$opt->{'url'};
        }
        $data->{'output'} = _request_url($c, $opt->{'url'})
    }
    return $data;
}

##############################################
sub _listbackends {
    my($c) = @_;
    my $output = '';
    $output .= sprintf("%-4s  %-7s  %-9s   %s\n", 'Def', 'Key', 'Name', 'Address');
    $output .= sprintf("---------------------------------------\n");
    for my $key (keys %{$c->stash->{'backend_detail'}}) {
        $output .= sprintf("%-4s %-8s %-10s %s\n",
                $c->stash->{'backend_detail'}->{$key}->{'disabled'} == 0 ? ' * ' : '',
                $key,
                $c->stash->{'backend_detail'}->{$key}->{'name'},
                $c->stash->{'backend_detail'}->{$key}->{'addr'},
        );
    }
    $output .= sprintf("---------------------------------------\n");
    return $output;
}

##############################################
sub _request_url {
    my($c, $url) = @_;

    # TODO: use $c->visit() instead

    $ENV{'REQUEST_URI'}      = $url;
    $ENV{'SCRIPT_NAME'}      = $url;
    $ENV{'SCRIPT_NAME'}      =~ s/\?(.*)$//gmx;
    $ENV{'QUERY_STRING'}     = $1 if defined $1;
    $ENV{'SERVER_PROTOCOL'}  = 'HTTP/1.0'  unless defined $ENV{'SERVER_PROTOCOL'};
    $ENV{'REQUEST_METHOD'}   = 'GET'       unless defined $ENV{'REQUEST_METHOD'};
    $ENV{'HTTP_HOST'}        = '127.0.0.1' unless defined $ENV{'HTTP_HOST'};
    $ENV{'REMOTE_ADDR'}      = '127.0.0.1' unless defined $ENV{'REMOTE_ADDR'};
    $ENV{'SERVER_PORT'}      = '80'        unless defined $ENV{'SERVER_PORT'};
    # reset args, otherwise they will be interpreted as args for the script runner
    @ARGV = ();

    require Catalyst::ScriptRunner;
    Catalyst::ScriptRunner->import();
    Catalyst::ScriptRunner->run('Thruk', 'Thrukembedded');
    my $result = $ENV{'HTTP_RESULT'};

    if($result->{'code'} == 302
       and defined $result->{'headers'}
       and defined $result->{'headers'}->{'Location'}
       and $result->{'headers'}->{'Location'} =~ m|/thruk/cgi\-bin/job\.cgi\?job=(.*)$|mx) {
        my $jobid = $1;
    }
    elsif($result->{'code'} != 200) {
        return 'request failed: '.$result->{'code'}."\n".Dumper($result);
    }
    return $result->{'result'};
}

##############################################
sub _dummy_c {
    my($self) = @_;
    my $olduser = $ENV{'REMOTE_USER'};
    $ENV{'REMOTE_USER'} = 'dummy';
    require Catalyst::Test;
    Catalyst::Test->import('Thruk');
    my($res, $c) = ctx_request('/thruk/cgi-bin/remote.cgi');
    defined $olduser ? $ENV{'REMOTE_USER'} = $olduser : delete $ENV{'REMOTE_USER'};
    my $failed = 0;
    $failed = 1 unless $res->code == 200;
    return($c, $failed);
}

1;
