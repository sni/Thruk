package Thruk::Utils::External;

=head1 NAME

Thruk::Utils::External - Utilities to run background processes

=head1 DESCRIPTION

Utilities to run background processes

=cut

use strict;
use warnings;
use Carp qw/confess/;
use Data::Dumper qw/Dumper/;
use Time::HiRes ();
use File::Slurp qw/read_file/;
use Storable qw/store retrieve/;
use POSIX ":sys_wait_h";
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

  cmd($c, {
            cmd          => "command line to execute",
            allow        => all|user,
            wait_message => "display message while running the job"
            forward      => "forward on success"
            background   => "return $jobid if set, or redirect otherwise"
            nofork       => "don't fork"
            no_shell     => "wrap command in a shell unless no_shell is set"
            env          => hash with extra environment variables
            show_output  => show console with output
        }
    );

run command in an external process

=cut
sub cmd {
    my($c, $conf) = @_;

    my $cmd = $c->config->{'thruk_shell'}." '".$conf->{'cmd'}."'";
    if($conf->{'no_shell'}) {
        $cmd = $conf->{'cmd'};
    }

    # set additional environment variables but keep local env
    local %ENV = (%{$conf->{'env'}}, %ENV) if $conf->{'env'};

    if(   $c->config->{'no_external_job_forks'}
       or $conf->{'nofork'}
       or exists $c->req->parameters->{'noexternalforks'}
       or ($c->stash->{job_id} && !$conf->{'background'}) # do not cascade jobs unless they should be forked to background
    ) {
        # $rc, $out
        my(undef, $out) = Thruk::Utils::IO::cmd($c, $cmd);
        return _finished_job_page($c, $c->stash, undef, $out);
    }

    my($id,$dir) = init_external($c);
    return unless $id;

    my $pid = fork();
    die "fork() failed: $!" unless defined $pid;

    if($pid) {
        return do_parent_stuff($c, $dir, $pid, $id, $conf);
    } else {
        do_child_stuff($c, $dir, $id);

        $cmd = $cmd.'; echo $? > '.$dir."/rc" unless $conf->{'no_shell'};

        exec($cmd) or exit(1); # just to be sure
    }
}


##############################################

=head2 perl

  perl($c, {
            expr         => "perl expression to execute",
            allow        => all|user,
            wait_message => "display message while running the job"
            forward      => "forward on success"
            backends     => "list of selected backends (keys)"
            nofork       => "don't fork"
            background   => "return $jobid if set, or redirect otherwise"
            clean        => "remove job after displaying it if true"
            render       => "set to a true value to render page immediatly"
            show_output  => show console with output
        }
    )

run perl expression in an external process

=cut
sub perl {
    my($c, $conf) = @_;

    if(   $c->config->{'no_external_job_forks'}
       or $conf->{'nofork'}
       or exists $c->req->parameters->{'noexternalforks'}
       or ($c->stash->{job_id} && !$conf->{'background'}) # do not cascade jobs unless they should be forked to background
    ) {
        if(defined $conf->{'backends'}) {
            $c->{'db'}->disable_backends();
            $c->{'db'}->enable_backends($conf->{'backends'});
        }
        ## no critic
        my $rc = eval($conf->{'expr'});
        ## use critic
        die($@) if $@;
        _finished_job_page($c, $c->stash) if !$c->stash->{job_id}; # breaks cascading jobs, ex.: xls export on showlog
        return $rc;
    }

    $c->stash->{job_conf} = $conf;

    my ($id,$dir) = init_external($c);
    return unless $id;

    my $pid = fork();
    die "fork() failed: $!" unless defined $pid;

    if($pid) {
        return do_parent_stuff($c, $dir, $pid, $id, $conf);
    }

    if(defined $conf->{'backends'}) {
        $c->{'db'}->disable_backends();
        $c->{'db'}->enable_backends($conf->{'backends'});
    }

    my $err;
    eval {
        do_child_stuff($c, $dir, $id);
        $c->stats->profile(begin => 'External::perl');

        do {
            ## no critic
            my $rc = eval($conf->{'expr'});
            ## use critic

            $err = $@;
            if($err) {
                undef $rc;
                if($c->stash->{'last_redirect_to'} && $c->{'detached'}) {
                    open(my $fh, '>', $dir."/forward");
                    if(ref $c->stash->{'last_redirect_to'}) {
                        confess("invalid redirect url: ".Dumper($c->stash->{'last_redirect_to'}));
                    }
                    print $fh $c->stash->{'last_redirect_to'},"\n";
                    Thruk::Utils::IO::close($fh, $dir."/forward");
                    $err = undef;
                    $rc  = 0;
                }
            }

            open(my $fh, '>', $dir."/rc");
            # invert rc to match exit code style
            print $fh ($rc ? 0 : 1);
            Thruk::Utils::IO::close($fh, $dir."/rc");
            open($fh, '>>', $dir."/perl_res");
            if(defined $rc && ref $rc eq '') {
                print $fh $rc;
            }
            Thruk::Utils::IO::close($fh, $dir."/perl_res");
            CORE::close(STDERR);
            CORE::close(STDOUT);
        };

        if($conf->{'render'} && $c->stash->{'template'} && !$c->{'rendered'}) {
            local $c->stash->{'job_conf'}->{'clean'} = undef;
            _finished_job_page($c, $c->stash);
            Thruk::Action::AddDefaults::end($c);
            Thruk::Views::ToolkitRenderer::render_tt($c);
            my $res = $c->res->finalize;
            Thruk::finalize_request($c, $res);
            Thruk::Utils::IO::write($dir."/result.dat", $res->[2]->[0]);
            $c->stash->{'file_name'} = "result.dat";
            $c->stash->{'file_name_meta'} = {
                code    => $res->[0],
                headers => $res->[1],
            };
        }

        # save stash
        _clean_unstorable_refs($c->stash);
        store(\%{$c->stash}, $dir."/stash");

        if(Thruk->debug) {
            open(my $fh, '>', $dir."/stash.dump");
            print $fh Dumper($c->stash);
            CORE::close($fh);
        }
        die($err) if $err; # die again after cleanup
    };
    $err = $@ unless $err;
    $c->stats->profile(end => 'External::perl');
    save_profile($c, $dir);
    if($err) {
        eval {
            open(my $fh, '>>', $dir."/stderr");
            print $fh "ERROR: perl eval failed:\n";
            print $fh $err;
            Thruk::Utils::IO::close($fh, $dir."/stderr");
        };
        # calling _exit skips running END blocks
        exit(1);
    }
    exit(0);
}

##############################################

=head2 render_page_in_background

  render_page_in_background($c)

return true if page will be rendered in background.
will return false if page should continue to render normally

=cut
sub render_page_in_background {
    my($c) = @_;

    # render page if running as a background job
    return if $ENV{'THRUK_JOB_DIR'};

    # render page if not running inside a webserver
    return if(Thruk->mode ne 'FASTCGI' && Thruk->mode ne 'DEVSERVER');

    return if exists $c->req->parameters->{'noexternalforks'};
    return if $ENV{'THRUK_NO_BACKGROUND_PAGES'};

    my @caller = caller(1);
    return(
        Thruk::Utils::External::perl($c, { expr    => $caller[3].'($c)',
                                           message => 'please stand by while page is beeing rendered...',
                                           clean   => 1,
                                           render  => 1,
    }));
}

##############################################

=head2 is_running

  is_running($c, $id, [$nouser])

return true if process is still running

=cut
sub is_running {
    my($c, $id, $nouser) = @_;
    confess("got no id") unless $id;

    my $dir = $c->config->{'var_path'}."/jobs/".$id;
    if(!$nouser && -f $dir."/user" ) {
        my $user = read_file($dir."/user");
        chomp($user);
        confess('no remote_user') unless defined $c->stash->{'remote_user'};
        return unless $user eq $c->stash->{'remote_user'};
    }

    return _is_running($c, $dir);
}


##############################################

=head2 cancel

  cancel($c, $id, [$nouser])

returns true if successfully canceled

=cut
sub cancel {
    my($c, $id, $nouser) = @_;
    confess("got no id") unless $id;

    my $dir = $c->config->{'var_path'}."/jobs/".$id;
    if(!$nouser && -f $dir."/user" ) {
        my $user = read_file($dir."/user");
        chomp($user);
        confess('no remote_user') unless defined $c->stash->{'remote_user'};
        return unless $user eq $c->stash->{'remote_user'};
    }

    my $pidfile = $dir."/pid";
    if(-f $pidfile) {
        # is it running on this node?
        if(-s $dir."/hostname") {
            my @hosts = split(/\n/mx, read_file($dir."/hostname"));
            if($hosts[0] ne $Thruk::NODE_ID) {
                $c->cluster->run_cluster($hosts[0], 'Thruk::Utils::External::cancel', [$c, $id, $nouser]);
                return _is_running($c, $dir);
            }
        }

        my $pid = read_file($pidfile);
        chomp($pid);
        update_status($dir, 99.9, 'canceled');
        CORE::kill(15, $pid);
        CORE::kill(-15, $pid);
        sleep(1);
        CORE::kill(2, $pid);
        CORE::kill(-2, $pid);
        sleep(1);
        CORE::kill(9, $pid);
        CORE::kill(-9, $pid);
    }
    return _is_running($c, $dir);
}


##############################################

=head2 read_job

  read_job($c, $id)

return status of a job

=cut
sub read_job {
    my($c, $id) = @_;

    my($is_running,$time,$percent,$message,$forward,$remaining,$user,$show_output) = get_status($c, $id);
    return unless defined $time;

    my $job_dir = $c->config->{'var_path'}.'/jobs/'.$id;

    my $start = -e $job_dir.'/start'    ? (stat($job_dir.'/start'))[9] : 0;
    my $end   = -e $job_dir.'/rc'       ? (stat($job_dir.'/rc'))[9]    : 0;
    my $rc    = -e $job_dir.'/rc'       ? read_file($job_dir.'/rc')  : '';
    my $res   = -e $job_dir.'/perl_res' ? read_file($job_dir.'/perl_res')  : '';
    my $out   = -e $job_dir.'/stdout'   ? read_file($job_dir.'/stdout')  : '';
    my $err   = -e $job_dir.'/stderr'   ? read_file($job_dir.'/stderr')  : '';
    my $host  = -e $job_dir.'/hostname' ? read_file($job_dir.'/hostname')  : '';
    my $cmd   = -e $job_dir.'/start'    ? read_file($job_dir.'/start')  : '';
    my $pid   = -e $job_dir.'/pid'      ? read_file($job_dir.'/pid')  : '';
    if($cmd) {
        $cmd =~ s%^\d+\n%%gmx;
        $cmd =~ s%^\$VAR1\s*=\s*%%gmx;
        $cmd =~ s%\n$%%gmx;
    }
    if($rc !~ m/^\d*$/mx) { $rc = -1; }
    my($hostid, $hostname) = split(/\n/mx, $host);

    $remaining = -1 unless defined $remaining;
    my $job   = {
        'id'         => $id,
        'pid'        => $pid,
        'user'       => $user,
        'host_id'    => $hostid // "",
        'host_name'  => $hostname // "",
        'cmd'        => $cmd,
        'rc'         => $rc // '',
        'perl_res'   => $res // '',
        'stdout'     => $out // '',
        'stderr'     => $err // '',
        'is_running' => 0+$is_running,
        'time'       => 0+$time,
        'start'      => 0+($start || 0),
        'end'        => 0+($end || 0),
        'percent'    => 0+$percent,
        'message'    => $message // '',
        'forward'    => $forward // '',
        'show_output'=> $show_output // 0,
        'remaining'  => 0+$remaining,
    };

    return($job);
}

##############################################

=head2 get_status

  get_status($c, $id)

return status of a job

=cut
sub get_status {
    my($c, $id) = @_;
    confess("got no id") unless $id;

    my $dir = $c->config->{'var_path'}."/jobs/".$id;
    return unless -d $dir;

    # reap pending zombies
    waitpid(-1, WNOHANG);

    my $user = '';
    if( -f $dir."/user" ) {
        $user = read_file($dir."/user");
        chomp($user);
        if(!defined $c->stash->{'remote_user'} || $user ne $c->stash->{'remote_user'}) {
            if(!$c->check_user_roles('admin')) {
                return;
            }
        }
    }

    my $is_running = _is_running($c, $dir);
    my $percent    = 0;
    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start      = stat($dir.'/start');
    if(!defined $start[9]) {
        return($is_running,0,$percent,"not started",undef,undef,$user);
    }
    my $time       = time() - $start[9];
    if($is_running == 0) {
        $percent = 100;
        my @end  = stat($dir."/stdout");
        $end[9]  = time() unless defined $end[9];
        $time    = $end[9] - $start[9];
    } elsif(-f $dir."/status") {
        $percent = read_file($dir."/status");
        chomp($percent);
    }

    my $message;
    if(-f $dir."/message") {
        $message = read_file($dir."/message");
        chomp($message);
    }
    my $forward;
    if(-f $dir."/forward") {
        $forward = read_file($dir."/forward");
        chomp($forward);
    }

    my $show_output;
    if(-f $dir."/show_output") {
        $show_output = 1;
    }

    my $remaining;
    if($percent =~ m/^([\d\.]+)\s+([\d\.\-]+)\s+(.*)$/mx) {
        $percent   = $1;
        $remaining = $2;
        $message   = $3;
    }
    if($percent eq "") { $percent = 0; }

    return($is_running,$time,$percent,$message,$forward,$remaining,$user,$show_output);
}


##############################################

=head2 get_json_status

  get_json_status($c, $id)

return json status of a job

=cut
sub get_json_status {
    my($c, $id) = @_;
    confess("got no id") unless $id;

    my $job = read_job($c, $id);
    return unless $job;

    my $json = {};
    for my $key (qw/is_running time percent message forward remaining start end/) {
        $json->{$key} = $job->{$key};
    }
    if($job->{'show_output'}) {
        $json->{'output'} = $job->{'stdout'}.$job->{'stderr'};
    }

    return $c->render(json => $json);
}


##############################################

=head2 get_result

  get_result($c, $id, [$nouser])

return result of a job

=cut
sub get_result {
    my($c, $id, $nouser) = @_;
    confess("got no id") unless $id;

    my $dir = $c->config->{'var_path'}."/jobs/".$id;
    if(!$nouser && -f $dir."/user") {
        my $user = read_file($dir."/user");
        chomp($user);
        confess('no remote_user') unless defined $c->stash->{'remote_user'};
        return unless $user eq $c->stash->{'remote_user'};
    }

    if(!-d $dir) {
        return('', 'no such job: '.$id, 0, $dir, undef, 1, undef);
    }

    my($out, $err) = ('', '');
    $out = read_file($dir."/stdout") if -f $dir."/stdout";
    $err = read_file($dir."/stderr") if -f $dir."/stderr";

    # remove known harmless errors
    $err =~ s|Warning:.*?during\ global\ destruction\.\n||gmx;
    $err =~ s|^.*DEBUG.*$||gmx;
    $err =~ s|^\s*\n||gmx;

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = stat($dir.'/start');
    my @end;
    my $retries = 10;
    while($retries > 0) {
        if(-f $dir."/stdout") {
            @end = stat($dir."/stdout");
        } elsif(-f $dir."/stderr") {
            @end = stat($dir."/stderr");
        } elsif(-f $dir."/rc") {
            @end = stat($dir."/rc");
        }
        if(!defined $end[9]) {
            sleep(1);
            $retries--;
        } else {
            last;
        }
    }
    if(!defined $end[9]) {
        $end[9] = time();
        $err    = 'job was killed';
        _error('killed job: '.$dir);
        my $folder = Thruk::Utils::IO::cmd("ls -la $dir");
        _error($folder);
    }

    my $time = $end[9] - $start[9];

    my $stash;
    $stash = retrieve($dir."/stash") if -f $dir."/stash";

    my $rc = -1;
    $rc = read_file($dir."/rc") if -f $dir."/rc";
    chomp($rc);

    my $perl_res;
    if(-f $dir."/perl_res") {
        $perl_res = read_file($dir."/perl_res");
        chomp($perl_res);
    }

    my $profiles = [];
    for my $p (glob($dir."/profile.log*")) {
        my $text = read_file($p);
        chomp($text);
        my $htmlfile = $p;
        $htmlfile =~ s/\.log\./.html./gmx;
        if(-e $htmlfile) {
            my $html = read_file($htmlfile);
            push @{$profiles}, [$html, $text];
        } else {
            push @{$profiles}, $text;
        }
    }

    return($out,$err,$time,$dir,$stash,$rc,$profiles,$start[9],$end[9],$perl_res);
}

##############################################

=head2 job_page

  job_page($c)

process job result page

=cut
sub job_page {
    my($c) = @_;

    my $job    = $c->req->parameters->{'job'};
    my $json   = $c->req->parameters->{'json'}   || 0;
    my $cancel = $c->req->parameters->{'cancel'} || 0;
    $c->stash->{no_auto_reload} = 1;
    return $c->detach('/error/index/22') unless defined $job;
    if($json) {
        return get_json_status($c, $job);
    }

    my($is_running,$time,$percent,$message,$forward,$remaining,$user,$show_output) = get_status($c, $job);
    return $c->detach('/error/index/22') unless defined $is_running;

    if($cancel) {
        cancel($c, $job);
        return;
    }

    if(!$show_output) {
        # try to directly serve the request if it takes less than 3 seconds
        $c->stats->profile(begin => "job_page waiting for job: ".$job);
        while($is_running and $time < 3) {
            Time::HiRes::sleep(0.1) if $time <  1;
            Time::HiRes::sleep(0.3) if $time >= 1;
            ($is_running,$time,$percent,$message,$forward) = get_status($c, $job);
        }
        $c->stats->profile(end => "job_page waiting for job: ".$job);
    }

    # job still running?
    if($is_running) {
        $c->stash->{title}                 = $c->config->{'name'};
        $c->stash->{job_id}                = $job;
        $c->stash->{job_time}              = $time;
        $c->stash->{job_percent}           = $percent || 0;
        $c->stash->{job_message}           = $message || "";
        $c->stash->{infoBoxTitle}          = 'please stand by';
        $c->stash->{hide_backends_chooser} = 1;
        $c->stash->{'has_jquery_ui'}       = 1;
        $c->stash->{show_output}           = $show_output || 0;
        $c->stash->{template}             = 'waiting_for_job.tt';
    } else {
        # job finished, display result
        my($out,$err,$time,$dir,$stash,$rc,$profiles) = get_result($c, $job);
        return $c->detach('/error/index/22') unless defined $dir;
        push @{$c->stash->{'profile'}}, @{$profiles} if $profiles;
        if(defined $stash and defined $stash->{'original_url'}) { $c->stash->{'original_url'} = $stash->{'original_url'} }
        if((defined $err && $err ne '') && (!defined $rc || $rc != 0 || (!$out && !$stash))) {
            $c->error($err);
            _error($err);
            return $c->detach('/error/index/23');
        }
        delete($stash->{'all_in_one_css'});
        return _finished_job_page($c, $stash, $forward, $out);
    }

    return;
}


##############################################

=head2 update_status

  update_status($dir, $percent, $status, $remaining_seconds)

update status for this job

=cut
sub update_status {
    my($dir, $percent, $status, $remaining_seconds) = @_;
    $remaining_seconds = -1 unless defined $remaining_seconds;
    my $statusfile = $dir."/status";
    my $text = $percent." ".$remaining_seconds." ".$status;
    _debug("update_status: ".$text);
    open(my $fh, '>', $statusfile) or die("cannot write status $statusfile: $!");
    print $fh $text, "\n";
    Thruk::Utils::IO::close($fh, $statusfile);
    return;
}

##############################################

=head2 save_profile

  save_profile($c, $dir)

save profile to profile.log.<nr> of this job

=cut
sub save_profile {
    my($c, $dir) = @_;

    my $nr   = 0;
    my $base = $dir.'/profile.log';
    while(-e $base.".".$nr) {
        $nr++;
    }

    $c->stats->profile(comment => 'total time waited on backends:  '.sprintf('%.2fs', $c->stash->{'total_backend_waited'})) if $c->stash->{'total_backend_waited'};
    $c->stats->profile(comment => 'total time waited on rendering: '.sprintf('%.2fs', $c->stash->{'total_render_waited'}))  if $c->stash->{'total_render_waited'};

    my $file = $dir.'/profile.log.'.$nr;
    open(my $fh, '>>', $file) or die("cannot write $file: $!");
    eval {
        print $fh $c->stats->report(),"\n";
    };
    print $fh $@,"\n" if $@;
    CORE::close($fh);

    $file = $dir.'/profile.html.'.$nr;
    open($fh, '>>', $file) or die("cannot write $file: $!");
    eval {
        print $fh $c->stats->report_html();
    };
    print $fh $@,"\n" if $@;
    CORE::close($fh);

    return;
}

##############################################

=head2 do_child_stuff

  do_child_stuff($c, $dir, $id)

do all child things after a fork

=cut
sub do_child_stuff {
    my($c, $dir, $id) = @_;

    POSIX::setsid() or die "Can't start a new session: $!";

    confess("no c") unless $c;
    $c->stats->clear();
    $c->stash->{'total_backend_waited'} = 0;
    $c->stash->{'total_render_waited'}  = 0;
    $c->stats->profile(begin => 'External Job: '.$id) if $id;
    $c->stats->profile(comment => sprintf('time: %s - host: %s - pid: %s', (scalar localtime), $c->config->{'hostname'}, $$));

    delete $ENV{'THRUK_PERFORMANCE_DEBUG'};

    Thruk::restore_signal_handler();

    ## no critic
    $ENV{'THRUK_MODE'}               = 'CLI';
    $ENV{'THRUK_NO_CONNECTION_POOL'} = 1; # don't use connection pool after forking
    $ENV{'NO_EXTERNAL_JOBS'}         = 1; # don't fork twice
    $ENV{'THRUK_JOB_ID'}             = $id;
    $ENV{'THRUK_JOB_DIR'}            = $dir;

    # make remote user available
    if($c->user_exists) {
        $ENV{REMOTE_USER}        = $c->stash->{'remote_user'};
        $ENV{REMOTE_USER_GROUPS} = join(';', @{$c->user->{'groups'}});
    }

    $|=1; # autoflush
    ## use critic

    Thruk::Backend::Pool::shutdown_backend_thread_pool();


    # connect stdin to dev/null
    open(*STDIN, "+<", "/dev/null") || die "can't reopen stdin to /dev/null: $!";

    # close the fcgid communication socket when running as fcgid process (close all filehandles from 3 to 10 which are sockets)
    for my $fd (3..10) {
        my $io = IO::Handle->new_from_fd($fd,"r");
        if(defined $io && -S $io) {
            POSIX::close($fd);
        }
    }

    # now make sure stdout and stderr point to somewhere, otherwise we get sigpipes pretty soon
    my $fallback_log = '/dev/null';
    $fallback_log    = $c->config->{'log4perl_logfile_in_use'} if $c->config->{'log4perl_logfile_in_use'};
    $fallback_log    = $ENV{'OMD_ROOT'}.'/var/log/thruk.log' if $ENV{'OMD_ROOT'};
    $fallback_log    = $dir."/stderr" if $dir;
    open(*STDERR, ">>", $fallback_log) || die "can't reopen stderr to $fallback_log: $!";
    $fallback_log    = $dir."/stdout" if $dir;
    open(*STDOUT, ">>", $fallback_log) || die "can't reopen stdout to $fallback_log: $!";

    # logging must be reset after closing the filehandles
    Thruk::Utils::Log::reset_logging();
    _debug2("child started with pid ".$$);

    $c->stats->enable(1);
    $c->config->{'slow_page_log_threshold'} = 0;

    # some db drivers need reconnect after forking
    _reconnect($c);

    return;
}


##############################################

=head2 do_parent_stuff

  do_parent_stuff($c, $dir, $pid, $id, $conf)

do all parent things after a fork

=cut
sub do_parent_stuff {
    my($c, $dir, $pid, $id, $conf) = @_;

    confess("got no id") unless $id;

    # write pid file
    my $pidfile = $dir."/pid";
    open(my $fh, '>', $pidfile) or die("cannot write pid $pidfile: $!");
    print $fh $pid;
    print $fh "\n";
    Thruk::Utils::IO::close($fh, $pidfile);

    # write hostname file
    my $hostfile = $dir."/hostname";
    open($fh, '>', $hostfile) or die("cannot write pid $hostfile: $!");
    print $fh $Thruk::NODE_ID, "\n", $Thruk::HOSTNAME, "\n";
    Thruk::Utils::IO::close($fh, $hostfile);

    # write start file
    my $startfile = $dir."/start";
    open($fh, '>', $startfile) or die("cannot write start $startfile: $!");
    print $fh time(),"\n";
    print $fh Dumper($conf);
    print $fh "\n";

    # write user file
    if(!defined $conf->{'allow'} || defined $conf->{'allow'} eq 'user') {
        confess("no remote_user") unless defined $c->stash->{'remote_user'};
        open($fh, '>', $dir."/user") or die("cannot write user: $!");
        print $fh $c->stash->{'remote_user'};
        print $fh "\n";
        Thruk::Utils::IO::close($fh, $dir."/user");
    }

    # write message file
    if(defined $conf->{'message'}) {
        open($fh, '>', $dir."/message") or die("cannot write message: $!");
        print $fh $conf->{'message'};
        print $fh "\n";
        Thruk::Utils::IO::close($fh, $dir."/message");
    }

    # write forward file
    if(defined $conf->{'forward'}) {
        if(ref $conf->{'forward'}) {
            confess("invalid redirect url: ".Dumper($conf->{'forward'}));
        }
        open($fh, '>', $dir."/forward") or die("cannot write forward: $!");
        print $fh $conf->{'forward'};
        print $fh "\n";
        Thruk::Utils::IO::close($fh, $dir."/forward");
    }

    # write show_output file
    if(defined $conf->{'show_output'}) {
        open($fh, '>', $dir."/show_output") or die("cannot write show_output: $!");
        print $fh "1";
        print $fh "\n";
        Thruk::Utils::IO::close($fh, $dir."/show_output");
    }

    _debug2(($conf->{'background'} ? "background" : "")." job $id started with pid ".$pid);

    $c->stash->{'job_id'} = $id;
    if(!$conf->{'background'}) {
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/job.cgi?job=".$id);
    }
    return $id;
}


##############################################

=head2 init_external

  init_external($c)

create job folder and return id

=cut
sub init_external {
    my($c) = @_;

    my $id  = substr(Thruk::Utils::Crypt::hexdigest($$."-".Time::HiRes::time()), 0, 5);
    my $dir = $c->config->{'var_path'}."/jobs/".$id;
    for my $mdir ($c->config->{'var_path'}, $c->config->{'var_path'}."/jobs", $dir) {
        if(! -d $mdir) {
            Thruk::Utils::IO::mkdir($mdir) or do {
                Thruk::Utils::set_message( $c, 'fail_message', 'background job failed to start, mkdir failed '.$mdir.': '.$! );
                die("mkdir $mdir failed: $!");
            };
        }
    }

    # cleanup old jobs
    my $max_age      = time() - 3600;      # keep them for one hour
    my $max_age_dead = time() - (86400*3); # clean broken jobs after 3 days
    for my $olddir (glob($c->config->{'var_path'}."/jobs/*")) {
        if(-f $olddir.'/rc') {
            my @stat = stat($olddir.'/rc');
            if($stat[9] < $max_age) {
                remove_job_dir($olddir);
            }
        } elsif(-f $olddir.'/start') {
            my @stat = stat($olddir.'/start');
            if($stat[9] < $max_age_dead) {
                remove_job_dir($olddir);
            }
        }
    }

    $c->stash->{job_id}         = $id;
    $c->stash->{job_dir}        = $c->config->{'var_path'}."/jobs/".$id."/";
    my $url = Thruk::Utils::Filter::full_uri($c);
    # will confuse the report html preview otherwise and repace the histoy_url with remote.cgi which is useless
    if($url !~ m/remote\.cgi$/mx) {
        $c->stash->{original_url}   = $url;
        $c->stash->{original_uri}   = $c->req->uri->as_string();
        $c->stash->{original_param} = $c->req->parameters;
    }

    return($id, $dir);
}

##############################################

=head2 remove_job_dir

  remove_job_dir($c, $dir)

remove job folder and all files

=cut
sub remove_job_dir {
    my($dir) = @_;
    unlink(glob($dir."/*"));
    rmdir($dir);
    return;
}

##############################################

=head2 _is_running

  _is_running($c, $dir)

return true if process is still running

=cut
sub _is_running {
    my($c, $dir) = @_;
    confess("no dir") unless $dir;
    $dir = Thruk::Utils::IO::untaint($dir);

    return 0 unless -s $dir."/pid";

    # fetch status from remote node
    if(-s $dir."/hostname") {
        my @hosts = split(/\n/mx, read_file($dir."/hostname"));
        my $cluster = $c ? $c->cluster : Thruk->cluster;
        if($cluster->is_clustered() && $hosts[0] ne $Thruk::NODE_ID) {
            confess('clustered _is_running requires $c') unless $c;
            my $res = $c->cluster->run_cluster($hosts[0], 'Thruk::Utils::External::_is_running', [$c, $dir]);
            if($res && exists $res->[0]) {
                return($res->[0]);
            }
            return(0);
        }
    }

    # reap pending zombies
    waitpid(-1, WNOHANG);

    my $pid = read_file($dir."/pid");
    $pid = Thruk::Utils::IO::untaint($pid);
    waitpid($pid, WNOHANG);
    if(kill(0, $pid) > 0) {
        return 1;
    }
    unlink($dir."/pid");

    return 0;
}

##############################################

=head2 _finished_job_page

  _finished_job_page($c, $stash, $forward, $out)

show page for finished jobs

=cut
sub _finished_job_page {
    my($c, $stash, $forward, $out) = @_;
    if(defined $stash and keys %{$stash} > 0) {
        my $cleanup = $stash->{'job_conf'}->{'clean'} ? 1 : 0;
        $c->res->headers->header( @{$stash->{'res_header'}} ) if defined $stash->{'res_header'};
        $c->res->headers->content_type($stash->{'res_ctype'}) if defined $stash->{'res_ctype'};
        if(defined $stash->{'file_name'}) {
            # job dir can be undefined when not doing external forks
            my $file = ($stash->{job_dir}||'').$stash->{'file_name'};
            open(my $fh, '<', $file) or die("cannot open $file: $!");
            binmode $fh;
            local $/ = undef;
            $c->res->body(<$fh>);
            Thruk::Utils::IO::close($fh, $file);
            unlink($file) if defined $c->stash->{cleanfile};
            $c->{'rendered'} = 1;
            $c->res->code($stash->{'file_name_meta'}->{'code'}) if defined $stash->{'file_name_meta'}->{'code'};
            push @{$c->stash->{'extra_headers'}}, @{$stash->{'file_name_meta'}->{'headers'}} if defined $stash->{'file_name_meta'}->{'headers'};
            remove_job_dir($stash->{job_dir}) if $cleanup;
            return;
        }
        # merge stash
            for my $key (keys %{$stash}) {
            next if $key eq 'theme';
            $c->stash->{$key} = $stash->{$key};
            $c->stash->{'time_begin'} = [Time::HiRes::gettimeofday()]; # trigger slow page log otherwise
        }

        # model?
        if(defined $c->stash->{model_type} and defined $c->stash->{model_init}) {
            if($c->stash->{model_type} eq 'Objects') {
                my $model = $c->app->obj_db_model;
                $model->init(@{$c->stash->{model_init}});
            } else {
                confess("model not implemented: ".$c->stash->{model_init});
            }
        }

        # set request parameters
        $c->req->parameters($stash->{original_param}) if $stash->{original_param};

        if(defined $forward) {
            $forward =~ s/^(http|https):\/\/.*?\//\//gmx;
            remove_job_dir($stash->{job_dir}) if $cleanup;
            return $c->redirect_to($forward);
        }

        if(defined $c->stash->{json}) {
            remove_job_dir($stash->{job_dir}) if $cleanup;
            return $c->render(json => $c->stash->{json});
        }

        remove_job_dir($stash->{job_dir}) if $cleanup;
        return;
    }

    if(defined $forward) {
        $forward =~ s/^(http|https):\/\/.*?\//\//gmx;
        return $c->redirect_to($forward);
    }

    $c->stash->{text}     = $out;
    $c->stash->{template} = 'passthrough.tt';
    return;
}

##############################################
sub _clean_unstorable_refs {
    my($var) = @_;
    for my $key (keys %{$var}) {
        my $ref = ref $var->{$key};
        if($ref ne '' && $ref ne 'HASH' && $ref ne 'ARRAY') {
            delete $var->{$key};
        }
    }
    return $var;
}

##############################################
sub _reconnect {
    my($c) = @_;
    return unless $c->{'db'};
    $c->{'db'}->reconnect() or do {
        print STDERR "reconnect failed: ".$@;
        kill($$);
    };
    return;
}

##############################################

1;
