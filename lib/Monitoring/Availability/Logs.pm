package Monitoring::Availability::Logs;

use 5.008;
use strict;
use warnings;
use Data::Dumper;
use Carp;
use POSIX qw(strftime);
use Encode qw/decode/;

use constant {
    STATE_UP            =>  0,
    STATE_DOWN          =>  1,
    STATE_UNREACHABLE   =>  2,

    STATE_OK            =>  0,
    STATE_WARNING       =>  1,
    STATE_CRITICAL      =>  2,
    STATE_UNKNOWN       =>  3,

    START_NORMAL        =>  1,
    START_RESTART       =>  2,
    STOP_NORMAL         =>  0,
    STOP_ERROR          => -1,
};

$Monitoring::Availability::Logs::host_states = {
    'OK'                => 0,
    'UP'                => 0,
    'DOWN'              => 1,
    'UNREACHABLE'       => 2,
    'RECOVERY'          => 0,
    'PENDING'           => 0,
    '(unknown)'         => 3,
};

$Monitoring::Availability::Logs::service_states = {
    'OK'                => 0,
    'WARNING'           => 1,
    'CRITICAL'          => 2,
    'UNKNOWN'           => 3,
    'RECOVERY'          => 0,
    'PENDING'           => 0,
    '(unknown)'         => 3,
};

=head1 NAME

Monitoring::Availability::Logs - Load/Store/Access Logfiles

=head1 DESCRIPTION

Store for logfiles

=head2 new ( [ARGS] )

Creates an C<Monitoring::Availability::Log> object.

=cut

sub new {
    my $class = shift;
    my(%options) = @_;

    my $self = {
        'verbose'        => 0,       # enable verbose output
        'logger'         => undef,   # logger object used for verbose output
        'log_string'     => undef,   # logs from string
        'log_livestatus' => undef,   # logs from a livestatus query
        'log_file'       => undef,   # logs from a file
        'log_dir'        => undef,   # logs from a dir
    };

    bless $self, $class;

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    # create an empty log store
    $self->{'logs'} = [];

    $self->{'xs'} = 0;
    eval {
        require Thruk::Utils::XS;
        Thruk::Utils::XS->import();
        $self->{'xs'} = 1;
    };

    # which source do we use?
    if(defined $self->{'log_string'}) {
        $self->_store_logs_from_string($self->{'log_string'});
    }
    if(defined $self->{'log_file'}) {
        $self->_store_logs_from_file($self->{'log_file'});
    }
    if(defined $self->{'log_dir'}) {
        $self->_store_logs_from_dir($self->{'log_dir'});
    }
    if(defined $self->{'log_livestatus'}) {
        $self->_store_logs_from_livestatus($self->{'log_livestatus'});
    }

    return $self;
}

########################################

=head1 METHODS

=head2 get_logs

 get_logs()

returns all read logs as array of hashrefs

=cut

sub get_logs {
    my $self = shift;
    return($self->{'logs'});
}

########################################

=head2 parse_line

 parse_line($line)

return parsed logfile line

=cut

sub parse_line {
    return if substr($_[0], 0, 1, '') ne '[';
    my $return = {
        'time' => substr($_[0], 0, 10, '')
    };
    substr($_[0], 0, 2, '');

    ($return->{'type'},$_[0]) = split(/:\ /mxo, $_[0], 2);
    if(!$_[0]) {
        # extract starts/stops
        &_set_from_type($return);
        return $return;
    }

    # extract more information from our options
    &_set_from_options($return->{'type'}, $return, $_[0]);

    return $return;
}

########################################
# INTERNAL SUBS
########################################
sub _store_logs_from_string {
    my($self, $string) = @_;
    return unless defined $string;
    my $parse_line = &parse_line;
    if($self->{xs}) {
        $parse_line = &Thruk::Utils::XS::parse_line;
    }
    for my $line (split/\n/mxo, $string) {
        my $data = &{$parse_line}($line);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    return 1;
}

########################################
sub _store_logs_from_file {
    my($self, $file) = @_;
    return unless defined $file;
    my $parse_line = &parse_line;
    if($self->{xs}) {
        $parse_line = &Thruk::Utils::XS::parse_line;
    }
    open(my $FH, '<', $file) or croak('cannot read file '.$file.': '.$!);
    binmode($FH);
    while(my $line = <$FH>) {
        &_decode_any($line);
        chomp($line);
        my $data = &{$parse_line}($line);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    close($FH);
    return 1;
}

########################################
sub _store_logs_from_dir {
    my($self, $dir) = @_;

    return unless defined $dir;

    opendir(my $dh, $dir) or croak('cannot open directory '.$dir.': '.$!);
    while(my $file = readdir($dh)) {
        if($file =~ m/\.log$/mxo) {
            $self->_store_logs_from_file($dir.'/'.$file);
        }
    }
    closedir $dh;

    return 1;
}

########################################
sub _store_logs_from_livestatus {
    my($self, $log_array) = @_;
    return unless defined $log_array;
    for my $entry (@{$log_array}) {
        my $data = $self->_parse_livestatus_entry($entry);
        push @{$self->{'logs'}}, $data if defined $data;
    }
    return 1;
}

########################################
sub _parse_livestatus_entry {
    my($self, $entry) = @_;

    my $string = $entry->{'message'} || $entry->{'options'} || '';
    if($string eq '') {
        # extract starts/stops
        &_set_from_type($entry, $string);
        return $entry;
    }

    my $parse_line = &parse_line;
    if($self->{xs}) {
        $parse_line = &Thruk::Utils::XS::parse_line;
    }

    # extract more information from our options
    if($entry->{'message'}) {
        return &{$parse_line}($string);
    } else {
        &_set_from_options($entry->{'type'}, $entry, $string);
    }

    return $entry;
}

########################################
sub _set_from_options {
    my($type, $data, $string) = @_;

    # Service States
    if(   $type eq 'SERVICE ALERT'
       or $type eq 'CURRENT SERVICE STATE'
       or $type eq 'INITIAL SERVICE STATE'
    ) {
        my @tmp = split(/;/mxo, $string,6); # regex is faster than strtok here
        $data->{'host_name'}           = $tmp[0];
        $data->{'service_description'} = $tmp[1];
        return unless defined $tmp[2];
        $data->{'state'}               = $Monitoring::Availability::Logs::service_states->{$tmp[2]};
        return unless defined $data->{'state'};
        $data->{'hard'}                = $tmp[3] eq 'HARD' ? 1 : 0;
        $data->{'plugin_output'}       = $tmp[5];
    }

    # Host States
    elsif(   $type eq 'HOST ALERT'
       or $type eq 'CURRENT HOST STATE'
       or $type eq 'INITIAL HOST STATE'
    ) {
        my @tmp = split(/;/mxo, $string,5); # regex is faster than strtok here
        $data->{'host_name'}     = $tmp[0];
        return unless defined $tmp[1];
        $data->{'state'}         = $Monitoring::Availability::Logs::host_states->{$tmp[1]};
        return unless defined $data->{'state'};
        $data->{'hard'}          = $tmp[2] eq 'HARD' ? 1 : 0;
        $data->{'plugin_output'} = $tmp[4];
    }


    # Host Downtimes
    elsif($type eq 'HOST DOWNTIME ALERT') {
        my @tmp = split(/;/mxo, $string,3); # regex is faster than strtok here
        $data->{'host_name'} = $tmp[0];
        $data->{'start'}     = $tmp[1] eq 'STARTED' ? 1 : 0;
    }

    # Service Downtimes
    elsif($type eq 'SERVICE DOWNTIME ALERT') {
        my @tmp = split(/;/mxo, $string,4); # regex is faster than strtok here
        $data->{'host_name'}           = $tmp[0];
        $data->{'service_description'} = $tmp[1];
        $data->{'start'}               = $tmp[2] eq 'STARTED' ? 1 : 0;
    }

    # Timeperiod Transitions
    # livestatus does not parse this correct, so we have to use regex
    elsif($type =~ m/^TIMEPERIOD\ TRANSITION/mxo) {
        my @tmp = split(/;/mxo, $string,3); # regex is faster than strtok here
        $data->{'type'}       = 'TIMEPERIOD TRANSITION';
        $data->{'timeperiod'} = $tmp[0];
        $data->{'from'}       = $tmp[1];
        $data->{'to'}         = $tmp[2];
        $data->{'timeperiod'} =~ s/^TIMEPERIOD\ TRANSITION:\ //mxo; # workaround for doubled string in logcache db
    }

    # Host States
    elsif($type eq 'HOST NOTIFICATION') {
        my @tmp = split(/;/mxo, $string,5); # regex is faster than strtok here
        $data->{'contact_name'}  = $tmp[0];
        $data->{'host_name'}     = $tmp[1];
        $data->{'plugin_output'} = $tmp[4];
    }

    # Service States
    elsif($type eq 'SERVICE NOTIFICATION') {
        my @tmp = split(/;/mxo, $string,6); # regex is faster than strtok here
        $data->{'contact_name'}         = $tmp[0];
        $data->{'host_name'}            = $tmp[1];
        $data->{'service_description'}  = $tmp[2];
        $data->{'plugin_output'}        = $tmp[5];
    }

    return 1;
}

########################################
sub _set_from_type {
    my($data) = @_;

    # program starts
    if($data->{'type'} =~ m/\ starting\.\.\./mxo) {
        $data->{'proc_start'} = START_NORMAL;
    }
    elsif($data->{'type'} =~ m/\ restarting\.\.\./mxo) {
        $data->{'proc_start'} = START_RESTART;
    }

    # program stops
    elsif($data->{'type'} =~ m/shutting\ down\.\.\./mxo) {
        $data->{'proc_start'} = STOP_NORMAL;
    }
    elsif($data->{'type'} =~ m/Bailing\ out/mxo) {
        $data->{'proc_start'} = STOP_ERROR;
    }

    return 1;
}

########################################
sub _decode_any {
    eval { $_[0] = decode( "utf8", $_[0], Encode::FB_CROAK ) };
    if ( $@ ) { # input was not utf8
        $_[0] = decode( "iso-8859-1", $_[0], Encode::FB_WARN );
    }
    return $_[0];
}

########################################

1;

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
