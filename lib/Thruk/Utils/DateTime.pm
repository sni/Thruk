package Thruk::Utils::DateTime;

=head1 NAME

Thruk::Utils::DateTime - Date/Time relative Utilities Collection for Thruk

=head1 DESCRIPTION

Date/Time related Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Date::Calc qw/Normalize_DHMS/;
use Carp qw/confess/;
use POSIX qw/strftime/;

##############################################
=head1 METHODS

=head2 mktime

  my $timestamp = mktime($year,$month,$day, $hour,$min,$sec)

return timestamp for given date

=cut
sub mktime {
    my($year,$month,$day, $hour,$min,$sec) = @_;
    my $m = $month - 1;    # POSIX::mktime month starts at 0
    my $y = $year  - 1900; # POSIX::mktime year starts at 1900
    my $ts = POSIX::mktime($sec, $min, $hour, $day, $m, $y);
    confess(sprintf("invalid date: %s-%s-%s %s:%s:%s", $day, $month, $year, $hour,$min,$sec)) unless defined $ts;
    return $ts;
}

########################################

=head2 normal_mktime

  normal_mktime($year,$mon,$day,$hour,$min,$sec)

returns normalized timestamp for given date

=cut
sub normal_mktime {
    my($year,$mon,$day,$hour,$min,$sec) = @_;

    # calculate borrow
    my $add_time = 0;
    if($hour == 24) {
        $add_time = 86400;
        $hour = 0;
    }

    confess("undefined value") unless defined $sec;
    ($day, $hour, $min, $sec) = Normalize_DHMS($day, $hour, $min, $sec);
    my $timestamp = mktime($year,$mon,$day, $hour,$min,$sec);
    $timestamp += $add_time;
    return $timestamp;
}

########################################

=head2 start_of_day

  start_of_day($ts)

returns start of day for given timestamp (00:00:00)

=cut
sub start_of_day {
    my($ts) = @_;

    my @localtime = localtime($ts);
    return(mktime(strftime("%Y", @localtime), strftime("%m", @localtime), strftime("%d", @localtime), 0,0,0));
}

##############################################

1;
