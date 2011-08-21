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

  cmd($c, $cmd)

run command in an external process

=cut
sub cmd {
    my $c         = shift;
    my $cmd       = shift;
    my ($id,$dir) = _init_external($c);
    return unless $id;
    my $pid       = fork();

    if ($pid) {
        return _do_parent_stuff($c, $dir, $pid, $id);
    } else {
        _do_child_stuff($dir);

        open STDERR, '>', $dir."/stderr";
        open STDOUT, '>', $dir."/stdout";

        exec("/bin/sh -c '".$cmd."'");
        exit; # just to be sure
    }
}


##############################################

=head2 perl

  perl($c, $expr)

run perl expression in an external process

=cut
sub perl {
    my $c         = shift;
    my $expr      = shift;
    my ($id,$dir) = _init_external($c);
    return unless $id;
    my $pid       = fork();

    if ($pid) {
        return _do_parent_stuff($c, $dir, $pid, $id);
    } else {
        _do_child_stuff($dir);

        do {
            ## no critic
            local *STDOUT;
            local *STDERR;
            open STDERR, '>', $dir."/stderr";
            open STDOUT, '>', $dir."/stdout";
            eval($expr);
            ## use critic

            if($@) {
                print STDERR $@;
                exit;
            }

            close(STDOUT);
            close(STDERR);
        };

        # save stash
        store(\%{$c->stash}, $dir."/stash");

        exit;
    }
}


##############################################

=head2 is_running

  is_running($c, $id)

return true if process is still running

=cut
sub is_running {
    my $c   = shift;
    my $id  = shift;
    my $dir = $c->config->{'var_path'}."/jobs/".$id;

    return unless -f $dir."/user";
    my $user = read_file($dir."/user");
    chomp($user);
    return unless $user eq $c->stash->{'remote_user'};

    return _is_running($dir);
}


##############################################

=head2 get_status

  get_status($c, $id)

return status of a job

=cut
sub get_status {
    my $c   = shift;
    my $id  = shift;
    my $dir = $c->config->{'var_path'}."/jobs/".$id;

    # reap pending zombies
    waitpid(-1, WNOHANG);

    return unless -f $dir."/user";
    my $user = read_file($dir."/user");
    chomp($user);
    return unless $user eq $c->stash->{'remote_user'};

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = stat($dir."/pid");
    my $time  = time() - $start[9];

    my $is_running = _is_running($dir);

    my $percent = 0;
    if($is_running == 0) {
        $percent = 100;
        my @end  = stat($dir."/stdout");
        $time    = $end[9] - $start[9];
    } elsif(-f $dir."/status") {
        my $percent = read_file($dir."/status");
    }

    return($is_running,$time,$percent);
}


##############################################

=head2 get_json_status

  get_json_status($c, $id)

return json status of a job

=cut
sub get_json_status {
    my $c   = shift;
    my $id  = shift;

    my($is_running,$time,$percent) = get_status($c, $id);
    return unless defined $time;

    $c->stash->{'json'}   = {
            'is_running' => $is_running,
            'time'       => $time,
            'percent'    => $percent,
    };

    return $c->forward('Thruk::View::JSON');
}


##############################################

=head2 get_result

  get_result($c, $id)

return result of a job

=cut
sub get_result {
    my $c   = shift;
    my $id  = shift;
    my $dir = $c->config->{'var_path'}."/jobs/".$id;

    return unless -f $dir."/user";
    my $user = read_file($dir."/user");
    chomp($user);
    return unless $user eq $c->stash->{'remote_user'};

    my $out    = read_file($dir."/stdout");
    my $err    = read_file($dir."/stderr");

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = stat($dir."/pid");
    my @end   = stat($dir."/stdout");

    my $time = $end[9] - $start[9];

    my $stash;
    $stash = retrieve($dir."/stash") if -f $dir."/stash";

    return($out,$err,$time, $dir,$stash);
}


##############################################
sub _do_child_stuff {
    my $dir = shift;

    POSIX::setsid() or die "Can't start a new session: $!";

    # close open filehandles
    for my $fd (0..1024) {
        POSIX::close($fd);
    }

    $|=1; # autoflush
    return;
}


##############################################
sub _do_parent_stuff {
    my $c   = shift;
    my $dir = shift;
    my $pid = shift;
    my $id  = shift;

    # write pid file
    open(my $fh, '>', $dir."/pid") or die("cannot write pid: $!");
    print $fh $pid;
    print $fh "\n";
    close($fh);

    # write user file
    open($fh, '>', $dir."/user") or die("cannot write pid: $!");
    print $fh $c->stash->{'remote_user'};
    print $fh "\n";
    close($fh);

    return $id;
}


##############################################
sub _init_external {
    my $c = shift;

    my $id  = substr(md5_hex($$."-".Time::HiRes::time()), 0, 5);
    my $dir = $c->config->{'var_path'}."/jobs/".$id;
    for my $mdir ($c->config->{'var_path'}, $c->config->{'var_path'}."/jobs", $dir) {
        if(! -d $mdir) {
            mkdir($mdir) or do {
                Thruk::Utils::set_message( $c, 'fail_message', 'background job failed to start, mkdir failed '.$mdir.': '.$! );
                die("mkdir $mdir failed: $!");
            };
            chmod 0770, $dir;
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
    $c->stash->{job_dir}      = $c->config->{'var_path'}."/jobs/".$id;
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

    my $pid = read_file($dir."/pid");
    if(kill(0, $pid) > 0) {
        return 1;
    }

    return 0;
}


##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
