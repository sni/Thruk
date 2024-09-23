package Thruk::Utils::External;

=head1 NAME

Thruk::Utils::External - Utilities to run background processes

=head1 DESCRIPTION

Utilities to run background processes

=cut

use warnings;
use strict;
use Carp qw/confess/;
use Data::Dumper qw/Dumper/;
use IO::Handle ();
use POSIX ":sys_wait_h";
use Storable ();
use Time::HiRes qw/time/;

use Thruk::Action::AddDefaults ();
use Thruk::Utils::Crypt ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Views::ToolkitRenderer ();

##############################################

=head1 METHODS

=head2 cmd

  cmd($c, {
            cmd          => "command line to execute",
            allow        => all|user,
            message      => "display message while running the job"
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
        my(undef, $out) = Thruk::Utils::IO::cmd($cmd);
        return _finished_job_page($c, $c->stash, undef, $out);
    }

    my($id,$dir) = init_external($c);
    return unless $id;

    my($is_parent, $parent_res) = _fork_twice($c, $id, $dir, $conf);
    return $parent_res if $is_parent;

    do_child_stuff($c, $dir, $id);
    $cmd = $cmd.'; echo $? > '.$dir."/rc" unless $conf->{'no_shell'};
    exec($cmd) or exit(1); # just to be sure
}


##############################################

=head2 perl

  perl($c, {
            expr         => "perl expression to execute",
            allow        => all|user,
            message      => "display message while running the job"
            forward      => "forward on success"
            backends     => "list of selected backends (keys)"
            nofork       => "don't fork"
            background   => "return $jobid if set, or redirect otherwise"
            clean        => "remove job after displaying it if true"
            render       => "set to a true value to render page immediatly"
            show_output  => show console with output
            log_archive  => store stdout/stderr with this filename
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
            $c->db->disable_backends();
            $c->db->enable_backends($conf->{'backends'});
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

    my($is_parent, $parent_res) = _fork_twice($c, $id, $dir, $conf);
    return $parent_res if $is_parent;

    if(defined $conf->{'backends'}) {
        $c->db->disable_backends();
        $c->db->enable_backends($conf->{'backends'});
    }

    my $err;
    eval {
        do_child_stuff($c, $dir, $id);
        $c->stats->profile(begin => 'External::perl');

        do {
            $c->stats->profile(begin => 'External::perl eval');
            ## no critic
            my $rc = eval($conf->{'expr'});
            ## use critic
            $c->stats->profile(end => 'External::perl eval');

            $err = $@;
            if($err) {
                undef $rc;
                if($c->stash->{'last_redirect_to'} && $c->{'detached'}) {
                    if(ref $c->stash->{'last_redirect_to'} || $c->stash->{'last_redirect_to'} =~ m/ARRAY\(/mx) {
                        confess("invalid redirect url: ".Dumper($c->stash->{'last_redirect_to'}));
                    }
                    Thruk::Utils::IO::write($dir."/forward", $c->stash->{'last_redirect_to'}."\n");
                    $err = undef;
                    $rc  = 0;
                }
            }

            # invert rc to match exit code style
            Thruk::Utils::IO::write($dir."/rc", ($rc ? 0 : 1));
            Thruk::Utils::IO::write($dir."/perl_res", (defined $rc && ref $rc eq '') ? Thruk::Utils::Encode::encode_utf8($rc) : "", undef, 1);

            open(*STDERR, '>>', '/dev/null') or _warn("cannot redirect stderr to /dev/null");
            open(*STDOUT, '>>', '/dev/null') or _warn("cannot redirect stdout to /dev/null");
        };

        # unrendered output from template and stash
        if($conf->{'render'} && $c->stash->{'template'} && !$c->{'rendered'}) {
            local $c->stash->{'job_conf'}->{'clean'} = undef;
            _finished_job_page($c, $c->stash);
            Thruk::Action::AddDefaults::end($c);
            Thruk::Views::ToolkitRenderer::render_tt($c);
            my $res = $c->res->finalize;
            $c->finalize_request($res);
            Thruk::Utils::IO::write($dir."/result.dat", $res->[2]->[0]);
            $c->stash->{'file_name'}      = "result.dat";
            $c->stash->{'file_name_meta'} = {
                code    => $res->[0],
                headers => $res->[1],
            };
        }
        # rendered output, ex.: from return $c->render(json => $json);
        elsif($conf->{'render'} && $c->{'rendered'} && !$c->stash->{'last_redirect_to'} && -e $dir."/perl_res") {
            local $c->stash->{'job_conf'}->{'clean'} = undef;
            $c->stash->{'file_name'}      = "perl_res";
            $c->stash->{'file_name_meta'} = {
                code    => $c->res->code(),
                headers => $c->res->headers->psgi_flatten,
            };
        }

        # save stash
        _clean_unstorable_refs($c->stash);
        Storable::store(\%{$c->stash}, $dir."/stash");
        Thruk::Utils::IO::write($dir."/stash.dump", Dumper($c->stash)) if Thruk::Base->debug;
        die($err) if $err; # die again after cleanup
    };
    $err = $@ unless $err;
    $c->stats->profile(end => 'External::perl');
    save_profile($c, $dir);
    _save_log_archive($c, $dir, $conf->{'log_archive'}) if $conf->{'log_archive'};
    if($err) {
        eval {
            Thruk::Utils::IO::write($dir."/stderr", "ERROR: perl eval failed:\n".$err, undef, 1);
            Thruk::Utils::IO::write($dir."/rc", "1\n");
        };
        # calling _exit skips running END blocks
        unlink($dir."/pid"); # signal parent we are done
        exit(1);
    }
    unlink($dir."/pid"); # signal parent we are done
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
    return if(Thruk::Base->mode ne 'FASTCGI' && Thruk::Base->mode ne 'DEVSERVER');

    return if exists $c->req->parameters->{'noexternalforks'};
    return if $ENV{'THRUK_NO_BACKGROUND_PAGES'};

    my @caller = caller(1);
    return(
        Thruk::Utils::External::perl($c, { expr    => $caller[3].'($c)',
                                           message => 'please stand by while page is being rendered...',
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
        my $user = Thruk::Utils::IO::read($dir."/user");
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
        my $user = Thruk::Utils::IO::read($dir."/user");
        chomp($user);
        confess('no remote_user') unless defined $c->stash->{'remote_user'};
        return unless $user eq $c->stash->{'remote_user'};
    }

    my $pidfile = $dir."/pid";
    my $pid = Thruk::Utils::IO::saferead($pidfile);
    if(defined $pid) {
        chomp($pid);

        # is it running on this node?
        if(-s $dir."/hostname") {
            my @hosts = Thruk::Utils::IO::read_as_list($dir."/hostname");
            if($hosts[0] ne $Thruk::Globals::NODE_ID) {
                $c->cluster->run_cluster($hosts[0], 'Thruk::Utils::External::cancel', [$c, $id, $nouser]);
                return _is_running($c, $dir);
            }
        }

        update_status($dir, 99.9, 'canceled');
        Thruk::Utils::IO::write($dir."/killed", sprintf("killed at: %d\njob pid: %d\nuser: %s\n", time(), $pid, $c->stash->{'remote_user'} // '<none>'));
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

    my $start = -e $job_dir.'/start'    ? (stat(_))[9] : 0;
    my $end   = -e $job_dir.'/rc'       ? (stat(_))[9] : 0;
    my $rc    =  Thruk::Utils::IO::saferead($job_dir.'/rc')       // ''; # 0 is OK, everything else is an error (exit code)
    my $res   =  Thruk::Utils::IO::saferead($job_dir.'/perl_res') // '';
    my $out   =  Thruk::Utils::IO::saferead($job_dir.'/stdout')   // '';
    my $err   =  Thruk::Utils::IO::saferead($job_dir.'/stderr')   // '';
    my $host  =  Thruk::Utils::IO::saferead($job_dir.'/hostname') // '';
    my $cmd   =  Thruk::Utils::IO::saferead($job_dir.'/start')    // '';
    my $pid   =  Thruk::Utils::IO::saferead($job_dir.'/pid')      // '';
    if($cmd) {
        $cmd =~ s%^\d+\n%%gmx;
        $cmd =~ s%^\$VAR1\s*=\s*%%gmx;
        $cmd =~ s%\n$%%gmx;
    }
    chomp($rc);
    if($rc !~ m/^\d*$/mx) { $rc = -1; }
    my($hostid, $hostname) = split(/\n/mx, $host);

    $out = Thruk::Utils::Encode::decode_any($out);
    $err = Thruk::Utils::Encode::decode_any($err);

    $remaining = -1 unless defined $remaining;
    my $job   = {
        'id'         => $id,
        'pid'        => $pid,
        'user'       => $user,
        'host_id'    => $hostid   // "",
        'host_name'  => $hostname // "",
        'cmd'        => $cmd,
        'rc'         => $rc  // '',
        'perl_res'   => $res // '',
        'stdout'     => $out // '',
        'stderr'     => $err // '',
        'is_running' => 0+$is_running,
        'time'       => 0+$time,
        'start'      => 0+($start || 0),
        'end'        => 0+($end   || 0),
        'percent'    => 0+$percent,
        'message'    => $message     // '',
        'forward'    => $forward     // '',
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

    _reap_pending_childs();

    my $user = Thruk::Utils::IO::saferead($dir."/user");
    if(defined $user) {
        chomp($user);
        if(!defined $c->stash->{'remote_user'} || $user ne $c->stash->{'remote_user'}) {
            if(!$c->check_user_roles('admin')) {
                return;
            }
        }
    }

    my $is_running = _is_running($c, $dir);
    my $percent    = 0;
    my @start      = Time::HiRes::stat($dir.'/start');
    if(!defined $start[9]) {
        return($is_running,0,$percent,"not started",undef,undef,$user);
    }
    my $time       = time() - $start[9];
    if($is_running == 0) {
        $percent = 100;
        my @end  = Time::HiRes::stat($dir."/stdout");
        $end[9]  = time() unless defined $end[9];
        $time    = $end[9] - $start[9];
    } elsif(-f $dir."/status") {
        $percent = Thruk::Utils::IO::read($dir."/status");
        chomp($percent);
    }

    my $message = Thruk::Utils::IO::saferead($dir."/message");
    chomp($message) if defined $message;

    my $forward = Thruk::Utils::IO::saferead($dir."/forward");
    chomp($forward) if defined $forward;

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
        my $user = Thruk::Utils::IO::read($dir."/user");
        chomp($user);
        confess('no remote_user') unless defined $c->stash->{'remote_user'};
        return unless $user eq $c->stash->{'remote_user'};
    }

    if(!-d $dir) {
        return('', 'no such job: '.$id, 0, $dir, undef, 1, undef);
    }

    my $out = Thruk::Utils::IO::saferead($dir."/stdout") // '';
    my $err = Thruk::Utils::IO::saferead($dir."/stderr") // '';
    my $killed = "";

    # remove known harmless errors
    $err =~ s|Warning:.*?during\ global\ destruction\.\n||gmx;
    $err =~ s|^.*DEBUG.*\n||gmx;
    $err =~ s|^\$VAR\d\ =\ .*\n||gmx;
    $err =~ s|^\s*\n||gmx;

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = Time::HiRes::stat($dir.'/start');
    my @end;
    my $retries = 10;
    while($retries > 0) {
        if(-f $dir."/killed") {
            @end = Time::HiRes::stat($dir."/killed");
            $killed = "job has been killed";
        } elsif(-f $dir."/stdout") {
            @end = Time::HiRes::stat($dir."/stdout");
        } elsif(-f $dir."/stderr") {
            @end = Time::HiRes::stat($dir."/stderr");
        } elsif(-f $dir."/rc") {
            @end = Time::HiRes::stat($dir."/rc");
        }
        if(!defined $end[9]) {
            sleep(1);
            $retries--;
        } else {
            last;
        }
    }
    if(!defined $end[9]) {
        $end[9] = Time::HiRes::time();
        $err    = 'job was killed';
        _error('killed job: '.$dir);
        my $folder = Thruk::Utils::IO::cmd("ls -la $dir");
        _error($folder);
    }

    my $time = $end[9] - $start[9];

    my $stash = -f $dir."/stash" ? Storable::retrieve($dir."/stash") : undef;

    my $rc = Thruk::Utils::IO::saferead($dir."/rc") // -1;
    chomp($rc);

    my $perl_res = Thruk::Utils::IO::saferead($dir."/perl_res");
    chomp($perl_res) if defined $perl_res;

    my $profiles = [];
    for my $p (glob($dir."/profile.log*")) {
        my $text = Thruk::Utils::IO::read($p);
        chomp($text);
        my $htmlfile = $p;
        $htmlfile =~ s/\.log\./.html./gmx;
        my $jsonfile = $p;
        $jsonfile =~ s/\.log\./.json./gmx;
        my $totals;
        if(-f $jsonfile) {
            $totals = Thruk::Utils::IO::json_lock_retrieve($jsonfile);
        }
        push @{$profiles}, {
            name   => "Job ".$id,
            time   => $end[9] // $start[9],
            html   => -e $htmlfile ? Thruk::Utils::IO::read($htmlfile) : undef,
            text   => $text,
            totals => $totals ? $totals->{'totals'} : undef,
        };
        my $dbfile = $p;
        $dbfile =~ s/\.log\./.db./gmx;
        if(-f $dbfile) {
            push @{$profiles}, Thruk::Utils::IO::json_lock_retrieve($dbfile);
        }
    }

    return($out,$err,$time,$dir,$stash,$rc,$profiles,$start[9],$end[9],$perl_res,$killed);
}

##############################################

=head2 job_page

  job_page($c)

process job result page

=cut
sub job_page {
    my($c) = @_;

    my $job    = $c->req->parameters->{'job'};
    my $peerid = $c->req->parameters->{'peer'};
    my $json   = $c->req->parameters->{'json'}   || 0;
    my $cancel = $c->req->parameters->{'cancel'} || 0;
    $c->stash->{no_auto_reload} = 1;
    return $c->detach('/error/index/22') unless defined $job;

    if($peerid) {
        my $peer = $c->db->get_peer_by_key($peerid);
        my $data = $peer->job_data($c, $job);
        return $c->detach('/error/index/22') unless defined $data;
        $c->stash->{job}      = $data   // {};
        $c->stash->{peer}     = $peerid // '';
        $c->stash->{template} = 'job_popup.tt';
        return $c->render(json => $data // {}) if $json;
        return;
    }

    if($cancel) {
        cancel($c, $job);
        return get_json_status($c, $job);
    }

    if($json) {
        return get_json_status($c, $job);
    }

    my($is_running,$time,$percent,$message,$forward,$remaining,$user,$show_output) = get_status($c, $job);
    return $c->detach('/error/index/22') unless defined $is_running;

    if(!$show_output) {
        # try to directly serve the request if it takes less than 3 seconds
        $is_running = wait_for_job($c, $job, 3) if $is_running;
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
        my($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res,$killed) = get_result($c, $job);
        return $c->detach('/error/index/22') unless defined $dir;
        $c->add_profile($profile) if $profile;
        if(defined $stash and defined $stash->{'original_url'}) { $c->stash->{'original_url'} = $stash->{'original_url'} }

        # passthrough $c->detach_error from jobs
        if($stash && $stash->{'error_data'}) {
            return($c->detach_error($c->stash->{'raw_error_data'}//$stash->{'error_data'}));
        }

        return $c->detach('/error/index/29') if $killed;

        # other errors
        if((defined $err && $err ne '') && (!defined $rc || $rc != 0 || (!$out && !$stash))) {
            if($c->req->parameters->{'modal'}) {
                $c->stash->{text}     = $err;
                $c->stash->{template} = 'passthrough.tt';
                return;
            }
            return $c->detach_error({
                msg               => 'Background Job Failed',
                descr             => 'background job failed, look at your logfile for details. ( job id: '.$job.' )',
                debug_information => $err,
            });
        }
        return _finished_job_page($c, $stash, $forward, $out);
    }

    return;
}

##############################################

=head2 wait_for_job

  wait_for_job($jobid, $timeout)

wait for this job to finish

=cut
sub wait_for_job {
    my($c, $job, $timeout) = @_;
    $timeout = 3 unless $timeout;

    my($is_running, $time) = get_status($c, $job);
    $c->stats->profile(begin => "job_page waiting for job: ".$job);
    while($is_running and $time < $timeout) {
        Time::HiRes::sleep(0.1) if $time <  1;
        Time::HiRes::sleep(0.3) if $time >= 1;
        ($is_running, $time) = get_status($c, $job);
    }
    $c->stats->profile(end => "job_page waiting for job: ".$job);

    return $is_running;
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
    Thruk::Utils::IO::write($statusfile, $text."\n");
    return;
}

##############################################

=head2 save_profile

  save_profile($c, $dir)

save profile to profile.log.$pid.<nr> of this job

=cut
sub save_profile {
    my($c, $dir) = @_;

    my $nr   = 0;
    my $base = $dir.'/profile.log.'.$$;
    while(-e $base.'.'.$nr) {
        $nr++;
    }
    my $file = $base.'.'.$nr;

    # update/extend previously written profile
    if($c->stats->{'_saved_to'}) {
        $file = $c->stats->{'_saved_to'};
    }

    $c->set_stats_common_totals();

    my $profile = "";
    eval {
        $profile = $c->stats->report()."\n";
    };
    my $err = $@;
    $profile = $err."\n" if $err;
    return if($c->stats->{'total_time'} == 0 && !$err);
    Thruk::Utils::IO::write($file, $profile);
    $c->stats->{'_saved_to'} = $file;

    $profile = "";
    eval {
        $profile = $c->stats->report_html();
    };
    $profile = $@."\n" if $@;
    $file =~ s/profile\.log/profile.html/gmx;
    Thruk::Utils::IO::write($file, $profile);

    $file =~ s/profile\.html/profile.json/gmx;
    Thruk::Utils::IO::json_lock_store($file, { totals => $c->stats->{'totals'}});

    if($c->stash->{'db_profiles'} && $c->user && $c->user->check_user_roles('admin')) {
        $file =~ s/profile\.json/profile.db/gmx;
        my $db_profile = Thruk::Utils::render_db_profile($c, 'Job '.$ENV{'THRUK_JOB_ID'}.' DB', $c->stash->{'db_profiles'});
        Thruk::Utils::IO::json_lock_store($file, $db_profile, { pretty => 1 });
        delete $c->stash->{'db_profiles'};
    }

    return;
}

##############################################
# save stdout and stderr into new logfile
sub _save_log_archive {
    my($c, $job_dir, $logfile) = @_;

    my $out = Thruk::Utils::IO::saferead($job_dir.'/stdout') // '';
    my $err = Thruk::Utils::IO::saferead($job_dir.'/stderr') // '';
    Thruk::Utils::IO::write($logfile, $out.$err);

    return;
}

##############################################

=head2 do_child_stuff

  do_child_stuff($c, $dir, $id)

do all child things after a fork

=cut
sub do_child_stuff {
    my($c, $dir, $id, $keep_stdout_err) = @_;

    confess("no c") unless $c;

    _decouple_fcgid();

    $c->stats->clear(); # start new stats session
    $c->stash->{'total_backend_waited'}  = 0;
    $c->stash->{'total_render_waited'}   = 0;
    $c->stash->{'total_io_time'}         = 0;
    $c->stash->{'total_io_lock'}         = 0;
    $c->stash->{'total_io_cmd'}          = 0;
    $c->stash->{'total_backend_queries'} = 0;
    $c->stats->profile(begin => 'External Job: '.$id) if $id;
    $c->stats->profile(comment => sprintf('time: %s - host: %s - pid: %s', (scalar localtime), $c->config->{'hostname'}, $$));
    delete $c->stash->{'db_profiles'};

    delete $ENV{'THRUK_PERFORMANCE_DEBUG'};

    Thruk::Base::restore_signal_handler();

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
    ## use critic

    $c->{'app'}->{'pool'}->shutdown_threads() if $c->{'app'}->{'pool'};

    # now make sure stdout and stderr point to somewhere, otherwise we get sigpipes pretty soon
    unless($keep_stdout_err) {
        my $fallback_log = '/dev/null';
        $fallback_log    = $c->config->{'log4perl_logfile_in_use'} if $c->config->{'log4perl_logfile_in_use'};
        $fallback_log    = $ENV{'OMD_ROOT'}.'/var/log/thruk.log' if $ENV{'OMD_ROOT'};
        $fallback_log    = $dir."/stderr" if $dir;
        open(*STDERR, ">>", $fallback_log) || die "can't reopen stderr to $fallback_log: $!";
        $fallback_log    = $dir."/stdout" if $dir;
        open(*STDOUT, ">>", $fallback_log) || die "can't reopen stdout to $fallback_log: $!";
    }

    ## no critic
    $|=1; # autoflush
    ## use critic

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

  do_parent_stuff($c, $dir, $id, $conf)

do all parent things after a fork

=cut
sub do_parent_stuff {
    my($c, $dir, $id, $conf) = @_;

    confess("got no id") unless $id;

    # write hostname file
    Thruk::Utils::IO::write($dir."/hostname", $Thruk::Globals::NODE_ID."\n".$Thruk::Globals::HOSTNAME."\n");

    # write start file
    Thruk::Utils::IO::write($dir."/start", time()."\n".Dumper($conf)."\n");

    # write user file
    if(!defined $conf->{'allow'} || defined $conf->{'allow'} eq 'user') {
        confess("no remote_user") unless defined $c->stash->{'remote_user'};
        Thruk::Utils::IO::write($dir."/user", $c->stash->{'remote_user'}."\n");
    }

    # write message file
    if(defined $conf->{'message'}) {
        Thruk::Utils::IO::write($dir."/message", $conf->{'message'}."\n");
    }

    # write forward file
    if(defined $conf->{'forward'}) {
        if(ref $conf->{'forward'}) {
            confess("invalid redirect url: ".Dumper($conf->{'forward'}));
        }
        Thruk::Utils::IO::write($dir."/forward", $conf->{'forward'}."\n");
    }

    # write show_output file
    if(defined $conf->{'show_output'}) {
        Thruk::Utils::IO::write($dir."/show_output", "1\n");
    }

    _debug2(($conf->{'background'} ? "background" : "")." job $id started");

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
    cleanup_job_folders($c);

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

=head2 cleanup_job_folders

  cleanup_job_folders($c)

remove old job folders

=cut
sub cleanup_job_folders {
    my($c, $verbose) = @_;

    $c->stats->profile(begin => "cleanup_job_folders");

    my($total, $removed) = (0, 0);
    my $max_age      = time() - 3600;      # keep them for one hour
    my $max_age_dead = time() - (86400*3); # clean broken jobs after 3 days
    for my $olddir (glob($c->config->{'var_path'}."/jobs/*")) {
        $total++;
        if(-f $olddir.'/rc') {
            my @stat = stat($olddir.'/rc');
            if($stat[9] < $max_age) {
                remove_job_dir($olddir);
                $removed++;
                if($verbose && -d $olddir.'/.') {
                    _warn("unable to remove job folder: %s", $olddir);
                }
            }
        }
        elsif(-f $olddir.'/start') {
            my @stat = stat($olddir.'/start');
            if($stat[9] < $max_age_dead) {
                remove_job_dir($olddir);
                $removed++;
                if($verbose && -d $olddir.'/.') {
                    _warn("unable to remove job folder: %s", $olddir);
                }
            }
        }
        else {
            my @stat = stat($olddir.'/');
            if($stat[9] < $max_age_dead) {
                remove_job_dir($olddir);
                $removed++;
                if($verbose && -d $olddir.'/.') {
                    _warn("unable to remove job folder: %s", $olddir);
                }
            }
        }
    }

    $c->stats->profile(end => "cleanup_job_folders");
    return($total, $removed);
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

    my $pid = Thruk::Utils::IO::saferead($dir."/pid");
    return 0 unless defined $pid;
    $pid = Thruk::Utils::IO::untaint($pid);

    # fetch status from remote node
    if(-s $dir."/hostname") {
        my @hosts = Thruk::Utils::IO::read_as_list($dir."/hostname");
        if($hosts[0] ne $Thruk::Globals::NODE_ID) {
            confess('clustered _is_running requires $c') unless $c;
            my $cluster = $c->cluster;
            if($cluster->is_clustered()) {
                my $res = $c->cluster->run_cluster($hosts[0], 'Thruk::Utils::External::_is_running', [$c, $dir]);
                if($res && exists $res->[0]) {
                    return($res->[0]);
                }
            }
            return(0);
        }
    }

    _reap_pending_childs();

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
           $cleanup = 0 if $ENV{'TEST_AUTHOR'};
        $c->res->headers->header( @{$stash->{'res_header'}} ) if defined $stash->{'res_header'};
        $c->res->headers->content_type($stash->{'res_ctype'}) if defined $stash->{'res_ctype'};
        if(defined $stash->{'file_name'}) {
            # job dir can be undefined when not doing external forks
            my $file = ($stash->{job_dir}||'').$stash->{'file_name'};
            open(my $fh, '<', $file) or die("cannot open $file: $!");
            binmode $fh;
            local $/ = undef;
            $c->res->body(<$fh>);
            CORE::close($file);
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
            next if $key eq 'total_backend_waited';
            next if $key eq 'total_render_waited';
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
        if($key eq 'model_init') {
            delete $var->{$key};
        }
    }
    return $var;
}

##############################################
sub _reconnect {
    my($c) = @_;
    return unless $c->db();
    $c->db->reconnect() or do {
        _error("reconnect failed: %s", $@);
        kill($$);
    };
    return;
}

##############################################
# fork twice and return parent initial stuff or exit
# if it doesn't return anything, you are the child
sub _fork_twice {
    my($c, $id, $dir, $conf) = @_;

    my $pid = fork();
    die "fork() failed: $!" unless defined $pid;

    if($pid) {
        my $parent_res = do_parent_stuff($c, $dir, $id, $conf);
        waitpid($pid, 0);
        return(1, $parent_res);
    }

    # fork twice to completely detach
    my $pid2 = fork();
    die "fork() failed: $!" unless defined $pid2;
    if($pid2) {
        Thruk::Utils::IO::write($dir."/pid", $pid2);
        _decouple_fcgid();
        exit;
    }

    return(0, undef);
}

##############################################
# close stdin and fcgid communication socket
sub _decouple_fcgid {
    POSIX::setsid() or die "Can't start a new session: $!";
    # close the fcgid communication socket when running as fcgid process (close all filehandles from 3 to 10 which are sockets)
    for my $fd (0..10) {
        my $io = IO::Handle->new_from_fd($fd,"r");
        if(defined $io && -S $io) {
            POSIX::close($fd);
        }
    }

    # connect stdin to dev/null
    open(*STDIN, "+<", "/dev/null") || die "can't reopen stdin to /dev/null: $!";

    return;
}

##############################################
# reap all finished child processes
sub _reap_pending_childs {
    while(waitpid(-1, WNOHANG) > 0) {
    }
    return;
}

##############################################

1;
