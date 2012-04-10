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
use File::Slurp;

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

    # try to read secret file
    $self->{'opt'}->{'credential'} = $self->_read_secret() unless defined $self->{'opt'}->{'credential'};

    return $self;
}

##############################################
sub _read_secret {
    my($self) = @_;
    my $files = [];
    push @{$files}, 'thruk.conf';
    push @{$files}, $ENV{'CATALYST_CONFIG'}.'thruk.conf'       if defined $ENV{'CATALYST_CONFIG'};
    push @{$files}, 'thruk_local.conf';
    push @{$files}, $ENV{'CATALYST_CONFIG'}.'thruk_local.conf' if defined $ENV{'CATALYST_CONFIG'};
    my $var_path = './var';
    for my $file (@{$files}) {
        next unless -f $file;
        open(my $fh, $file);
        while(my $line = <$fh>) {
            next unless $line =~ m/^\s*var_path\s+=\s*(.*)$/mx;
            $var_path = $1;
        }
        close($fh);
    }
    my $secret;
    if(-e $var_path.'/secret.key') {
        $secret = read_file($var_path.'/secret.key');
        chomp($secret);
    }
    return $secret;
}

##############################################
sub _run {
    my($self) = @_;
    my $result = $self->_request($self->{'opt'}->{'credential'}, $self->{'opt'}->{'remoteurl'}, $self->{'opt'});
    unless(defined $result) {
        my($c, $failed) = $self->_dummy_c();
        if($failed) {
            print "command failed";
            return 1;
        }
        $result = _from_local($c, $self->{'opt'})
    }
    binmode STDOUT;
    print STDOUT $result->{'output'};
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
    confess('no data?') unless defined $data_str;
    my $data = decode_json($data_str);
    confess('corrupt data?') unless ref $data eq 'HASH';

    # check credentials
    my $res = {};
    if(   !defined $c->config->{'secret_key'}
       or !defined $data->{'credential'}
       or $c->config->{'secret_key'} ne $data->{'credential'}) {
        $res = {
            'output' => "authorization failed\n",
            'rc'     => 1,
        };
    } else {
        $res = _run_commands($c, $data->{'options'});
    }

    return encode_json($res);
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
        my $x = 0;
        while($result->{'code'} == 302) {
            my $sleep = 0.1 * $x;
            $sleep = 1 if $x > 10;
            sleep($sleep);
            $url = $result->{'headers'}->{'Location'};
            $ENV{'REQUEST_URI'}      = $url;
            $ENV{'SCRIPT_NAME'}      = $url;
            $ENV{'SCRIPT_NAME'}      =~ s/\?(.*)$//gmx;
            $ENV{'QUERY_STRING'}     = $1 if defined $1;
            Catalyst::ScriptRunner->run('Thruk', 'Thrukembedded');
            $result = $ENV{'HTTP_RESULT'};
            $x++;
        }
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
