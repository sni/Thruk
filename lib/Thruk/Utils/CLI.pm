package Thruk::Utils::CLI;

=head1 NAME

Thruk::Utils::CLI - Utilities Collection for CLI Tool

=head1 DESCRIPTION

Utilities Collection for CLI scripting with Thruk. Allows you to access internal
structures and change config information.

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper;
use LWP::UserAgent;
use JSON::XS;
use File::Slurp;
use URI::Escape;

$Thruk::Utils::CLI::verbose = 0;
$Thruk::Utils::CLI::c       = undef;

##############################################

=head1 METHODS

=head2 new

    new([ $options ])

 $options = {
    verbose         => 0|1,         # be more verbose
    credential      => 'secret',    # secret key when accessing remote instances
    remoteurl       => 'url',       # url where to access remote instances
    local           => 0|1,         # local requests only
 }

create CLI tool object

=cut
sub new {
    my($class, $options) = @_;
    $Thruk::Utils::CLI::verbose = $options->{'verbose'} if defined $options->{'verbose'};
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

=head2 get_c

    get_c()

return L<Catalyst|Catalyst> context object

=cut
sub get_c {
    my($self) = @_;
    return $Thruk::Utils::CLI::c if defined $Thruk::Utils::CLI::c;
    my($c, $failed) = $self->_dummy_c();
    $Thruk::Utils::CLI::c = $c;
    return $c;
}

##############################################

=head1 OBJECT CONFIGURATION

These methods will only be available if you have the config tool plugin enabled
and if you set core config items to access the core objects config.

=head2 get_object_db

    get_object_db()

Return config database as a L<Monitoring::Config|Monitoring::Config> object.

=cut
sub get_object_db {
    my($self) = @_;
    my $c = $self->get_c();
    die("config tool not enabled") unless $c->config->{'use_feature_configtool'} == 1;
    Thruk::Utils::Conf::set_object_model($c) or die("failed to set objects model");
    return $c->{'obj_db'};
}

##############################################

=head2 store_objects

    store_objects()

Store changed objects. Changes will be stashed into Thruks internal object cache
and can then be saved, reviewed or discarded.

=cut
sub store_objects {
    my($self) = @_;
    my $c = $self->get_c();
    die("config tool not enabled") unless $c->config->{'use_feature_configtool'} == 1;
    $c->{'obj_db'}->{'needs_commit'} = 1;
    $c->{'obj_db'}->{'last_changed'} = time();
    Thruk::Utils::Conf::store_model_retention($c) or die("failed to store objects model");
    return;
}


##############################################
# INTERNAL SUBS
##############################################
sub _read_secret {
    my($self) = @_;
    my $files = [];
    push @{$files}, 'thruk.conf';
    push @{$files}, $ENV{'CATALYST_CONFIG'}.'/thruk.conf'       if defined $ENV{'CATALYST_CONFIG'};
    push @{$files}, 'thruk_local.conf';
    push @{$files}, $ENV{'CATALYST_CONFIG'}.'/thruk_local.conf' if defined $ENV{'CATALYST_CONFIG'};
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
    my $secretfile = $var_path.'/secret.key';
    if(-e $secretfile) {
        _debug("reading secret file: ".$secretfile);
        $secret = read_file($var_path.'/secret.key');
        chomp($secret);
    } else {
        _debug("reading secret file ".$secretfile." failed: ".$!);
    }
    return $secret;
}

##############################################
sub _run {
    my($self) = @_;
    my($result, $response);
    _debug("_run(): ".Dumper($self->{'opt'}));
    unless($self->{'opt'}->{'local'}) {
        ($result,$response) = $self->_request($self->{'opt'}->{'credential'}, $self->{'opt'}->{'remoteurl'}, $self->{'opt'});
    }
    if(!defined $result and $self->{'opt'}->{'remoteurl'} !~ m|/localhost/|mx) {
        print STDERR "remote command failed:\n".Dumper($response);
        return 1;
    }

    unless(defined $result) {
        my($c, $failed) = $self->_dummy_c();
        if($failed) {
            print STDERR "command failed";
            return 1;
        }
        $result = $self->_from_local($c, $self->{'opt'})
    }

    # no output?
    if(!defined $result->{'output'}) {
        return $result->{'rc'};
    }

    # with output
    if($result->{'rc'} == 0) {
        binmode STDOUT;
        print STDOUT $result->{'output'};
    } else {
        binmode STDERR;
        print STDERR $result->{'output'};
    }
    return $result->{'rc'};
}

##############################################
sub _request {
    my($self, $credential, $url, $options) = @_;
    _debug("_request(".$url.")");
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->post($url, {
        data => encode_json({
            credential => $credential,
            options    => $options,
        })
    });
    if($response->is_success) {
        _debug(" -> success");
        my $data_str = $response->decoded_content;
        my $data     = decode_json($data_str);
        return($data, $response);
    } else {
        _debug(" -> failed: ".Dumper($response));
    }
    return(undef, $response);
}

##############################################
sub _dummy_c {
    my($self) = @_;
    _debug("_dummy_c()");
    require Catalyst::Test;
    Catalyst::Test->import('Thruk');
    my($res, $c) = ctx_request('/thruk/cgi-bin/remote.cgi');
    my $failed = ( $res->code == 200 ? 0 : 1 );
    return($c, $failed);
}

##############################################
sub _from_local {
    my($self, $c, $options) = @_;
    _debug("_from_local()");

    # verify that we are running with the right user
    require Thruk;
    Thruk->import();
    my $var_path = Thruk->config->{'var_path'} || './var';
    _debug("var_path: ".$var_path);
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
sub _from_fcgi {
    my($c, $data_str) = @_;
    confess('no data?') unless defined $data_str;
    my $data = decode_json($data_str);
    confess('corrupt data?') unless ref $data eq 'HASH';
    $Thruk::Utils::CLI::verbose = $data->{'options'}->{'verbose'} if defined $data->{'options'}->{'verbose'};
    $Thruk::Utils::CLI::c       = $c;

    # check credentials
    my $res = {};
    if(   !defined $c->config->{'secret_key'}
       or !defined $data->{'credential'}
       or $c->config->{'secret_key'} ne $data->{'credential'}) {
        $res = {
            'version' => $c->config->{'version'},
            'output'  => "authorization failed\n",
            'rc'      => 1,
        };
    } else {
        $res = _run_commands($c, $data->{'options'});
    }

    return encode_json($res);
}

##############################################
sub _run_commands {
    my($c, $opt) = @_;
    $c->stats->profile(begin => "Utils::CLI::_run_commands");
    my $data = {
        'version' => $c->config->{'version'},
        'output'  => '',
        'rc'      => 0,
    };

    # which command to run?
    my $action = $opt->{'action'};
    if(defined $opt->{'url'} and $opt->{'url'} ne '') {
        $action = 'url='.$opt->{'url'};
    }
    if(defined $opt->{'listbackends'}) {
        $action = 'listbackends';
    }

    # list backends
    if($action eq 'listbackends') {
        $data->{'output'} = _listbackends($c);
        $c->stats->profile(end => "Utils::CLI::_run_commands");
        return $data;
    }

    # request url
    if($action =~ /^url=(.*)$/mx) {
        my $url = $1;
        if($url =~ m|^\w+\.cgi|gmx) {
            $url = '/thruk/cgi-bin/'.$url;
        }
        $data->{'output'} = _request_url($c, $url);
    }

    # report or report mails
    if($action =~ /^report(\w*)=(.*)$/mx) {
        eval {
            require Thruk::Utils::Reports;
        };
        if($@) {
            $data->{'output'} = "reports plugin is not enabled.\n";
            $data->{'rc'}     = 1;
            return $data;
        }
        my $mail = $1;
        my $nr   = $2;
        if($mail eq 'mail') {
            if(Thruk::Utils::Reports::report_send($c, $nr)) {
                $data->{'output'} = "mail send successfully\n";
            } else {
                $data->{'output'} = "cannot send mail\n";
                $data->{'rc'}     = 1;
            }
        } else {
            my $pdf_file = Thruk::Utils::Reports::generate_report($c, $nr);
            if(defined $pdf_file) {
                $data->{'output'} = read_file($pdf_file);
            }
        }
    }

   # downtime?
   if($action =~ /^downtimetask=(.*)$/mx) {
        my $downtime = Thruk::Utils::read_data_file($1);
        # convert to normal url request
        my $url = sprintf('/thruk/cgi-bin/cmd.cgi?cmd_mod=2&cmd_typ=%d&host=%s&com_data=%s&com_author=%s&trigger=0&start_time=%s&end_time=%s&fixed=1&childoptions=0&backend=%s%s',
                          $downtime->{'service'} ? 56 : 55,
                          uri_escape($downtime->{'host'}),
                          uri_escape($downtime->{'comment'}),
                          'cron',
                          uri_escape(Thruk::Utils::format_date(time(), '%Y-%m-%d %H:%M:%S')),
                          uri_escape(Thruk::Utils::format_date(time() + ($downtime->{'duration'}*60), '%Y-%m-%d %H:%M:%S')),
                          $downtime->{'backends'},
                          $downtime->{'service'} ? '&service='.uri_escape($downtime->{'service'}) : '',
                         );
        my $old = $c->config->{'cgi_cfg'}->{'lock_author_names'};
        $c->config->{'cgi_cfg'}->{'lock_author_names'} = 0;
        _request_url($c, $url);
        $c->config->{'cgi_cfg'}->{'lock_author_names'} = $old;
        if($downtime->{'service'}) {
            $data->{'output'} = 'scheduled downtime for '.$downtime->{'service'}.' on '.$downtime->{'host'};
        } else {
            $data->{'output'} = 'scheduled downtime for '.$downtime->{'host'};
        }
        $data->{'output'} .= " (duration ".Thruk::Utils::Filter::duration($downtime->{'duration'}*60).")\n";
   }

    $c->stats->profile(end => "Utils::CLI::_run_commands");
    return $data;
}

##############################################
sub _listbackends {
    my($c) = @_;
    $c->{'db'}->enable_backends();
    $c->{'db'}->get_processinfo();
    Thruk::Action::AddDefaults::_set_possible_backends($c, {});
    my $output = '';
    $output .= sprintf("%-4s  %-7s  %-9s   %s\n", 'Def', 'Key', 'Name', 'Address');
    $output .= sprintf("---------------------------------------\n");
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        $output .= sprintf("%-4s %-8s %-10s %s",
                (!defined $peer->{'hidden'} or $peer->{'hidden'} == 0) ? ' * ' : '',
                $key,
                $c->stash->{'backend_detail'}->{$key}->{'name'},
                $c->stash->{'backend_detail'}->{$key}->{'addr'},
        );
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        chomp($error);
        $output .= " (".$error.")" if $error;
        $output .= "\n";
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
sub _error {
    return _debug($_[0],'error');
}

##############################################
sub _debug {
    my($data, $lvl) = @_;
    return unless defined $data;
    $lvl = 'DEBUG' unless defined $lvl;
    return if($Thruk::Utils::CLI::verbose <= 0 and uc($lvl) ne 'ERROR');
    if(ref $data) {
        return _debug(Dumper($data), $lvl);
    }
    my $time = scalar localtime();
    for my $line (split/\n/mx, $data) {
        if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
            print STDERR "[".$time."][".uc($lvl)."] ".$line."\n";
        } else {
            my $c = $Thruk::Utils::CLI::c;
            confess('no c') unless defined $c;
            if(uc($lvl) eq 'ERROR') { $c->log->error($line) }
            if(uc($lvl) eq 'INFO')  { $c->log->info($line)  }
            if(uc($lvl) eq 'DEBUG') { $c->log->debug($line) }
        }
    }
    return;
}

##############################################

=head1 EXAMPLES

there are some cli scripting examples in the examples subfolder of the source
package.

=head1 AUTHOR

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
