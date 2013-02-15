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
use Encode qw(encode_utf8);
use Thruk::Utils::IO;

$Thruk::Utils::CLI::verbose = 0;
$Thruk::Utils::CLI::c       = undef;

##############################################

=head1 METHODS

=head2 new

    new([ $options ])

 $options = {
    verbose         => 0-2,         # be more verbose
    credential      => 'secret',    # secret key when accessing remote instances
    remoteurl       => 'url',       # url where to access remote instances
    local           => 0|1,         # local requests only
 }

create CLI tool object

=cut
sub new {
    my($class, $options) = @_;
    $options->{'verbose'} = 1 unless defined $options->{'verbose'};
    $Thruk::Utils::CLI::verbose = $options->{'verbose'};
    my $self  = {
        'opt' => $options,
    };
    bless $self, $class;

    # set some env defaults
    $ENV{'THRUK_SRC'}       = 'CLI';
    $ENV{'REMOTE_USER'}     = $options->{'auth'} if defined $options->{'auth'};
    $ENV{'THRUK_BACKENDS'}  = join(',', @{$options->{'backends'}}) if(defined $options->{'backends'} and scalar @{$options->{'backends'}} > 0);
    $ENV{'THRUK_DEBUG'}     = $options->{'verbose'} if $options->{'verbose'} >= 3;
    $options->{'remoteurl_specified'} = 1;
    unless(defined $options->{'remoteurl'}) {
        $options->{'remoteurl_specified'} = 0;
        if(defined $ENV{'STARTURL'}) {
            $options->{'remoteurl'} = $ENV{'STARTURL'};
        }
        elsif(defined $ENV{'REMOTEURL'}) {
            $options->{'remoteurl'} = $ENV{'REMOTEURL'};
        }
        elsif(defined $ENV{'OMD_SITE'}) {
            $options->{'remoteurl'} = 'http://localhost/'.$ENV{'OMD_SITE'}.'/thruk/cgi-bin/remote.cgi';
        }
        else {
            $options->{'remoteurl'} = 'http://localhost/thruk/cgi-bin/remote.cgi';
        }
    }
    $options->{'remoteurl'} =~ s|/thruk/*$||mx;
    $options->{'remoteurl'} = $options->{'remoteurl'}.'/thruk/cgi-bin/remote.cgi' if $options->{'remoteurl'} !~ m/remote\.cgi$/mx;

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
    push @{$files}, 'thruk_local.conf';
    push @{$files}, $ENV{'CATALYST_CONFIG'}.'/thruk.conf'       if defined $ENV{'CATALYST_CONFIG'};
    push @{$files}, $ENV{'CATALYST_CONFIG'}.'/thruk_local.conf' if defined $ENV{'CATALYST_CONFIG'};
    my $var_path = './var';
    for my $file (reverse @{$files}) {
        next unless -f $file;
        open(my $fh, '<', $file) or die("open file $file failed (id: ".`id -a`.", pwd: ".`pwd`."): ".$!);
        while(my $line = <$fh>) {
            next unless $line =~ m/^\s*var_path\s+=\s*(.*)$/mx;
            $var_path = $1;
            last if $1;
        }
        Thruk::Utils::IO::close($fh, $file, 1);
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
    my($c, $failed);
    _debug("_run(): ".Dumper($self->{'opt'}));
    unless($self->{'opt'}->{'local'}) {
        ($result,$response) = $self->_request($self->{'opt'}->{'credential'}, $self->{'opt'}->{'remoteurl'}, $self->{'opt'});
        if(!defined $result and $self->{'opt'}->{'remoteurl_specified'}) {
            _error("requesting result from ".$self->{'opt'}->{'remoteurl'}." failed: ".Thruk::Utils::format_response_error($response));
            _debug(" -> ".Dumper($response));
            return 1;
        }
    }

    unless(defined $result) {
        $c = $self->get_c();
        if(!defined $c) {
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
    _trace("".$c->stats->report) if defined $c;
    return $result->{'rc'};
}

##############################################
sub _request {
    my($self, $credential, $url, $options) = @_;
    _debug("_request(".$url.")");
    Thruk::Utils::load_lwp_curl();
    _error($ENV{'THRUK_CURL_ERROR'}) if $ENV{'THRUK_CURL_ERROR'};
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
        my $data;
        eval {
            $data = decode_json($data_str);
        };
        if($@) {
            _error(" -> decode failed: ".Dumper($response));
            return(undef, $response);
        }
        _debug("   -> ".Dumper($response));
        _debug("   -> ".Dumper($data));
        return($data, $response);
    }

    _debug(" -> failed: ".Dumper($response));
    return(undef, $response);
}

##############################################
sub _dummy_c {
    my($self) = @_;
    _debug("_dummy_c()");
    delete local $ENV{'CATALYST_SERVER'} if defined $ENV{'CATALYST_SERVER'};
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
    $ENV{'NO_EXTERNAL_JOBS'} = 1;
    return _run_commands($c, $options, 'local');
}

##############################################
sub _from_fcgi {
    my($c, $data_str) = @_;
    confess('no data?') unless defined $data_str;
    $data_str = encode_utf8($data_str);
    my $data  = decode_json($data_str);
    confess('corrupt data?') unless ref $data eq 'HASH';
    $Thruk::Utils::CLI::verbose = $data->{'options'}->{'verbose'} if defined $data->{'options'}->{'verbose'};
    $Thruk::Utils::CLI::c       = $c;
    local $ENV{'THRUK_SRC'}     = 'CLI';

    # check credentials
    my $res = {};
    if(   !defined $c->config->{'secret_key'}
       or !defined $data->{'credential'}
       or $c->config->{'secret_key'} ne $data->{'credential'}) {
        my $msg = "authorization failed, ". $c->request->uri." does not accept this key.\n";
        if(!defined $data->{'credential'} or $data->{'credential'} eq '') {
            $msg = "authorization failed, no auth key specified for ". $c->request->uri."\n";
        }
        $res = {
            'version' => $c->config->{'version'},
            'branch'  => $c->config->{'branch'},
            'output'  => $msg,
            'rc'      => 1,
        };
    } else {
        $res = _run_commands($c, $data->{'options'}, 'fcgi');
    }
    my $res_json;
    eval {
        $res_json = encode_json($res);
    };
    if($@) {
        die("unable to encode to json: ".Dumper($res));
    }
    return $res_json;
}

##############################################
sub _run_commands {
    my($c, $opt, $src) = @_;

    if(defined $opt->{'auth'}) {
        Thruk::Utils::set_user($c, $opt->{'auth'});
    } elsif(defined $c->config->{'default_cli_user_name'}) {
        Thruk::Utils::set_user($c, $c->config->{'default_cli_user_name'});
    }

    unless(defined $c->stash->{'defaults_added'}) {
        Thruk::Action::AddDefaults::add_defaults(1, undef, "Thruk::Controller::remote", $c);
    }
    # set backends from options
    if(defined $opt->{'backends'} and scalar @{$opt->{'backends'}} > 0) {
        Thruk::Action::AddDefaults::_set_enabled_backends($c, $opt->{'backends'});
    }

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

    $c->stats->profile(begin => "_run_commands($action)");

    # raw query
    if($action eq 'raw') {
        die('no local raw requests!') if $src ne 'fcgi';
        ($data->{'output'}, $data->{'rc'}) = _cmd_raw($c, $opt);
    }

    # list backends
    elsif($action eq 'listbackends') {
        $data->{'output'} = _cmd_listbackends($c);
    }

    # list hosts
    elsif($action eq 'listhosts') {
        $data->{'output'} = _cmd_listhosts($c);
    }

    # list hostgroups
    elsif($action eq 'listhostgroups') {
        $data->{'output'} = _cmd_listhostgroups($c);
    }

    # request url
    elsif($action =~ /^url=(.*)$/mx) {
        $data->{'output'} = _cmd_url($c, $1);
    }

    # report or report mails
    elsif($action =~ /^report(\w*)=(.*)$/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_report($c, $1, $2);
    }

    # downtime?
    elsif($action =~ /^downtimetask=(.*)$/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_downtimetask($c, $1);
    }

    # install cron
    elsif($action eq 'installcron') {
        $data->{'output'} = _cmd_installcron($c);
    }

    # uninstall cron
    elsif($action eq 'uninstallcron') {
        $data->{'output'} = _cmd_uninstallcron($c);
    }

    # import mongodb logs
    elsif($action =~ /logcacheimport($|=(\d+))/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'import', $src, $2, $opt);
    }
    elsif($action eq 'logcacheupdate') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'update', $src);
    }
    elsif($action eq 'logcachestats') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'stats', $src);
    }
    elsif($action eq 'logcacheauthupdate') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'authupdate', $src);
    }
    elsif($action =~ /logcacheclean($|=(\d+))/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'clean', $src, $2);
    }
    else {
        $data->{'output'} = "FAILED - no such command: ".$action.". Run with --help to see a list of commands.\n";
        $data->{'rc'}     = 1;
    }

    $c->stats->profile(end => "_run_commands($action)");

    return $data;
}

##############################################
sub _cmd_listhosts {
    my($c) = @_;
    my $output = '';
    for my $host (@{$c->{'db'}->get_hosts(sort => {'ASC' => 'name'})}) {
        $output .= $host->{'name'}."\n";
    }

    # fix encoding
    utf8::decode($output);

    return encode_utf8($output);
}

##############################################
sub _cmd_listhostgroups {
    my($c) = @_;
    my $output = '';
    for my $group (@{$c->{'db'}->get_hostgroups(sort => {'ASC' => 'name'})}) {
        $output .= $group->{'name'}."\n";
    }

    # fix encoding
    utf8::decode($output);

    return encode_utf8($output);
}

##############################################
sub _cmd_listbackends {
    my($c) = @_;
    $c->{'db'}->enable_backends();
    eval {
        $c->{'db'}->get_processinfo();
    };
    _debug($@) if $@;
    Thruk::Action::AddDefaults::_set_possible_backends($c, {});
    my $output = '';
    $output .= sprintf("%-4s  %-7s  %-9s   %s\n", 'Def', 'Key', 'Name', 'Address');
    $output .= sprintf("-------------------------------------------------\n");
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        my $addr = $c->stash->{'backend_detail'}->{$key}->{'addr'};
        $addr    =~ s|/cgi-bin/remote.cgi$||mx;
        $output .= sprintf("%-4s %-8s %-10s %s",
                (!defined $peer->{'hidden'} or $peer->{'hidden'} == 0) ? ' * ' : '',
                $key,
                $c->stash->{'backend_detail'}->{$key}->{'name'},
                $addr,
        );
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        chomp($error);
        $output .= " (".$error.")" if $error;
        $output .= "\n";
    }
    $output .= sprintf("-------------------------------------------------\n");
    return $output;
}

##############################################
sub _request_url {
    my($c, $url) = @_;

    local $ENV{'REQUEST_URI'}      = $url;
    local $ENV{'SCRIPT_NAME'}      = $url;
          $ENV{'SCRIPT_NAME'}      =~ s/\?(.*)$//gmx;
    local $ENV{'QUERY_STRING'}     = $1 if defined $1;
    local $ENV{'SERVER_PROTOCOL'}  = 'HTTP/1.0'  unless defined $ENV{'SERVER_PROTOCOL'};
    local $ENV{'REQUEST_METHOD'}   = 'GET'       unless defined $ENV{'REQUEST_METHOD'};
    local $ENV{'HTTP_HOST'}        = '127.0.0.1' unless defined $ENV{'HTTP_HOST'};
    local $ENV{'REMOTE_ADDR'}      = '127.0.0.1' unless defined $ENV{'REMOTE_ADDR'};
    local $ENV{'SERVER_PORT'}      = '80'        unless defined $ENV{'SERVER_PORT'};
    local $ENV{'REMOTE_USER'}      = $c->stash->{'remote_user'} if(!$ENV{'REMOTE_USER'} and $c->stash->{'remote_user'});
    local $ENV{'HTTP_RESULT'}      = {};

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
        while($result->{'code'} == 302 or $result->{'result'} =~ m/thruk:\ waiting\ for\ job\ $jobid/mx) {
            my $sleep = 0.1 * $x;
            $sleep = 1 if $x > 10;
            sleep($sleep);
            $url = $result->{'headers'}->{'Location'} if defined $result->{'headers'}->{'Location'};
            local $ENV{'REQUEST_URI'}      = $url;
            local $ENV{'SCRIPT_NAME'}      = $url;
                  $ENV{'SCRIPT_NAME'}      =~ s/\?(.*)$//gmx;
            local $ENV{'QUERY_STRING'}     = $1 if defined $1;
            Catalyst::ScriptRunner->run('Thruk', 'Thrukembedded');
            $result = $ENV{'HTTP_RESULT'};
            $x++;
        }
    }

    if($result->{'code'} == 302
          and defined $result->{'headers'}->{'Set-Cookie'}
          and $result->{'headers'}->{'Set-Cookie'} =~ m/^thruk_message=(.*)%7E%7E(.*);\ path=/mx
    ) {
        my $txt = uri_unescape($2);
        my $msg = '';
        if($1 eq 'success_message') {
            $msg = 'OK';
        } else {
            $msg = 'FAILED';
        }
        $txt = $msg.' - '.$txt."\n";
        return($result->{'code'}, $result, $txt) if wantarray;
        return $txt;
    }
    elsif($result->{'code'} == 500) {
        my $txt = 'request failed: '.$result->{'code'}." - internal error, please consult your logfiles\n";
        _debug(Dumper($result));
        return($result->{'code'}, $result, $txt) if wantarray;
        return $txt;
    }
    elsif($result->{'code'} != 200) {
        my $txt = 'request failed: '.$result->{'code'}." - ".$result->{'result'}."\n";
        _debug(Dumper($result));
        return($result->{'code'}, $result, $txt) if defined wantarray;
        return $txt;
    }

    return($result->{'code'}, $result) if wantarray;
    return $result->{'result'};
}

##############################################
sub _error {
    return _debug($_[0],'error');
}

##############################################
sub _info {
    return _debug($_[0],'info');
}

##############################################
sub _trace {
    return _debug($_[0],'trace');
}

##############################################
sub _debug {
    my($data, $lvl) = @_;
    return unless defined $data;
    $lvl = 'DEBUG' unless defined $lvl;
    return if($Thruk::Utils::CLI::verbose < 3 and uc($lvl) eq 'TRACE');
    return if($Thruk::Utils::CLI::verbose < 2 and uc($lvl) eq 'DEBUG');
    return if($Thruk::Utils::CLI::verbose < 1 and uc($lvl) eq 'INFO');
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
sub _cmd_installcron {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_installcron()");
    Thruk::Utils::switch_realuser($c);
    Thruk::Controller::extinfo->_update_cron_file($c);
    if($c->config->{'use_feature_reports'}) {
        Thruk::Utils::Reports::update_cron_file($c);
    }
    $c->stats->profile(end => "_cmd_installcron()");
    return "updated cron entries\n";
}

##############################################
sub _cmd_uninstallcron {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_uninstallcron()");
    Thruk::Utils::switch_realuser($c);
    Thruk::Utils::update_cron_file($c);
    $c->stats->profile(end => "_cmd_uninstallcron()");
    return "cron entries removed\n";
}

##############################################
sub _cmd_report {
    my($c, $mail, $nr) = @_;

    $c->stats->profile(begin => "_cmd_report()");

    my($output, $rc);
    eval {
        require Thruk::Utils::Reports;
    };
    if($@) {
        return("reports plugin is not enabled.\n", 1)
    }
    if($mail eq 'mail') {
        if(Thruk::Utils::Reports::report_send($c, $nr)) {
            $output = "mail send successfully\n";
        } else {
            return("cannot send mail\n", 1)
        }
    } else {
        my $report_file = Thruk::Utils::Reports::generate_report($c, $nr);
        if(defined $report_file and -f $report_file) {
            $output = read_file($report_file);
        } else {
            my $errors = read_file($c->config->{'tmp_path'}.'/reports/'.$nr.'.log');
            return("generating report failed:\n".$errors, 1)
        }
    }

    $c->stats->profile(end => "_cmd_report()");
    return($output, 0)
}

##############################################
sub _cmd_downtimetask {
    my($c, $file) = @_;
    $c->stats->profile(begin => "_cmd_downtimetask()");

    # do auth stuff
    Thruk::Utils::set_user($c, '(cron)') unless $c->user_exists;

    my $downtime   = Thruk::Utils::read_data_file($file);
    my $default_rd = Thruk::Utils::_get_default_recurring_downtime($c);
    for my $key (keys %{$default_rd}) {
        $downtime->{$key} = $default_rd->{$key} unless defined $downtime->{$key};
    }

    my $start    = time();
    my $end      = $start + ($downtime->{'duration'}*60);
    my $hours    = 0;
    my $minutes  = 0;
    my $flexible = '';
    if($downtime->{'fixed'} == 0) {
        $flexible = ' flexible';
        $end      = $start + $downtime->{'flex_range'}*60;
        $hours    = int($downtime->{'duration'} / 60);
        $minutes  = $downtime->{'duration'}%60;
    }

    my $output     = '';
    # convert to normal url request
    my $url = sprintf('/thruk/cgi-bin/cmd.cgi?cmd_mod=2&cmd_typ=%d&host=%s&com_data=%s&com_author=%s&trigger=0&start_time=%s&end_time=%s&fixed=%s&hours=%s&minutes=%s&backend=%s%s%s',
                      $downtime->{'service'} ? 56 : 55,
                      uri_escape($downtime->{'host'}),
                      uri_escape($downtime->{'comment'}),
                      '(cron)',
                      uri_escape(Thruk::Utils::format_date($start, '%Y-%m-%d %H:%M:%S')),
                      uri_escape(Thruk::Utils::format_date($end, '%Y-%m-%d %H:%M:%S')),
                      $downtime->{'fixed'},
                      $hours,
                      $minutes,
                      ref $downtime->{'backends'} eq 'ARRAY' ? join(',', @{$downtime->{'backends'}}) : $downtime->{'backends'},
                      defined $downtime->{'childoptions'} ? '&childoptions='.$downtime->{'childoptions'} : '',
                      $downtime->{'service'} ? '&service='.uri_escape($downtime->{'service'}) : '',
                     );
    my $old = $c->config->{'cgi_cfg'}->{'lock_author_names'};
    $c->config->{'cgi_cfg'}->{'lock_author_names'} = 0;
    my @res = _request_url($c, $url);
    $c->config->{'cgi_cfg'}->{'lock_author_names'} = $old;
    return("failed\n", 1) unless $res[0] == 200; # error is already printed

    if($downtime->{'service'}) {
        $output = 'scheduled'.$flexible.' downtime for service \''.$downtime->{'service'}.'\' on host \''.$downtime->{'host'}.'\'';
    } else {
        $output = 'scheduled'.$flexible.' downtime for host \''.$downtime->{'host'}.'\'';
    }
    $output .= " (duration ".Thruk::Utils::Filter::duration($downtime->{'duration'}*60).")\n";

    $c->stats->profile(end => "_cmd_downtimetask()");
    return($output, 0);
}

##############################################
sub _cmd_url {
    my($c, $url) = @_;
    $c->stats->profile(begin => "_cmd_url()");

    if($url =~ m|^\w+\.cgi|gmx) {
        $url = '/thruk/cgi-bin/'.$url;
    }
    my $output = _request_url($c, $url);

    $c->stats->profile(end => "_cmd_url()");
    return $output;
}

##############################################
sub _cmd_import_logs {
    my($c, $mode, $src, $blocksize, $opt) = @_;
    $c->stats->profile(begin => "_cmd_import_logs()");

    if($src ne 'local' and $mode eq 'import') {
        return("ERROR - please run the initial import with --local\n", 1);
    }
    if($mode eq 'import' and !$opt->{'yes'}) {
        print "import removes current data and imports all logfile data, continue? [n]: ";
        my $buf;
        sysread STDIN, $buf, 1;
        if($buf !~ m/^(y|j)/mxi) {
            return("canceled\n", 1);
        }
    }

    my $verbose = 0;
    $verbose = 1 if $src eq 'local';

    eval {
        require Thruk::Backend::Provider::Mongodb;
        Thruk::Backend::Provider::Mongodb->import;
    };
    if($@) {
        return("FAILED - failed to load mongodb support: ".$@."\n", 1);
    }

    if(!defined $c->config->{'logcache'}) {
        return("FAILED - logcache is not enabled\n", 1);
    }

    if($mode eq 'stats') {
        my $stats = Thruk::Backend::Provider::Mongodb->_log_stats($c);
        $c->stats->profile(end => "_cmd_import_logs()");
        return($stats."\n", 0);
    } else {
        my $t1 = time();
        my($backend_count, $log_count) = Thruk::Backend::Provider::Mongodb->_import_logs($c, $mode, $verbose, undef, $blocksize);
        my $t2 = time();
        $c->stats->profile(end => "_cmd_import_logs()");
        my $action = "imported";
        $action    = "updated" if $mode eq 'authupdate';
        $action    = "removed" if $mode eq 'clean';
        return('OK - '.$action.' '.$log_count.' log items from '.$backend_count.' site'.($backend_count == 1 ? '' : 's')." successfully in ".($t2-$t1)."s\n", 0);
    }
}

##########################################################
sub _cmd_configtool {
    my($c, $peerkey, $opt) = @_;
    my $res        = undef;
    my $last_error = undef;
    my $peer       = $Thruk::peers->{$peerkey};
    $c->stash->{'param_backend'} = $peerkey;

    if(!Thruk::Utils::Conf::set_object_model($c)) {
        return("failed to set objects model", 1);
    }
    # outgoing file sync
    elsif($opt->{'args'}->{'sub'} eq 'syncfiles') {
        $c->{'obj_db'}->check_files_changed();
        my $transfer    = {};
        my $remotefiles = $opt->{'args'}->{'args'}->{'files'};
        for my $f (@{$c->{'obj_db'}->{'files'}}) {
            $transfer->{$f->{'path'}} = { mtime => $f->{'mtime'} };
            if(!defined $remotefiles->{$f->{'path'}}->{'mtime'}
               or $f->{'mtime'} != $remotefiles->{$f->{'path'}}->{'mtime'}) {
                $transfer->{$f->{'path'}}->{'content'} = read_file($f->{'path'});
            }
        }
        $res = $transfer;
    }
    # some settings
    elsif($opt->{'args'}->{'sub'} eq 'configsettings') {
        $res = {
            'files_root' => $c->{'obj_db'}->get_files_root(),
        };
    }
    # run config check
    elsif($opt->{'args'}->{'sub'} eq 'configcheck') {
        my $jobid = Thruk::Utils::External::cmd($c, { cmd => $c->{'obj_db'}->{'config'}->{'obj_check_cmd'}." 2>&1", 'background' => 1 });
        $res = 'jobid:'.$jobid;
    }
    # reload configuration
    elsif($opt->{'args'}->{'sub'} eq 'configreload') {
        my $jobid = Thruk::Utils::External::cmd($c, { cmd => $c->{'obj_db'}->{'config'}->{'obj_reload_cmd'}." 2>&1", 'background' => 1 });
        $res = 'jobid:'.$jobid;
    }
    # save incoming config changes
    elsif($opt->{'args'}->{'sub'} eq 'configsave') {
        my $changed = $opt->{'args'}->{'args'}->{'changed'};
        # changed and new files
        for my $f (@{$changed}) {
            my($path,$content, $mtime) = @{$f};
            next if $path =~ m|/../|gmx; # no relative paths
            my $file = $c->{'obj_db'}->get_file_by_path($path);
            if($file and !$file->readonly()) {
                # update file
                Thruk::Utils::IO::write($path, $content, $mtime);
            } elsif(!$file) {
                # new file
                my $filesroot = $c->{'obj_db'}->get_files_root();
                if($path =~ m/^\Q$filesroot\E/mx) {
                    $file = Monitoring::Config::File->new($path, $c->{'obj_db'}->{'config'}->{'obj_readonly'}, $c->{'obj_db'}->{'coretype'});
                    if(defined $file and !$file->readonly()) {
                        Thruk::Utils::IO::write($path, $content, $mtime);
                    }
                }
            }
        }
        # deleted files
        my $deleted = $opt->{'args'}->{'args'}->{'deleted'};
        for my $f (@{$deleted}) {
            my $file = $c->{'obj_db'}->get_file_by_path($f);
            if($file and !$file->readonly()) {
                unlink($f);
            }
        }
        $res = "saved";
    } else {
        return("unknown configtool command", 1);
    }
    return([undef, 1, $res, $last_error], 0);
}

##############################################
sub _cmd_raw {
    my($c, $opt) = @_;
    my $function  = $opt->{'sub'};

    unless(defined $c->stash->{'defaults_added'}) {
        Thruk::Action::AddDefaults::add_defaults(1, undef, "Thruk::Controller::remote", $c);
    }
    my @keys = keys %{$Thruk::peers};
    my $key = $keys[0];
    # do we have a hint about remote peer?
    if($opt->{'remote_name'}) {
        my $peer = $c->{'db'}->get_peer_by_name($opt->{'remote_name'});
        die('no such backend: '.$opt->{'remote_name'}) unless defined $peer;
        $key = $peer->peer_key();
    } else {
        $key = $keys[0];
    }
    die("no backends...") unless $key;

    if($function eq 'get_logs' or $function eq '_get_logs_start_end') {
        $c->{'db'}->renew_logcache($c);
    }

    # config tool commands
    elsif($function eq 'configtool') {
        return _cmd_configtool($c, $key, $opt);
    }

    # result for external job
    elsif($function eq 'job') {
        return _cmd_ext_job($c, $key, $opt);
    }

    my @res = Thruk::Backend::Manager::_do_on_peer($key, $function, $opt->{'args'});
    my $res = shift @res;

    # add proxy version to processinfo
    if($function eq 'get_processinfo' and defined $res and ref $res eq 'ARRAY' and defined $res->[2] and ref $res->[2] eq 'HASH') {
        $res->[2]->{$key}->{'data_source_version'} .= ' (via Thruk '.$c->config->{'version'}.($c->config->{'branch'}? '~'.$c->config->{'branch'} : '').')';

        # add config tool settings
        if($Thruk::peers->{$key}->{'config'}->{'configtool'}) {
            $res->[2]->{$key}->{'configtool'} = {
                'obj_readonly'   => $Thruk::peers->{$key}->{'config'}->{'configtool'}->{'obj_readonly'},
                'obj_check_cmd'  => exists $Thruk::peers->{$key}->{'config'}->{'configtool'}->{'obj_check_cmd'},
                'obj_reload_cmd' => exists $Thruk::peers->{$key}->{'config'}->{'configtool'}->{'obj_reload_cmd'},
            };
        }
    }

    # remove useless mongodb _id if using logcache
    if($function eq 'get_logs' and $c->config->{'logcache'} and defined $res and ref $res eq 'ARRAY' and defined $res->[2] and ref $res->[2] eq 'ARRAY') {
        for (@{$res->[2]}) { delete $_->{'_id'} }
    }

    return($res, 0);
}

##############################################
sub _cmd_ext_job {
    my($c, $key, $opt) = @_;
    my $jobid       = $opt->{'args'};
    my $res         = "";
    my $last_error  = "";
    if(Thruk::Utils::External::is_running($c, $jobid, 1)) {
        $res = "jobid:".$jobid.":0";
    }
    else {
        my($out,$err,$time,$dir,$stash,$rc) = Thruk::Utils::External::get_result($c, $jobid, 1);
        $res = {
            'out'   => $out,
            'err'   => $err,
            'time'  => $time,
            'dir'   => $dir,
            'rc'    => $rc,
        };
    }
    return([undef, 1, $res, $last_error], 0);
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
