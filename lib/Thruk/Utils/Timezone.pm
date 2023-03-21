package Thruk::Utils::Timezone;

=head1 NAME

Thruk::Utils::Timezone - helper to get/set timezone

=head1 DESCRIPTION

get/set timezone

=cut

use warnings;
use strict;
use POSIX ();

use Thruk::Base ();
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;

###################################################

=head1 METHODS

=head2 set_timezone

    set servers timezone

=cut
sub set_timezone {
    my($config, $timezone) = @_;
    $config->{'_server_timezone'} = detect_timezone() unless $config->{'_server_timezone'};

    if(!defined $timezone) {
        $timezone = $config->{'server_timezone'} || $config->{'use_timezone'} || $config->{'_server_timezone'};
    }

    ## no critic
    $ENV{'TZ'} = $timezone;
    ## use critic
    POSIX::tzset();

    return;
}

###################################################

=head2 detect_timezone

    returns current timezone

Try to detect current timezone
Locations like Europe/Berlin are prefered over CEST

=cut

sub detect_timezone {
    if($ENV{'TZ'}) {
        _debug(sprintf("server timezone: %s (from ENV)", $ENV{'TZ'})) if Thruk::Base->verbose;
        return($ENV{'TZ'});
    }

    if(-r '/etc/timezone') {
        chomp(my $tz = Thruk::Utils::IO::read('/etc/timezone'));
        if($tz) {
            _debug(sprintf("server timezone: %s (from /etc/timezone)", $tz)) if Thruk::Base->verbose;
            return $tz;
        }
    }

    if(-r '/etc/sysconfig/clock') {
        my $content = Thruk::Utils::IO::read('/etc/sysconfig/clock');
        if($content =~ m/^\s*ZONE="([^"]+)"/mx) {
            _debug(sprintf("server timezone: %s (from /etc/sysconfig/clock)", $1)) if Thruk::Base->verbose;
            return $1;
        }
        if($content =~ m/^\s*TIMEZONE="([^"]+)"/mx) {
            _debug(sprintf("server timezone: %s (from /etc/sysconfig/clock)", $1)) if Thruk::Base->verbose;
            return $1;
        }
    }

    my $out = Thruk::Utils::IO::cmd("timedatectl 2>/dev/null");
    if($out =~ m/^\s*Time\ zone:\s+(\S+)/mx) {
        _debug(sprintf("server timezone: %s (from timedatectl)", $1)) if Thruk::Base->verbose;
        return($1);
    }

    # returns CEST instead of CET as well
    POSIX::tzset();
    my($std, $dst) = POSIX::tzname();
    if($std) {
        _debug(sprintf("server timezone: %s (from POSIX::tzname)", $std)) if Thruk::Base->verbose;
        return($std);
    }

    # last ressort, date, fails for ex. to set CET instead of CEST
    my $tz = Thruk::Utils::IO::cmd("date +%Z");
    _debug(sprintf("server timezone: %s (from date +%%Z)", $tz)) if Thruk::Base->verbose;
    return $tz;
}

###################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

Thruk is Copyright (c) 2009-present by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself.

=cut

1;
