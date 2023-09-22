package Thruk::Utils::CLI::Maintenance;

=head1 NAME

Thruk::Utils::CLI::Maintenance - Maintenance CLI module

=head1 DESCRIPTION

The maintenance command performs regular maintenance jobs like

    - cleaning old session files

=head1 SYNOPSIS

  Usage: thruk [globaloptions] maintenance

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=back

=cut

use warnings;
use strict;

use Thruk::Utils::CookieAuth ();
use Thruk::Utils::External ();
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;

##############################################
# no backends required for this command
our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action) = @_;
    $c->stats->profile(begin => "_cmd_maintenance($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    # sleep random number of seconds to avoid cluster conflicts with already removed sessions
    if($ENV{'THRUK_CRON'}) {
        sleep(int(rand(10)));
    }

    _info("running maintenance jobs:");

    # remove old user session files
    my($total, $removed) = Thruk::Utils::CookieAuth::clean_session_files($c);
    _info("  - %-20s: removed %5d / %5d old sessions", "sessions", $removed, $total);

    ($total, $removed) = clean_old_user_files($c);
    _info("  - %-20s: removed %5d / %5d unused user files", "user files", $removed, $total);

    ($total, $removed) = Thruk::Utils::External::cleanup_job_folders($c, 1);
    _info("  - %-20s: removed %5d / %5d old job folders", "jobs", $removed, $total);

    $c->stats->profile(end => "_cmd_maintenance($action)");
    return("maintenance complete\n", 0);
}

##############################################

=head2 clean_old_user_files

    clean_old_user_files($c)

removes user files from failed logins after 24hours

=cut
sub clean_old_user_files {
    my($c) = @_;
    $c->stats->profile(begin => "clean_old_user_files");
    my($total, $removed) = (0, 0);

    my $failed_timeout = time() - 86400;
    my $old_timeout    = time() - (86400 * 365); # remove unused logins after one year

    my $sdir = $c->config->{'var_path'}.'/users';
    return unless -d $sdir."/.";
    opendir(my $dh, $sdir) or die "can't opendir '$sdir': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        $total++;
        my $file = $sdir.'/'.$entry;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
           $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);

        next unless $mtime;
        next unless $mtime < $failed_timeout;

        my $data;
        eval {
            $data = Thruk::Utils::IO::json_lock_retrieve($file);
        };
        _warn($@) if $@;
        # user contains a single entry which is the failed login counter
        if(scalar keys %{$data} == 1 && defined $data->{'login'} && $data->{'login'}->{'failed'}) {
            unlink($file);
            $removed++;
            next;
        }

        # remove very old user files as well
        if($mtime < $old_timeout) {
            unlink($file);
            $removed++;
            next;
        }
    }

    $c->stats->profile(end => "clean_old_user_files");
    return($total, $removed);
}

##############################################

1;
