package Thruk::Utils::External;

=head1 NAME

Thruk::Utils::External - Utilities to run background processes

=head1 DESCRIPTION

Utilities to run background processes

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use Time::HiRes;
use File::Slurp;
use Storable;
use POSIX ":sys_wait_h";

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
        }
    );

run command in an external process

=cut
sub cmd {
    my $c         = shift;
    my $conf      = shift;

    my $cmd = $c->config->{'thruk_shell'}." '".$conf->{'cmd'}."'";
    if($conf->{'no_shell'}) {
        $cmd = $conf->{'cmd'};
    }

    if(   $c->config->{'no_external_job_forks'}
       or $conf->{'nofork'}
       or exists $c->{'request'}->{'parameters'}->{'noexternalforks'}
    ) {
        local $ENV{REMOTE_USER} = $c->stash->{'remote_user'};
        my $out = `$cmd`;
        return _finished_job_page($c, $c->stash, undef, $out);
    }

    my($id,$dir) = _init_external($c);
    return unless $id;
    my $pid       = fork();
    die "fork() failed: $!" unless defined $pid;

    if($pid) {
        return _do_parent_stuff($c, $dir, $pid, $id, $conf);
    } else {
        _do_child_stuff($c, $dir, $id);

        $SIG{CHLD} = 'DEFAULT';


        open STDERR, '>', $dir."/stderr";
        open STDOUT, '>', $dir."/stdout";

        # some db drivers need reconnect after forking
        _reconnect($c);

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
        }
    )

run perl expression in an external process

=cut
sub perl {
    my $c         = shift;
    my $conf      = shift;

    if(   $c->config->{'no_external_job_forks'}
       or $conf->{'nofork'}
       or exists $c->{'request'}->{'parameters'}->{'noexternalforks'}
    ) {
        if(defined $conf->{'backends'}) {
            $c->{'db'}->disable_backends();
            $c->{'db'}->enable_backends($conf->{'backends'});
        }
        ## no critic
        my $rc = eval($conf->{'expr'});
        ## use critic
        die($@) if $@;
        _finished_job_page($c, $c->stash);
        return $rc;
    }

    my ($id,$dir) = _init_external($c);
    return unless $id;
    my $pid       = fork();
    die "fork() failed: $!" unless defined $pid;

    if($pid) {
        return _do_parent_stuff($c, $dir, $pid, $id, $conf);
    } else {
        if(defined $conf->{'backends'}) {
            $c->{'db'}->disable_backends();
            $c->{'db'}->enable_backends($conf->{'backends'});
        }
        eval {
            $c->stats->profile(begin => 'External::perl');
            _do_child_stuff($c, $dir, $id);

            do {
                ## no critic
                local *STDOUT;
                local *STDERR;
                open STDERR, '>', $dir."/stderr";
                open STDOUT, '>', $dir."/stdout";

                # some db drivers need reconnect after forking
                _reconnect($c);

                eval($conf->{'expr'});
                ## use critic

                if($@) {
                    print STDERR $@;
                    exit(1);
                }

                close(STDOUT);
                close(STDERR);
            };

            # save stash
            _clean_code_refs($c->stash);
            store(\%{$c->stash}, $dir."/stash");

            $c->stats->profile(end => 'External::perl');
            save_profile($c, $dir);
        };
        if($@) {
            my $err = $@;
            eval {
                open(my $fh, '>>', $dir."/stderr");
                print $fh $err;
                Thruk::Utils::IO::close($fh, $dir."/stderr");
            };
            save_profile($c, $dir);
            exit(1);
        }
        save_profile($c, $dir);
        exit(0);
    }
    exit(1);
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

    return _is_running($dir);
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
        my $pid = read_file($pidfile);
        update_status($dir, 99.9, 'canceled');
        kill(-15, $pid);
        sleep(1);
        kill(-2, $pid);
        sleep(1);
    }
    return _is_running($dir);
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

    if( -f $dir."/user" ) {
        my $user = read_file($dir."/user");
        chomp($user);
        return unless $user eq $c->stash->{'remote_user'};
    }

    my $is_running = _is_running($dir);
    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start      = stat($dir.'/start');
    my $time       = time() - $start[9];
    my $percent    = 0;
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

    my $remaining;
    if($percent =~ m/^(\d+)\s+([\d\.\-]+)\s+(.*)$/mx) {
        $percent   = $1;
        $remaining = $2;
        $message   = $3;
    }

    return($is_running,$time,$percent,$message,$forward,$remaining);
}


##############################################

=head2 get_json_status

  get_json_status($c, $id)

return json status of a job

=cut
sub get_json_status {
    my($c, $id) = @_;
    confess("got no id") unless $id;

    my($is_running,$time,$percent,$message,$forward,$remaining) = get_status($c, $id);
    return unless defined $time;

    $remaining = -1 unless defined $remaining;
    $c->stash->{'json'}   = {
            'is_running' => 0+$is_running,
            'time'       => 0+$time,
            'percent'    => 0+$percent,
            'message'    => $message,
            'forward'    => $forward,
            'remaining'  => 0+$remaining,
    };

    return $c->forward('Thruk::View::JSON');
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

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = stat($dir.'/start');
    my @end;
    if(-f $dir."/stdout") {
        @end = stat($dir."/stdout")
    } elsif(-f $dir."/stderr") {
        @end = stat($dir."/stderr")
    } elsif(-f $dir."/rc") {
        @end = stat($dir."/rc")
    }
    unless(defined $end[9]) {
        $end[9] = time();
        $err    = 'job was killed';
        $c->log->error('killed job: '.$dir);
        $c->log->error(`ls -la $dir`);
    }

    my $time = $end[9] - $start[9];

    my $stash;
    $stash = retrieve($dir."/stash") if -f $dir."/stash";

    my $rc;
    $rc = read_file($dir."/rc") if -f $dir."/rc";
    chomp($rc) if defined $rc;

    my $profile;
    $profile = read_file($dir."/profile.log") if -f $dir."/profile.log";
    chomp($profile) if defined $profile;

    return($out,$err,$time,$dir,$stash,$rc,$profile);
}

##############################################

=head2 job_page

  job_page($c)

process job result page

=cut
sub job_page {
    my($c) = @_;

    my $job  = $c->{'request'}->{'parameters'}->{'job'};
    my $json = $c->{'request'}->{'parameters'}->{'json'} || 0;
    $c->stash->{no_auto_reload} = 1;
    return $c->detach('/error/index/22') unless defined $job;
    if($json) {
        return get_json_status($c, $job);
    }

    my($is_running,$time,$percent,$message,$forward) = get_status($c, $job);
    return $c->detach('/error/index/22') unless defined $is_running;

    # try to directly serve the request if it takes less than 10seconds
    while($is_running and $time < 10) {
        sleep(1);
        ($is_running,$time,$percent,$message,$forward) = get_status($c, $job);
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
        $c->stash->{template}              = 'waiting_for_job.tt';
    } else {
        # job finished, display result
        #my($out,$err,$time,$dir,$stash)...
        my($out,$err,undef,$dir,$stash) = get_result($c, $job);
        return $c->detach('/error/index/22') unless defined $dir;
        if(defined $stash and defined $stash->{'original_url'}) { $c->stash->{'original_url'} = $stash->{'original_url'} };
        if(defined $err and $err ne '') {
            $c->error($err);
            $c->log->error($err);
            return $c->detach('/error/index/23')
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
    open(my $fh, '>', $statusfile) or die("cannot write status $statusfile: $!");
    print $fh $percent, " ", $remaining_seconds, " ", $status, "\n";
    Thruk::Utils::IO::close($fh, $statusfile);
    return;
}

##############################################

=head2 save_profile

  save_profile($c, $dir)

save profile to profile.log of this job

=cut
sub save_profile {
    my($c, $dir) = @_;

    my $file = $dir.'/profile.log';
    open(my $fh, '>>', $file) or die("cannot write $file: $!");
    local $ENV{COLUMNS} = 140;
    local $SIG{__WARN__} = sub { }; # suppress useless warnings from Catalyst::Utils::term_width
    eval {
        print $fh "".$c->stats->report(),"\n";
    };
    print $fh $@,"\n" if $@;
    CORE::close($fh);
    return;
}

##############################################

=head2 log_profile

  log_profile($c)

log profile to info channel

=cut
sub log_profile {
    my($c) = @_;

    local $ENV{COLUMNS} = 140;
    local $SIG{__WARN__} = sub { }; # suppress useless warnings from Catalyst::Utils::term_width
    eval {
        $c->log->info(sprintf("Req: %03d, profile:\n%s", $Catalyst::COUNT, scalar $c->stats->report()));
    };
    return;
}

##############################################
sub _do_child_stuff {
    my($c, $dir, $id) = @_;

    POSIX::setsid() or die "Can't start a new session: $!";

    delete $ENV{'THRUK_SRC'};
    delete $ENV{'THRUK_PERFORMANCE_DEBUG'};

    # don't use connection pool after forking
    $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;

    # don't fork twice
    $ENV{'NO_EXTERNAL_JOBS'}         = 1;

    # make remote user available
    confess('no remote_user') unless defined $c->stash->{'remote_user'};
    $ENV{REMOTE_USER} = $c->stash->{'remote_user'};

    # make job id available
    $ENV{'THRUK_JOB_ID'}  = $id;
    $ENV{'THRUK_JOB_DIR'} = $dir;

    $|=1; # autoflush

    Thruk::Backend::Pool::shutdown_backend_thread_pool();

    # close open filehandles
    for my $fd (0..1024) {
        POSIX::close($fd);
    }

    $c->stats->enable(1);

    return;
}


##############################################
sub _do_parent_stuff {
    my($c, $dir, $pid, $id, $conf) = @_;

    confess("got no id") unless $id;

    # write pid file
    my $pidfile = $dir."/pid";
    open(my $fh, '>', $pidfile) or die("cannot write pid $pidfile: $!");
    print $fh $pid;
    print $fh "\n";
    Thruk::Utils::IO::close($fh, $pidfile);

    # write start file
    my $startfile = $dir."/start";
    open($fh, '>', $startfile) or die("cannot write start $startfile: $!");
    print $fh time(),"\n";
    print $fh Dumper($conf);
    print $fh "\n";

    # write user file
    if(!defined $conf->{'allow'} or defined $conf->{'allow'} eq 'user') {
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
        open($fh, '>', $dir."/forward") or die("cannot write forward: $!");
        print $fh $conf->{'forward'};
        print $fh "\n";
        Thruk::Utils::IO::close($fh, $dir."/forward");
    }

    $c->stash->{'job_id'} = $id;
    if(!$conf->{'background'}) {
        return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/job.cgi?job=".$id);
    }
    return $id;
}


##############################################
sub _init_external {
    my $c = shift;

    my $id  = substr(md5_hex($$."-".Time::HiRes::time()), 0, 5);
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
    my $max_age = time() - 3600; # keep them for one hour
    for my $olddir (glob($c->config->{'var_path'}."/jobs/*")) {
        next unless -f $olddir.'/stdout';
        my @stat = stat($olddir.'/stdout');
        if($stat[9] < $max_age) {
            unlink(glob($olddir."/*"));
            rmdir($olddir);
        }
    }

    $SIG{CHLD} = 'IGNORE';

    $c->stash->{job_id}       = $id;
    $c->stash->{job_dir}      = $c->config->{'var_path'}."/jobs/".$id."/";
    $c->stash->{original_url} = Thruk::Utils::Filter::full_uri($c, 1);

    return($id, $dir);
}


##############################################

=head2 _is_running

  _is_running($dir)

return true if process is still running

=cut
sub _is_running {
    my $dir = shift;

    return 0 unless -s $dir."/pid";

    my $pid = read_file($dir."/pid");
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
        $c->res->headers->header( @{$stash->{'res_header'}} ) if defined $stash->{'res_header'};
        $c->res->content_type($stash->{'res_ctype'})          if defined $stash->{'res_ctype'};
        if(defined $stash->{'file_name'}) {
            my $file = $stash->{job_dir}.$stash->{'file_name'};
            open(my $fh, '<', $file) or die("cannot open $file: $!");
            binmode $fh;
            local $/ = undef;
            $c->res->body(<$fh>);
            Thruk::Utils::IO::close($fh, $file);
            unlink($file) if defined $c->stash->{cleanfile};
            return;
        }
        # merge stash
            for my $key (keys %{$stash}) {
            next if $key eq 'theme';
            $c->stash->{$key} = $stash->{$key};
        }

        # model?
        if(defined $c->stash->{model_type} and defined $c->stash->{model_init}) {
            my $model  = $c->model($c->stash->{model_type});
            $model->init(@{$c->stash->{model_init}});
        }

        if(defined $forward) {
            $forward =~ s/^(http|https):\/\/.*?\//\//gmx;
            return $c->response->redirect($forward);
        }

        if(defined $c->stash->{json}) {
            $c->forward('Thruk::View::JSON');
        }

        return;
    }
    $c->stash->{text}     = $out;
    $c->stash->{template} = 'passthrough.tt';
    return;
}

##############################################
sub _clean_code_refs {
    my $var = shift;
    for my $key (keys %{$var}) {
        delete $var->{$key} if ref $var->{$key} eq 'CODE';
    }
    return $var;
}

##############################################
sub _reconnect {
    my($c) = @_;
    $c->{'db'}->reconnect() or do {
        print STDERR "reconnect failed: ".$@;
        kill($$);
    };
    return;
}

##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
