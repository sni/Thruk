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

        ## no critic
        eval($expr);
        ## use critic

        exit; # just to be sure
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

    my $pid = read_file($dir."/pid");
    if(kill(0, $pid) > 0) {
        return 1;
    }

    return 0;
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

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = stat($dir."/pid");
    my $time  = time() - $start[9];

    my $is_running = is_running($c, $id);

    my $percent;
    if($is_running == 0) {
        $percent = 100;
    } elsif(-f $dir."/status") {
        my $percent = read_file($dir."/status");
    }

    return($is_running,$time,$percent);
}


##############################################

=head2 get_result

  get_result($c, $id)

return result of a job

=cut
sub get_result{
    my $c   = shift;
    my $id  = shift;
    my $dir = $c->config->{'var_path'}."/jobs/".$id;

    my $out    = read_file($dir."/stdout");
    my $err    = read_file($dir."/stderr");

    # dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks
    my @start = stat($dir."/pid");
    my @end   = stat($dir."/stdout");

    my $time = $end[9] - $start[9];

    return($out,$err,$time, $dir);
}


##############################################
sub _do_child_stuff {
    my $dir = shift;

    POSIX::setsid() or die "Can't start a new session: $!";
    # close open filehandles except stdin,out,err
    for(1..20) {
        POSIX::close($_);
    }

    open STDERR, '>', $dir."/stderr";
    open STDOUT, '>', $dir."/stdout";

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
    open(my $fh, '>', $dir."/pid");
    print $fh $pid;
    print $fh "\n";
    close($fh);

    # write user file
    open($fh, '>', $dir."/user");
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
                return;
            };
        }
    }

    # cleanup old jobs
    my $max_age = time() - 300; # keep them for 5 minutes
    for my $olddir (glob($c->config->{'var_path'}."/jobs/*")) {
        next unless -f $olddir.'/stdout';
        my @stat = stat($olddir.'/stdout');
        if($stat[9] < $max_age) {
            unlink(glob($olddir."/*"));
            rmdir($olddir);
        }
    }

    $SIG{CHLD} = 'IGNORE';

    return($id, $dir);
}


##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
