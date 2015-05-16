package Monitoring::Availability;

use 5.008;
use strict;
use warnings;
use Data::Dumper;
use Carp;
use POSIX qw(strftime mktime);
use File::Temp qw/tempfile/;
use Monitoring::Availability::Logs;

our $VERSION = '0.48';


=head1 NAME

Monitoring::Availability - Calculate Availability Data from
Nagios / Icinga and Shinken Logfiles.

=head1 SYNOPSIS

    use Monitoring::Availability;
    my $ma = Monitoring::Availability->new();

=head1 DESCRIPTION

This module calculates the availability for hosts/server from given logfiles.
The Logfileformat is Nagios/Icinga only.

=head1 REPOSITORY

    Git: http://github.com/sni/Monitoring-Availability

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Monitoring::Availability> object. C<new> takes at least the
logs parameter.  Arguments are in key-value pairs.

=over 4

=item rpttimeperiod

report timeperiod. defines a timeperiod for this report. Will use 24x7 if not
specified.

=item assumeinitialstates

Assume the initial host/service state if none is found, default: yes

=item assumestateretention

Assume state retention, default: yes

=item assumestatesduringnotrunning

Assume state during times when the monitoring process is not running, default: yes

=item includesoftstates

Include soft states in the calculation. Only hard states are used otherwise, default: no

=item initialassumedhoststate

Assumed host state if none is found, default: unspecified

valid options are: unspecified, current, up, down and unreachable

=item initialassumedservicestate

Assumed service state if none is found, default: unspecified

valid options are: unspecified, current, ok, warning, unknown and critical

=item backtrack

Go back this amount of days to find initial states, default: 4

=item showscheduleddowntime

Include downtimes in calculation, default: yes

=item timeformat

Time format for the log output, default: %s

=item verbose

verbose mode

=item breakdown

Breakdown availability into 'months', 'weeks', 'days', 'none'

adds additional 'breakdown' hash to each result with broken down results

=back

=cut

use constant {
    TRUE                => 1,
    FALSE               => 0,

    STATE_NOT_RUNNING   => -3,
    STATE_UNSPECIFIED   => -2,
    STATE_CURRENT       => -1,

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

    HOST_ONLY           => 2,
    SERVICE_ONLY        => 3,

    BREAK_NONE          => 0,
    BREAK_DAYS          => 1,
    BREAK_WEEKS         => 2,
    BREAK_MONTHS        => 3,
};

my $verbose = 0;
my $report_options_start;
my $report_options_end;
my $report_options_includesoftstates;
my $report_options_calc_all;
my $xs = 0;

sub new {
    my($class, %options) = @_;

    my $self = {
        'verbose'                        => 0,       # enable verbose output
        'logger'                         => undef,   # logger object used for verbose output
        'timeformat'                     => undef,
        'rpttimeperiod'                  => undef,
        'assumeinitialstates'            => undef,
        'assumestateretention'           => undef,
        'assumestatesduringnotrunning'   => undef,
        'includesoftstates'              => undef,
        'initialassumedhoststate'        => undef,
        'initialassumedservicestate'     => undef,
        'backtrack'                      => undef,
        'showscheduleddowntime'          => undef,
        'breakdown'                      => undef,
    };

    bless $self, $class;

    # verify the options we got so far
    $self = $self->_verify_options($self);

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    # translation hash
    $self->{'state_string_2_int'} = {
        'ok'          => STATE_OK,
        'warning'     => STATE_WARNING,
        'unknown'     => STATE_UNKNOWN,
        'critical'    => STATE_CRITICAL,
        'up'          => STATE_UP,
        'down'        => STATE_DOWN,
        'unreachable' => STATE_UNREACHABLE,
        '0'           => STATE_OK,
        '1'           => STATE_WARNING,
        '2'           => STATE_CRITICAL,
        '3'           => STATE_UNKNOWN,
    };

    $self->_log('initialized '.$class) if $self->{'verbose'};
    $self->_log($self)                 if $self->{'verbose'};

    eval {
        require Thruk::Utils::XS;
        Thruk::Utils::XS->import();
        $xs = 1;
    };

    return $self;
}


########################################

=head1 METHODS

=head2 calculate

 calculate()

Calculate the availability.

Returns hash with the availability.

=over 4

=item start

Timestamp of start

=item end

Timestamp of end

=item log_string

String containing the logs

=item log_file

File containing the logs

=item log_dir

Directory containing *.log files

=item log_livestatus

Array with logs from a livestatus query

 a sample query could be:
 selectall_arrayref(GET logs...\nColumns: time type options, {Slice => 1})

=item log_iterator

 Iterator object for logentry objects. For example a L<MongoDB::Cursor> object.

=item hosts

array with hostnames for which the report should be generated

=item services

array with hashes of services for which the report should be generated.
The array should look like this:

 [{host => 'hostname', service => 'description'}, ...]

=item initial_states

if you use the "current" option for initialassumedservicestate or initialassumedhoststate you
have to provide the current states with a hash like this:

  {
    hosts => {
     'hostname' => 'ok',
     ...
    },
    services => {
     'hostname' => {
         'description' =>  'warning',
         ...
      }
    }
  }

valid values for hosts are: up, down and unreachable

valid values for services are: ok, warning, unknown and critical

=back

=cut

sub calculate {
    my($self, %opts) = @_;

    # allow setting debug mode from env
    if(defined $ENV{'MONITORING_AVAILABILITY_DEBUG'}) {
        $self->{'verbose'} = 1;
    }

    # init log4perl, may require additional modules
    if($self->{'verbose'} && !defined $self->{'logger'}) {
        require Log::Log4perl;
        Log::Log4perl->import(qw(:easy));
        Log::Log4perl->easy_init({
            level   => 'DEBUG',
            file    => ">/tmp/Monitoring-Availability-Debug.log",
            utf8    => 1,
        });
        $self->{'logger'} = get_logger();
    }
    $verbose = $self->{'verbose'};

    # clean up namespace
    $self->_reset();

    $self->{'report_options'} = {
        'start'                          => undef,
        'end'                            => undef,
        'hosts'                          => [],
        'services'                       => [],
        'initial_states'                 => {},
        'log_string'                     => undef,   # logs from string
        'log_livestatus'                 => undef,   # logs from a livestatus query
        'log_file'                       => undef,   # logs from a file
        'log_dir'                        => undef,   # logs from a dir
        'log_iterator'                   => undef,   # logs from a iterator object
        'rpttimeperiod'                  => $self->{'rpttimeperiod'} || '',
        'assumeinitialstates'            => $self->{'assumeinitialstates'},
        'assumestateretention'           => $self->{'assumestateretention'},
        'assumestatesduringnotrunning'   => $self->{'assumestatesduringnotrunning'},
        'includesoftstates'              => $self->{'includesoftstates'},
        'initialassumedhoststate'        => $self->{'initialassumedhoststate'},
        'initialassumedservicestate'     => $self->{'initialassumedservicestate'},
        'backtrack'                      => $self->{'backtrack'},
        'showscheduleddowntime'          => $self->{'showscheduleddowntime'},
        'timeformat'                     => $self->{'timeformat'},
        'breakdown'                      => $self->{'breakdown'},
    };
    my $result;

    for my $opt_key (keys %opts) {
        if(exists $self->{'report_options'}->{$opt_key}) {
            $self->{'report_options'}->{$opt_key} = $opts{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    $self->{'report_options'} = $self->_set_default_options($self->{'report_options'});
    $self->{'report_options'} = $self->_verify_options($self->{'report_options'});

    $self->_log('calculate()')             if $verbose;
    $self->_log($self->{'report_options'}) if $verbose;

    # create lookup hash for faster access
    $result->{'hosts'}    = {};
    $result->{'services'} = {};
    for my $host (@{$self->{'report_options'}->{'hosts'}}) {
        $result->{'hosts'}->{$host} = 1;
    }
    for my $service (@{$self->{'report_options'}->{'services'}}) {
        if(ref $service ne 'HASH') {
            croak("services have to be an array of hashes, for example: [{host => 'hostname', service => 'description'}, ...]\ngot: ".Dumper($service));
        }
        if(!defined $service->{'host'} || !defined $service->{'service'}) {
            croak("services have to be an array of hashes, for example: [{host => 'hostname', service => 'description'}, ...]\ngot: ".Dumper($service));
        }
        $result->{'services'}->{$service->{'host'}}->{$service->{'service'}} = 1;
    }

    # if we have more than one host or service, we dont build up a log
    $self->{'report_options'}->{'build_log'} = TRUE;
    if(scalar @{$self->{'report_options'}->{'hosts'}} == 1) {
        $self->{'report_options'}->{'build_log'} = HOST_ONLY;
    }
    elsif(scalar @{$self->{'report_options'}->{'services'}} == 1) {
        $self->{'report_options'}->{'build_log'} = SERVICE_ONLY;
    }

    $self->{'report_options'}->{'calc_all'} = FALSE;
    if(scalar keys %{$result->{'services'}} == 0 and scalar keys %{$result->{'hosts'}} == 0) {
        $self->_log('will calculate availability for all hosts/services found') if $verbose;
        $self->{'report_options'}->{'calc_all'} = TRUE;
    }

    $self->_set_breakpoints();

    unless($self->{'report_options'}->{'calc_all'}) {
        $self->_set_empty_hosts($result);
        $self->_set_empty_services($result);
    }

    # set some variables for faster access
    $report_options_start             = $self->{'report_options'}->{'start'};
    $report_options_end               = $self->{'report_options'}->{'end'};
    $report_options_includesoftstates = $self->{'report_options'}->{'includesoftstates'};
    $report_options_calc_all          = $self->{'report_options'}->{'calc_all'};

    # read in logs
    if($self->{'report_options'}->{'log_file'} && !$self->{'report_options'}->{'log_string'} && !$self->{'report_options'}->{'log_dir'}) {
        # single file can be read line by line to save memory
        $self->_compute_availability_line_by_line($result, $self->{'report_options'}->{'log_file'});
    }
    elsif(defined $self->{'report_options'}->{'log_string'} || $self->{'report_options'}->{'log_file'} || $self->{'report_options'}->{'log_dir'}) {
        my $mal = Monitoring::Availability::Logs->new(
            'log_string'        => $self->{'report_options'}->{'log_string'},
            'log_file'          => $self->{'report_options'}->{'log_file'},
            'log_dir'           => $self->{'report_options'}->{'log_dir'},
        );
        my $logs = $mal->get_logs();
        $self->_compute_availability_from_log_store($result, $logs);
    }
    elsif(defined $self->{'report_options'}->{'log_livestatus'}) {
        $self->_compute_availability_on_the_fly($result, $self->{'report_options'}->{'log_livestatus'});
    }
    elsif(defined $self->{'report_options'}->{'log_iterator'}) {
        $self->_compute_availability_from_iterator($result, $self->{'report_options'}->{'log_iterator'});
    }
    return($result);
}


########################################

=head2 get_condensed_logs

 get_condensed_logs()

returns an array of hashes with the condensed log used for this report

=cut

sub get_condensed_logs {
    my $self = shift;

    return if $self->{'report_options'}->{'build_log'} == FALSE;

    $self->_calculate_log() unless $self->{'log_output_calculated'};

    return $self->{'log_output'};
}


########################################

=head2 get_full_logs

 get_full_logs()

returns an array of hashes with the full log used for this report

=cut

sub get_full_logs {
    my $self = shift;

    return if $self->{'report_options'}->{'build_log'} == FALSE;

    $self->_calculate_log() unless $self->{'log_output_calculated'};

    return $self->{'full_log_output'};
}


########################################
# INTERNAL SUBS
########################################
sub _reset {
    my $self   = shift;
    $self->_log('_reset()') if $verbose;

    undef $self->{'full_log_store'};
    $self->{'full_log_store'} = [];

    delete $self->{'first_known_state_before_report'};
    delete $self->{'first_known_proc_before_report'};
    delete $self->{'log_output_calculated'};

    delete $self->{'report_options'};
    delete $self->{'full_log_output'};
    delete $self->{'log_output'};

    return 1;
}

########################################
sub _set_empty_hosts {
    my $self    = shift;
    my $data    = shift;

    my $initial_assumend_state = STATE_UNSPECIFIED;
    if($self->{'report_options'}->{'assumeinitialstates'}) {
        $initial_assumend_state = $self->{'report_options'}->{'initialassumedhoststate'};
    }

    $self->_log('_set_empty_hosts()') if $verbose;
    for my $hostname (keys %{$data->{'hosts'}}) {
        my $first_state = $initial_assumend_state;
        if($initial_assumend_state == STATE_CURRENT) {
            eval { $first_state = $self->_state_to_int($self->{'report_options'}->{'initial_states'}->{'hosts'}->{$hostname}); };
            if($@) { croak("found no initial state for host '$hostname'\ngot: ".Dumper($self->{'report_options'}->{'initial_states'}).Dumper($@)); }
            $self->{'report_options'}->{'first_state'} = $first_state;
        }
        $data->{'hosts'}->{$hostname} = $self->_new_host_data($self->{'report_options'}->{'breakdown'});
        $self->{'host_data'}->{$hostname} = {
            'in_downtime'      => 0,
            'last_state'       => $initial_assumend_state,
            'last_known_state' => undef,
            'last_state_time'  => 0,
        };
    }
    return 1;
}

########################################
sub _set_empty_services {
    my $self    = shift;
    my $data    = shift;
    $self->_log('_set_empty_services()') if $verbose;

    my $initial_assumend_state      = STATE_UNSPECIFIED;
    my $initial_assumend_host_state = STATE_UNSPECIFIED;
    if($self->{'report_options'}->{'assumeinitialstates'}) {
        $initial_assumend_state      = $self->{'report_options'}->{'initialassumedservicestate'};
        $initial_assumend_host_state = $self->{'report_options'}->{'initialassumedhoststate'};
    }

    for my $hostname (keys %{$data->{'services'}}) {
        for my $service_description (keys %{$data->{'services'}->{$hostname}}) {
            my $first_state = $initial_assumend_state;
            if($initial_assumend_state == STATE_CURRENT) {
                eval { $first_state = $self->_state_to_int($self->{'report_options'}->{'initial_states'}->{'services'}->{$hostname}->{$service_description}); };
                if($@) { croak("found no initial state for service '$service_description' on host '$hostname'\ngot: ".Dumper($self->{'report_options'}->{'initial_states'}).Dumper($@)); }
                $self->{'report_options'}->{'first_state'} = $first_state;
            }
            $data->{'services'}->{$hostname}->{$service_description} = $self->_new_service_data($self->{'report_options'}->{'breakdown'});

            # create last service data
            $self->{'service_data'}->{$hostname}->{$service_description} = {
                'in_downtime'      => 0,
                'last_state'       => $first_state,
                'last_known_state' => undef,
                'last_state_time'  => 0,
            };
        }
        my $first_host_state = $initial_assumend_host_state;
        if($initial_assumend_host_state == STATE_CURRENT) {
            eval { $first_host_state = $self->_state_to_int($self->{'report_options'}->{'initial_states'}->{'hosts'}->{$hostname}); };
            if($@) { $first_host_state = STATE_UNSPECIFIED; }
        }
        $self->{'host_data'}->{$hostname} = {
            'in_downtime'      => 0,
            'last_state'       => $first_host_state,
            'last_known_state' => undef,
            'last_state_time'  => 0,
        };
    }
    return 1;
}

########################################
sub _compute_for_data {
    my($self, $last_time, $data, $result) = @_;

    # if we reach the start date of our report, insert a fake entry
    if($last_time < $report_options_start and $data->{'time'} >= $report_options_start) {
        $self->_insert_fake_event($result, $report_options_start);

        # insert another fake event with current timeperiod state
        if($self->{'report_options'}->{'rpttimeperiod'} and defined $self->{'in_timeperiod'}) {
            # set a log entry
            my $start         = 'STOP';
            my $plugin_output = 'leaving timeperiod: '.$self->{'report_options'}->{'rpttimeperiod'};
            if($self->{'in_timeperiod'}) {
                $plugin_output = 'entering timeperiod: '.$self->{'report_options'}->{'rpttimeperiod'};
                $start         = 'START';
            }
            $self->_add_log_entry(
                            'log'         => {
                                'start'         => $report_options_start,
                                'type'          => 'TIMEPERIOD '.$start,
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        }
    }

    # if we passed a breakdown point, insert fake event
    if($self->{'report_options'}->{'breakdown'} != BREAK_NONE) {
        my $breakpoint = $self->{'breakpoints'}->[0];
        while(defined $breakpoint and $last_time < $breakpoint and $data->{'time'} >= $breakpoint) {
            $self->_log('_compute_for_data(): inserted breakpoint: '.$breakpoint." (".scalar localtime($breakpoint).")") if $verbose;
            $self->_insert_fake_event($result, $breakpoint);
            shift(@{$self->{'breakpoints'}});
            $breakpoint = $self->{'breakpoints'}->[0];
        }
    }

    # end of report reached, insert fake end event
    if($data->{'time'} >= $report_options_end and $last_time < $report_options_end) {
        $self->_insert_fake_event($result, $report_options_end);

        # set a log entry
        $self->_add_log_entry(
                        'full_only'   => 1,
                        'log'         => {
                            'start'         => $report_options_end,
                        },
        ) unless defined $data->{'fake'};
    }

    # now process the real line
    &_process_log_line($self,$result, $data) unless defined $data->{'fake'};

    return 1;
}

########################################
sub _compute_availability_line_by_line {
    my($self,$result,$file) = @_;

    if($verbose) {
        $self->_log('_compute_availability_line_by_line()');
        $self->_log('_compute_availability_line_by_line() report start: '.(scalar localtime $self->{'report_options'}->{'start'}));
        $self->_log('_compute_availability_line_by_line() report end:   '.(scalar localtime $self->{'report_options'}->{'end'}));
    }

    my $last_time = -1;

    chomp(my $total = `wc -l $file`);
    $total =~ s/^(\d+)\s.*$/$1/mx;

    open(my $fh, '<', $file) or die("cannot read ".$file.": ".$!);
    binmode($fh);

    # process all log lines we got
    # logs should be sorted already
    my $count     = 0;
    my $last_perc = 35;  # our range is from 35% - 75%
    my $started   = time();
    while(my $line = <$fh>) {
        $count++;
        my $data;
        &Monitoring::Availability::Logs::_decode_any($line);
        chomp($line);
        if($xs) {
            $data = &Thruk::Utils::XS::parse_line($line);
        } else {
            $data = &Monitoring::Availability::Logs::parse_line($line);
        }
        next unless $data;
        &_compute_for_data($self,$last_time, $data, $result);
        # set timestamp of last log line
        $last_time = $data->{'time'};

        if($count%10 == 0 && $ENV{'THRUK_JOB_DIR'}) {
            my $perc = int(($count / $total * 40) + 35);
            if($perc != $last_perc) {
                my $elapsed = time() - $started;
                my $remaining_seconds = int(($elapsed) / ($count / $total)) - $elapsed;
                Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, $perc, 'calculating', $remaining_seconds);
            }
            $last_perc = $perc;
        }
    }
    close($fh);

    $self->_add_last_time_event($last_time, $result);

    return 1;
}


########################################
sub _compute_availability_from_iterator {
    my $self    = shift;
    my $result  = shift;
    my $logs    = shift;

    if($verbose) {
        $self->_log('_compute_availability_from_iterator()');
        $self->_log('_compute_availability_from_iterator() report start: '.(scalar localtime $self->{'report_options'}->{'start'}));
        $self->_log('_compute_availability_from_iterator() report end:   '.(scalar localtime $self->{'report_options'}->{'end'}));
    }

    my $last_time = -1;
    # no logs at all?
    unless($logs->has_next) {
        &_compute_for_data($self, -1,
                                 {time => $self->{'report_options'}->{'end'}, fake => 1},
                                 $result);
        $last_time = $self->{'report_options'}->{'end'};
    }

    # process all log lines we got
    # logs should be sorted already
    while(my $data = $logs->next) {
        &_compute_for_data($self, $last_time,
                                 &Monitoring::Availability::Logs::_parse_livestatus_entry($data),
                                 $result);

        # set timestamp of last log line
        $last_time = $data->{'time'};
    }

    # processing logfiles finished

    $self->_add_last_time_event($last_time, $result);

    return 1;
}


########################################
sub _compute_availability_on_the_fly {
    my($self, $result, $logs) = @_;

    if($verbose) {
        $self->_log('_compute_availability_on_the_fly()');
        $self->_log('_compute_availability_on_the_fly() report start: '.(scalar localtime $self->{'report_options'}->{'start'}));
        $self->_log('_compute_availability_on_the_fly() report end:   '.(scalar localtime $self->{'report_options'}->{'end'}));
        $self->_log('_compute_availability_on_the_fly() log size:     '.(scalar @{$logs}));
    }

    my $last_time = -1;
    if(scalar @{$logs} == 0) {
        &_compute_for_data($self, -1,
                                 {time => $self->{'report_options'}->{'end'}, fake => 1},
                                 $result);
        $last_time = $self->{'report_options'}->{'end'};
    }

    # process all log lines we got
    # make sure our logs are sorted by time
    for my $data ( sort { $a->{'time'} <=> $b->{'time'} } @{$logs} ) {
        eval {
            if($xs) {
                &_compute_for_data($self, $last_time,
                                         &Thruk::Utils::XS::parse_line($data->{'message'}),
                                         $result);
            } else {
                &_compute_for_data($self, $last_time,
                                         &Monitoring::Availability::Logs::_parse_livestatus_entry($data),
                                         $result);
            }
            # set timestamp of last log line
            $last_time = $data->{'time'};
        };
        $self->_log('_compute_availability_on_the_fly(): '.$@) if $@ and $verbose;
    }

    # processing logfiles finished

    $self->_add_last_time_event($last_time, $result);

    return 1;
}


########################################
sub _compute_availability_from_log_store {
    my $self    = shift;
    my $result  = shift;
    my $logs    = shift;

    if($verbose) {
        $self->_log('_compute_availability_from_log_store()');
        $self->_log('_compute_availability_from_log_store() report start: '.(scalar localtime $self->{'report_options'}->{'start'}));
        $self->_log('_compute_availability_from_log_store() report end:   '.(scalar localtime $self->{'report_options'}->{'end'}));
    }

    # make sure our logs are sorted by time
    @{$logs} = sort { $a->{'time'} <=> $b->{'time'} } @{$logs};

    $self->_log('_compute_availability_from_log_store() sorted logs') if $verbose;

    # process all log lines we got
    my $last_time = -1;
    for my $data (@{$logs}) {

        &_compute_for_data($self, $last_time, $data, $result);

        # set timestamp of last log line
        $last_time = $data->{'time'};
    }

    # processing logfiles finished

    $self->_add_last_time_event($last_time, $result);

    return 1;
}


########################################
sub _add_last_time_event {
    my($self, $last_time, $result) = @_;

    # no start event yet, insert a fake entry
    if($last_time < $self->{'report_options'}->{'start'}) {
        $self->_insert_fake_event($result, $self->{'report_options'}->{'start'});
    }

    # breakpoints left?
    my $breakpoint = $self->{'breakpoints'}->[0];
    while(defined $breakpoint) {
        $self->_log('_add_last_time_event(): inserted breakpoint: '.$breakpoint." (".scalar localtime($breakpoint).")") if $verbose;
        $self->_insert_fake_event($result, $breakpoint);
        shift(@{$self->{'breakpoints'}});
        $breakpoint = $self->{'breakpoints'}->[0];
    }


    # no end event yet, insert fake end event
    if($last_time < $self->{'report_options'}->{'end'}) {
        $self->_insert_fake_event($result, $self->{'report_options'}->{'end'});
    }

    return 1;
}

########################################
sub _process_log_line {
    my($self, $result, $data) = @_;

    if($verbose) {
        $self->_log('#######################################');
        $self->_log('_process_log_line() at '.(scalar localtime $data->{'time'}));
        $self->_log($data);
    }

    # only hard states?
    if(exists $data->{'hard'} && !$report_options_includesoftstates && $data->{'hard'} != 1) {
        $self->_log('  -> skipped soft state') if $verbose;
        return;
    }

    # process starts / stops?
    if(defined $data->{'proc_start'}) {
        unless($self->{'report_options'}->{'assumestatesduringnotrunning'}) {
            if($data->{'proc_start'} == START_NORMAL or $data->{'proc_start'} == START_RESTART) {
                # set an event for all services and set state to no_data
                $self->_log('_process_log_line() process start, inserting fake event for all services') if $verbose;
                for my $host_name (keys %{$self->{'service_data'}}) {
                    for my $service_description (keys %{$self->{'service_data'}->{$host_name}}) {
                        my $last_known_state = $self->{'service_data'}->{$host_name}->{$service_description}->{'last_known_state'};
                        my $last_state = STATE_UNSPECIFIED;
                        $last_state = $last_known_state if(defined $last_known_state and $last_known_state >= 0);
                        &_set_service_event($self, $host_name, $service_description, $result, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'}, 'state' => $last_state });
                    }
                }
                for my $host_name (keys %{$self->{'host_data'}}) {
                    my $last_known_state = $self->{'host_data'}->{$host_name}->{'last_known_state'};
                    my $last_state = STATE_UNSPECIFIED;
                    $last_state = $last_known_state if(defined $last_known_state and $last_known_state >= 0);
                    &_set_host_event($self, $host_name, $result, { 'time' => $data->{'time'}, 'state' => $last_state });
                }
            } else {
                # set an event for all services and set state to not running
                $self->_log('_process_log_line() process stop, inserting fake event for all services') if $verbose;
                for my $host_name (keys %{$self->{'service_data'}}) {
                    for my $service_description (keys %{$self->{'service_data'}->{$host_name}}) {
                        &_set_service_event($self, $host_name, $service_description, $result, { 'time' => $data->{'time'}, 'state' => STATE_NOT_RUNNING });
                    }
                }
                for my $host_name (keys %{$self->{'host_data'}}) {
                    &_set_host_event($self, $host_name, $result, { 'time' => $data->{'time'}, 'state' => STATE_NOT_RUNNING });
                }
            }
        }
        # set a log entry
        if($data->{'proc_start'} == START_NORMAL or $data->{'proc_start'} == START_RESTART) {
            my $plugin_output = 'Program start';
               $plugin_output = 'Program restart' if $data->{'proc_start'} == START_RESTART;
            $self->_add_log_entry(
                            'full_only'  => 1,
                            'proc_start' => $data->{'proc_start'},
                            'log'        => {
                                'start'         => $data->{'time'},
                                'type'          => 'PROGRAM (RE)START',
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        } else {
            my $plugin_output = 'Normal program termination';
            $plugin_output    = 'Abnormal program termination' if $data->{'proc_start'} == STOP_ERROR;
            $self->_add_log_entry(
                            'full_only'  => 1,
                            'log'        => {
                                'start'         => $data->{'time'},
                                'type'          => 'PROGRAM END',
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        }
        return;
    }

    # timeperiod transitions
    elsif(defined $data->{'timeperiod'}) {
        if($self->{'report_options'}->{'rpttimeperiod'} eq $data->{'timeperiod'} ) {
            $self->_log('_process_log_line() timeperiod translation, inserting fake event for all hosts/services') if $verbose;
            for my $host_name (keys %{$self->{'service_data'}}) {
                for my $service_description (keys %{$self->{'service_data'}->{$host_name}}) {
                    my $last_known_state = $self->{'service_data'}->{$host_name}->{$service_description}->{'last_known_state'};
                    my $last_state = STATE_UNSPECIFIED;
                    $last_state = $last_known_state if(defined $last_known_state and $last_known_state >= 0);
                    &_set_service_event($self, $host_name, $service_description, $result, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'}, 'state' => $last_state });
                }
            }
            for my $host_name (keys %{$self->{'host_data'}}) {
                my $last_known_state = $self->{'host_data'}->{$host_name}->{'last_known_state'};
                my $last_state = STATE_UNSPECIFIED;
                $last_state = $last_known_state if(defined $last_known_state and $last_known_state >= 0);
                &_set_host_event($self,$host_name, $result, { 'time' => $data->{'time'}, 'state' => $last_state });
            }
            $self->{'in_timeperiod'} = $data->{'to'};

            # set a log entry
            my $start         = 'STOP';
            my $plugin_output = 'leaving timeperiod: '.$data->{'timeperiod'};
            if($self->{'in_timeperiod'}) {
                $plugin_output = 'entering timeperiod: '.$data->{'timeperiod'};
                $start         = 'START';
            }
            $self->_add_log_entry(
                            'log'         => {
                                'start'         => $data->{'time'},
                                'type'          => 'TIMEPERIOD '.$start,
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                            },
            );
        }
        return;
    }

    # skip hosts we dont need
    if($report_options_calc_all == FALSE && defined $data->{'host_name'} && !defined $self->{'host_data'}->{$data->{'host_name'}} && !defined $self->{'service_data'}->{$data->{'host_name'}}) {
        $self->_log('  -> skipped not needed host event') if $verbose;
        return;
    }

    # skip services we dont need
    if($report_options_calc_all == FALSE
       && $data->{'host_name'}
       && $data->{'service_description'}
       && !defined $self->{'service_data'}->{$data->{'host_name'}}->{$data->{'service_description'}}
      ) {
        $self->_log('  -> skipped not needed service event') if $verbose;
        return;
    }

    # service events
    if($data->{'service_description'}) {
        my $service_hist = $self->{'service_data'}->{$data->{'host_name'}}->{$data->{'service_description'}};

        if($data->{'type'} eq 'CURRENT SERVICE STATE' or $data->{'type'} eq 'SERVICE ALERT' or $data->{'type'} eq 'INITIAL SERVICE STATE') {
            &_set_service_event($self,$data->{'host_name'}, $data->{'service_description'}, $result, $data);

            # set a log entry
            my $state_text;
            if(   $data->{'state'} == STATE_OK     )  { $state_text = "OK";       }
            elsif($data->{'state'} == STATE_WARNING)  { $state_text = "WARNING";  }
            elsif($data->{'state'} == STATE_UNKNOWN)  { $state_text = "UNKNOWN";  }
            elsif($data->{'state'} == STATE_CRITICAL) { $state_text = "CRITICAL"; }
            if(defined $state_text) {
                my $hard = "";
                $hard = " (HARD)" if $data->{'hard'};
                $self->_add_log_entry(
                            'log' => {
                                'start'         => $data->{'time'},
                                'type'          => 'SERVICE '.$state_text.$hard,
                                'plugin_output' => $data->{'plugin_output'},
                                'class'         => $state_text,
                                'in_downtime'   => $service_hist->{'in_downtime'},
                                'host'          => $data->{'host_name'},
                                'service'       => $data->{'service_description'},
                            },
                ) unless $self->{'report_options'}->{'build_log'} == HOST_ONLY;
            }
        }
        elsif($data->{'type'} eq 'SERVICE DOWNTIME ALERT') {
            return unless $self->{'report_options'}->{'showscheduleddowntime'};

            undef $data->{'state'}; # we dont know the current state, so make sure it wont be overwritten
            &_set_service_event($self,$data->{'host_name'}, $data->{'service_description'}, $result, $data);

            my $start;
            my $plugin_output;
            if($data->{'start'}) {
                $start = "START";
                $plugin_output = 'Start of scheduled downtime';
                $service_hist->{'in_downtime'} = 1;
            }
            else {
                $start = "END";
                $plugin_output = 'End of scheduled downtime';
                $service_hist->{'in_downtime'} = 0;
            }

            # set a log entry
            $self->_add_log_entry(
                            'log'         => {
                                'start'         => $data->{'time'},
                                'type'          => 'SERVICE DOWNTIME '.$start,
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                                'in_downtime'   => $service_hist->{'in_downtime'},
                                'host'          => $data->{'host_name'},
                                'service'       => $data->{'service_description'},
                            },
            ) unless $self->{'report_options'}->{'build_log'} == HOST_ONLY;
        }
        else {
            $self->_log('  -> unknown log type') if $verbose;
        }
    }

    # host events
    elsif(defined $data->{'host_name'}) {
        my $host_hist = $self->{'host_data'}->{$data->{'host_name'}};

        if($data->{'type'} eq 'CURRENT HOST STATE' or $data->{'type'} eq 'HOST ALERT' or $data->{'type'} eq 'INITIAL HOST STATE') {
            # skip unwanted host events
            return unless($report_options_calc_all == TRUE or defined $result->{'hosts'}->{$data->{'host_name'}});

            &_set_host_event($self,$data->{'host_name'}, $result, $data);

            # set a log entry
            my $state_text;
            if(   $data->{'state'} == STATE_UP)          { $state_text = "UP"; }
            elsif($data->{'state'} == STATE_DOWN)        { $state_text = "DOWN"; }
            elsif($data->{'state'} == STATE_UNREACHABLE) { $state_text = "UNREACHABLE"; }
            if(defined $state_text) {
                my $hard = "";
                $hard = " (HARD)" if $data->{'hard'};
                $self->_add_log_entry(
                            'log' => {
                                'start'         => $data->{'time'},
                                'type'          => 'HOST '.$state_text.$hard,
                                'plugin_output' => $data->{'plugin_output'},
                                'class'         => $state_text,
                                'in_downtime'   => $host_hist->{'in_downtime'},
                                'host'          => $data->{'host_name'},
                            },
                );
            }
        }
        elsif($data->{'type'} eq 'HOST DOWNTIME ALERT') {
            return unless $self->{'report_options'}->{'showscheduleddowntime'};

            my $last_state_time = $host_hist->{'last_state_time'};

            $self->_log('_process_log_line() hostdowntime, inserting fake event for all hosts/services') if $verbose;
            # set an event for all services
            for my $service_description (keys %{$self->{'service_data'}->{$data->{'host_name'}}}) {
                $last_state_time = $self->{'service_data'}->{$data->{'host_name'}}->{$service_description}->{'last_state_time'};
                &_set_service_event($self, $data->{'host_name'}, $service_description, $result, { 'start' => $data->{'start'}, 'end' => $data->{'end'}, 'time' => $data->{'time'} });
            }

            undef $data->{'state'}; # we dont know the current state, so make sure it wont be overwritten

            # set the host event itself
            &_set_host_event($self,$data->{'host_name'}, $result, $data);

            my $start;
            my $plugin_output;
            if($data->{'start'}) {
                $start = "START";
                $plugin_output = 'Start of scheduled downtime';
                $host_hist->{'in_downtime'} = 1;
            }
            else {
                $start = "STOP";
                $plugin_output = 'End of scheduled downtime';
                $host_hist->{'in_downtime'} = 0;
            }

            # set a log entry
            $self->_add_log_entry(
                            'log'         => {
                                'start'         => $data->{'time'},
                                'type'          => 'HOST DOWNTIME '.$start,
                                'plugin_output' => $plugin_output,
                                'class'         => 'INDETERMINATE',
                                'in_downtime'   => $host_hist->{'in_downtime'},
                                'host'          => $data->{'host_name'},
                            },
            );
        }
        else {
            $self->_log('  -> unknown log type') if $verbose;
        }
    }
    else {
        $self->_log('  -> unknown log type') if $verbose;
    }

    return 1;
}


########################################
sub _set_service_event {
    my($self, $host_name, $service_description, $result, $data) = @_;

    $self->_log('_set_service_event()') if $verbose;

    my $host_hist    = $self->{'host_data'}->{$host_name};
    my $service_hist = $self->{'service_data'}->{$host_name}->{$service_description};
    my $service_data = $result->{'services'}->{$host_name}->{$service_description};

    # check if we are inside the report time
    if($report_options_start < $data->{'time'} && $report_options_end >= $data->{'time'}) {
        # we got a last state?
        if(defined $service_hist->{'last_state'}) {
            my $diff = $data->{'time'} - $service_hist->{'last_state_time'};
            if($diff < 0) {
                #die("report failed, debug data is available in ".$self->_write_debug_file("added negative time"));
                $diff = 0;
            }
            # outside timeperiod
            if(defined $self->{'in_timeperiod'} && !$self->{'in_timeperiod'}) {
                $self->_add_time($service_data, $data->{'time'}, 'time_indeterminate_outside_timeperiod', $diff);
            }

            # ok
            elsif($service_hist->{'last_state'} == STATE_OK) {
                $self->_add_time($service_data, $data->{'time'}, 'time_ok', $diff, ($service_hist->{'in_downtime'} or $host_hist->{'in_downtime'}));
            }

            # warning
            elsif($service_hist->{'last_state'} == STATE_WARNING) {
                $self->_add_time($service_data, $data->{'time'}, 'time_warning', $diff, ($service_hist->{'in_downtime'} or $host_hist->{'in_downtime'}));
            }

            # critical
            elsif($service_hist->{'last_state'} == STATE_CRITICAL) {
                $self->_add_time($service_data, $data->{'time'}, 'time_critical', $diff, ($service_hist->{'in_downtime'} or $host_hist->{'in_downtime'}));
            }

            # unknown
            elsif($service_hist->{'last_state'} == STATE_UNKNOWN) {
                $self->_add_time($service_data, $data->{'time'}, 'time_unknown', $diff, ($service_hist->{'in_downtime'} or $host_hist->{'in_downtime'}));
            }

            # no data yet
            elsif($service_hist->{'last_state'} == STATE_UNSPECIFIED) {
                $self->_add_time($service_data, $data->{'time'}, 'time_indeterminate_nodata', $diff, ($service_hist->{'in_downtime'} or $host_hist->{'in_downtime'}), 'scheduled_time_indeterminate');
            }

            # not running
            elsif($service_hist->{'last_state'} == STATE_NOT_RUNNING) {
                $self->_add_time($service_data, $data->{'time'}, 'time_indeterminate_notrunning', $diff);
            }

        }
    }

    # set last state
    if(defined $data->{'state'}) {
        $self->_log('_set_service_event() set last state = '.$data->{'state'}) if $verbose;
        $service_hist->{'last_state'}       = $data->{'state'};
        $service_hist->{'last_known_state'} = $data->{'state'} if $data->{'state'} >= 0;
    }

    $service_hist->{'last_state_time'} = $data->{'time'};

    return 1;
}


########################################
sub _set_host_event {
    my($self, $host_name, $result, $data) = @_;

    $self->_log('_set_host_event()') if $verbose;

    my $host_hist = $self->{'host_data'}->{$host_name};
    my $host_data = $result->{'hosts'}->{$host_name};

    # check if we are inside the report time
    if($report_options_start < $data->{'time'} && $report_options_end >= $data->{'time'}) {
        # we got a last state?
        if(defined $host_hist->{'last_state'}) {
            my $diff = $data->{'time'} - $host_hist->{'last_state_time'};

            # outside timeperiod
            if(defined $self->{'in_timeperiod'} && !$self->{'in_timeperiod'}) {
                $self->_add_time($host_data, $data->{'time'}, 'time_indeterminate_outside_timeperiod', $diff);
            }

            # up
            elsif($host_hist->{'last_state'} == STATE_UP) {
                $self->_add_time($host_data, $data->{'time'}, 'time_up', $diff, $host_hist->{'in_downtime'});
            }

            # down
            elsif($host_hist->{'last_state'} == STATE_DOWN) {
                $self->_add_time($host_data, $data->{'time'}, 'time_down', $diff, $host_hist->{'in_downtime'});
            }

            # unreachable
            elsif($host_hist->{'last_state'} == STATE_UNREACHABLE) {
                $self->_add_time($host_data, $data->{'time'}, 'time_unreachable', $diff, $host_hist->{'in_downtime'});
            }

            # no data yet
            elsif($host_hist->{'last_state'} == STATE_UNSPECIFIED) {
                $self->_add_time($host_data, $data->{'time'}, 'time_indeterminate_nodata', $diff, $host_hist->{'in_downtime'}, 'scheduled_time_indeterminate');
            }

            # not running
            elsif($host_hist->{'last_state'} == STATE_NOT_RUNNING) {
                $self->_add_time($host_data, $data->{'time'}, 'time_indeterminate_notrunning', $diff);
            }
        }
    }

    # set last state
    if(defined $data->{'state'}) {
        $self->_log('_set_host_event() set last state = '.$data->{'state'}) if $verbose;
        $host_hist->{'last_state'}       = $data->{'state'};
        $host_hist->{'last_known_state'} = $data->{'state'} if $data->{'state'} >= 0;
    }
    $host_hist->{'last_state_time'} = $data->{'time'};

    return 1;
}

########################################
sub _add_time {
    my($self, $data, $date, $type, $diff, $in_downtime, $scheduled_type) = @_;
    $scheduled_type = 'scheduled_'.$type unless defined $scheduled_type;
    $self->_log('_add_time() '.$type.' + '.$diff.' seconds ('.$self->_duration($diff).')') if $verbose;
    $data->{$type} += $diff;
    if($in_downtime) {
        $self->_log('_add_time() '.$type.' scheduled + '.$diff.' seconds') if $verbose;
        $data->{$scheduled_type} += $diff;
    }

    # breakdowns?
    if($self->{'report_options'}->{'breakdown'} != BREAK_NONE) {
        my $timestr = $self->_get_break_timestr($date-1);
        $data->{'breakdown'}->{$timestr}->{$type} += $diff;
        $self->_log('_add_time() breakdown('.$timestr.') '.$type.' + '.$diff.' seconds ('.$self->_duration($diff).')') if $verbose;
        if($in_downtime) {
            $self->_log('_add_time() breakdown('.$timestr.') '.$type.' scheduled + '.$diff.' seconds ('.$self->_duration($diff).')') if $verbose;
            $data->{'breakdown'}->{$timestr}->{$scheduled_type} += $diff;
        }
    }
    return;
}


########################################
sub _log {
    my($self, $text) = @_;
    return 1 unless $verbose;

    if(ref $text ne '') {
        $Data::Dumper::Sortkeys = \&_logging_filter;
        $text = Dumper($text);
    }
    $self->{'logger'}->debug($text);

    return 1;
}

########################################
sub _logging_filter {
    my ($hash) = @_;
    my @keys = keys %{$hash};
    # filter a few keys we don't want to log
    @keys = grep {!/^(state_string_2_int
                      |logger
                      |peer_addr
                      |peer_name
                      |peer_key
                      |log_string
                      |log_livestatus
                      |log_file
                      |log_dir
                      |log_iterator
                      |current_host_groups
                )$/mx} @keys;
    return \@keys;
}
##############################################
# calculate a duration in the
# format: 0d 0h 29m 43s
sub _duration {
    my($self, $duration) = @_;

    croak("undef duration in duration(): ".$duration) unless defined $duration;
    $duration = $duration * -1 if $duration < 0;

    if($duration < 0) { $duration = time() + $duration; }

    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($duration >= 86400) {
        $days     = int($duration/86400);
        $duration = $duration%86400;
    }
    if($duration >= 3600) {
        $hours    = int($duration/3600);
        $duration = $duration%3600;
    }
    if($duration >= 60) {
        $minutes  = int($duration/60);
        $duration = $duration%60;
    }
    $seconds = $duration;

    return($days."d ".$hours."h ".$minutes."m ".$seconds."s");
}

########################################
sub _insert_fake_event {
    my($self, $result, $time) = @_;

    $self->_log('_insert_fake_event()') if $verbose;
    for my $host (keys %{$result->{'services'}}) {
        for my $service (keys %{$result->{'services'}->{$host}}) {
            my $last_service_state = STATE_UNSPECIFIED;
            if(defined $self->{'service_data'}->{$host}->{$service}->{'last_known_state'}) {
                $last_service_state = $self->{'service_data'}->{$host}->{$service}->{'last_known_state'};
            }
            elsif(defined $self->{'service_data'}->{$host}->{$service}->{'last_state'}) {
                $last_service_state = $self->{'service_data'}->{$host}->{$service}->{'last_state'};
            }
            my $fakedata = {
                'service_description' => $service,
                'time'                => $time,
                'host_name'           => $host,
                'type'                => 'INITIAL SERVICE STATE',
                'hard'                => 1,
                'state'               => $last_service_state,
            };
            $self->_set_service_event($host, $service, $result, $fakedata);
        }
    }

    for my $host (keys %{$result->{'hosts'}}) {
        my $last_host_state = STATE_UNSPECIFIED;
        if(defined $self->{'host_data'}->{$host}->{'last_known_state'}) {
            $last_host_state = $self->{'host_data'}->{$host}->{'last_known_state'};
        }
        elsif(defined $self->{'host_data'}->{$host}->{'last_state'}) {
            $last_host_state = $self->{'host_data'}->{$host}->{'last_state'};
        }
        my $fakedata = {
            'time'                => $time,
            'host_name'           => $host,
            'type'                => 'INITIAL HOST STATE',
            'hard'                => 1,
            'state'               => $last_host_state,
        };
        &_set_host_event($self, $host, $result, $fakedata);
    }

    return 1;
}

########################################
sub _set_default_options {
    my $self    = shift;
    my $options = shift;

    $options->{'backtrack'}                      = 4             unless defined $options->{'backtrack'};
    $options->{'assumeinitialstates'}            = 'yes'         unless defined $options->{'assumeinitialstates'};
    $options->{'assumestateretention'}           = 'yes'         unless defined $options->{'assumestateretention'};
    $options->{'assumestatesduringnotrunning'}   = 'yes'         unless defined $options->{'assumestatesduringnotrunning'};
    $options->{'includesoftstates'}              = 'no'          unless defined $options->{'includesoftstates'};
    $options->{'initialassumedhoststate'}        = 'unspecified' unless defined $options->{'initialassumedhoststate'};
    $options->{'initialassumedservicestate'}     = 'unspecified' unless defined $options->{'initialassumedservicestate'};
    $options->{'showscheduleddowntime'}          = 'yes'         unless defined $options->{'showscheduleddowntime'};
    $options->{'timeformat'}                     = '%s'          unless defined $options->{'timeformat'};
    $options->{'breakdown'}                      = BREAK_NONE    unless defined $options->{'breakdown'};

    return $options;
}

########################################
sub _verify_options {
    my $self    = shift;
    my $options = shift;

    # set default backtrack to 4 days
    if(defined $options->{'backtrack'}) {
        if($options->{'backtrack'} < 0) {
            croak('backtrack has to be a positive integer');
        }
    }

    # our yes no options
    for my $yes_no (qw/assumeinitialstates
                       assumestateretention
                       assumestatesduringnotrunning
                       includesoftstates
                       showscheduleddowntime
                      /) {
        if(defined $options->{$yes_no}) {
            if(lc $options->{$yes_no} eq 'yes') {
                $options->{$yes_no} = TRUE;
            }
            elsif(lc $options->{$yes_no} eq 'no') {
                $options->{$yes_no} = FALSE;
            } else {
                croak($yes_no.' unknown, please use \'yes\' or \'no\'. Got: '.$options->{$yes_no});
            }
        }
    }

    # set initial assumed host state
    if(defined $options->{'initialassumedhoststate'}) {
        if(lc $options->{'initialassumedhoststate'} eq 'unspecified') {
            $options->{'initialassumedhoststate'} = STATE_UNSPECIFIED;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'current') {
            $options->{'initialassumedhoststate'} = STATE_CURRENT;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'up') {
            $options->{'initialassumedhoststate'} = STATE_UP;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'down') {
            $options->{'initialassumedhoststate'} = STATE_DOWN;
        }
        elsif(lc $options->{'initialassumedhoststate'} eq 'unreachable') {
            $options->{'initialassumedhoststate'} = STATE_UNREACHABLE;
        }
        else {
            croak('initialassumedhoststate unknown, please use one of: unspecified, current, up, down or unreachable. Got: '.$options->{'initialassumedhoststate'});
        }
    }

    # set initial assumed service state
    if(defined $options->{'initialassumedservicestate'}) {
        if(lc $options->{'initialassumedservicestate'} eq 'unspecified') {
            $options->{'initialassumedservicestate'} = STATE_UNSPECIFIED;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'current') {
            $options->{'initialassumedservicestate'} = STATE_CURRENT;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'ok') {
            $options->{'initialassumedservicestate'} = STATE_OK;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'warning') {
            $options->{'initialassumedservicestate'} = STATE_WARNING;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'unknown') {
            $options->{'initialassumedservicestate'} = STATE_UNKNOWN;
        }
        elsif(lc $options->{'initialassumedservicestate'} eq 'critical') {
            $options->{'initialassumedservicestate'} = STATE_CRITICAL;
        }
        else {
            croak('initialassumedservicestate unknown, please use one of: unspecified, current, ok, warning, unknown or critical. Got: '.$options->{'initialassumedservicestate'});
        }
    }

    # set breakdown
    if(defined $options->{'breakdown'}) {
        if(lc $options->{'breakdown'} eq '') {
            $options->{'breakdown'} = BREAK_NONE;
        }
        elsif(lc $options->{'breakdown'} eq 'months') {
            $options->{'breakdown'} = BREAK_MONTHS;
        }
        elsif(lc $options->{'breakdown'} eq 'weeks') {
            $options->{'breakdown'} = BREAK_WEEKS;
        }
        elsif(lc $options->{'breakdown'} eq 'days') {
            $options->{'breakdown'} = BREAK_DAYS;
        }
        elsif(lc $options->{'breakdown'} eq 'none') {
            $options->{'breakdown'} = BREAK_NONE;
        }
        elsif(   $options->{'breakdown'} == BREAK_NONE
           or $options->{'breakdown'} == BREAK_DAYS
           or $options->{'breakdown'} == BREAK_WEEKS
           or $options->{'breakdown'} == BREAK_MONTHS) {
            # ok
        }
        else {
            croak('breakdown unknown, please use one of: months, weeks, days or none. Got: '.$options->{'breakdown'});
        }
    }

    return $options;
}

########################################
sub _add_log_entry {
    my($self, %opts) = @_;

    $self->_log('_add_log_entry()') if $verbose;

    # do we build up a log?
    return if $self->{'report_options'}->{'build_log'} == FALSE;

    push @{$self->{'full_log_store'}}, \%opts;

    return 1;
}

########################################
sub _calculate_log {
    my($self) = @_;

    $self->_log('_calculate_log()') if $verbose;

    # combine outside report range log events
    my $changed = FALSE;
    if(defined $self->{'first_known_state_before_report'}) {
        push @{$self->{'full_log_store'}}, $self->{'first_known_state_before_report'};
        $changed = TRUE;
    }
    if(defined $self->{'first_known_proc_before_report'}) {
        push @{$self->{'full_log_store'}}, $self->{'first_known_proc_before_report'};
        $changed = TRUE;
    }

    # sort once more if changed
    if($changed) {
        @{$self->{'full_log_store'}} = sort { $a->{'log'}->{'start'} <=> $b->{'log'}->{'start'} } @{$self->{'full_log_store'}};
    }

    # insert fakelog service entry when initial state is fixed
    if($self->{'report_options'}->{'initialassumedservicestate'} != STATE_UNSPECIFIED
       and scalar @{$self->{'report_options'}->{'services'}} == 1
    ) {
        my $type;
        my $first_state = $self->{'report_options'}->{'initialassumedservicestate'};
        if($first_state == STATE_CURRENT)     { $first_state = $self->{'report_options'}->{'first_state'}; }
        if($first_state == STATE_OK)          { $type = 'OK'; }
        elsif($first_state == STATE_WARNING)  { $type = 'WARNING'; }
        elsif($first_state == STATE_UNKNOWN)  { $type = 'UNKNOWN'; }
        elsif($first_state == STATE_CRITICAL) { $type = 'CRITICAL'; }
        my $fake_start = $self->{'report_options'}->{'start'};
        if(defined $self->{'full_log_store'}->[0]) {
            if($fake_start >= $self->{'full_log_store'}->[0]->{'log'}->{'start'}) { $fake_start = $self->{'full_log_store'}->[0]->{'log'}->{'start'} - 1; }
        }
        my $fakelog = {
            'log' => {
                'type'          => 'SERVICE '.$type.' (HARD)',
                'class'         => $type,
                'start'         => $fake_start,
                'plugin_output' => 'First Service State Assumed (Faked Log Entry)',
            },
        };
        unshift @{$self->{'full_log_store'}}, $fakelog;
    }

    # insert fakelog host entry when initial state is fixed
    if($self->{'report_options'}->{'initialassumedhoststate'} != STATE_UNSPECIFIED
       and scalar @{$self->{'report_options'}->{'hosts'}} == 1
    ) {
        my $type;
        my $first_state = $self->{'report_options'}->{'initialassumedhoststate'};
        if($first_state == STATE_CURRENT) { $first_state = $self->{'report_options'}->{'first_state'}; }
        if($first_state == STATE_UP)             { $type = 'UP'; }
        elsif($first_state == STATE_DOWN)        { $type = 'DOWN'; }
        elsif($first_state == STATE_UNREACHABLE) { $type = 'UNREACHABLE'; }
        my $fake_start = $self->{'report_options'}->{'start'};
        if(defined $self->{'full_log_store'}->[0] and $fake_start >= $self->{'full_log_store'}->[0]->{'log'}->{'start'}) { $fake_start = $self->{'full_log_store'}->[0]->{'log'}->{'start'} - 1; }
        my $fakelog = {
            'log' => {
                'type'          => 'HOST '.$type.' (HARD)',
                'class'         => $type,
                'start'         => $fake_start,
                'plugin_output' => 'First Host State Assumed (Faked Log Entry)',
            },
        };
        unshift @{$self->{'full_log_store'}}, $fakelog;
    }

    if($verbose) {
        $self->_log("#################################");
        $self->_log("LOG STORE:");
        $self->_log(\@{$self->{'full_log_store'}});
        $self->_log("#################################");
    }

    for(my $x = 0; $x < scalar @{$self->{'full_log_store'}}; $x++) {
        my $log_entry      = $self->{'full_log_store'}->[$x];
        my $next_log_entry = $self->{'full_log_store'}->[$x+1];
        my $log            = $log_entry->{'log'};

        # set end date of current log entry
        if(defined $next_log_entry->{'log'}->{'start'}) {
            $log->{'end'}      = $next_log_entry->{'log'}->{'start'};
            $log->{'duration'} = $self->_duration($log->{'start'} - $log->{'end'});
        } else {
            $log->{'end'}      = $self->{'report_options'}->{'end'};
            $log->{'duration'} = $self->_duration($log->{'start'} - $log->{'end'}).'+';
        }

        # convert time format
        if($self->{'report_options'}->{'timeformat'} ne '%s') {
            $log->{'end'}   = POSIX::strftime $self->{'report_options'}->{'timeformat'}, localtime($log->{'end'});
            $log->{'start'} = POSIX::strftime $self->{'report_options'}->{'timeformat'}, localtime($log->{'start'});
        }

        push @{$self->{'log_output'}}, $log unless defined $log_entry->{'full_only'};
        push @{$self->{'full_log_output'}}, $log;
    }

    $self->{'log_output_calculated'} = TRUE;
    return 1;
}


########################################
sub _state_to_int {
    my($self, $string) = @_;

    return unless defined $string;

    if(defined $self->{'state_string_2_int'}->{$string}) {
        return $self->{'state_string_2_int'}->{$string};
    }

    croak("valid values for services are: ok, warning, unknown and critical\nvalues for host: up, down and unreachable");
}

########################################
sub _new_service_data {
    my($self, $breakdown, $timestamp) = @_;
    my $data = {
        time_ok           => 0,
        time_warning      => 0,
        time_unknown      => 0,
        time_critical     => 0,

        scheduled_time_ok             => 0,
        scheduled_time_warning        => 0,
        scheduled_time_unknown        => 0,
        scheduled_time_critical       => 0,
        scheduled_time_indeterminate  => 0,

        time_indeterminate_nodata             => 0,
        time_indeterminate_notrunning         => 0,
        time_indeterminate_outside_timeperiod => 0,
    };
    $data->{'timestamp'} = $timestamp if $timestamp;
    if($breakdown != BREAK_NONE) {
        $data->{'breakdown'} = {};
        for my $cur (@{$self->{'breakpoints'}}) {
            my $timestr = $self->_get_break_timestr($cur);
            next if defined $data->{'breakdown'}->{$timestr};
            $data->{'breakdown'}->{$timestr} = $self->_new_service_data(BREAK_NONE, $cur);
        }
    }
    return $data;
}

########################################
sub _new_host_data {
    my($self, $breakdown, $timestamp) = @_;
    my $data = {
        time_up           => 0,
        time_down         => 0,
        time_unreachable  => 0,

        scheduled_time_up             => 0,
        scheduled_time_down           => 0,
        scheduled_time_unreachable    => 0,
        scheduled_time_indeterminate  => 0,

        time_indeterminate_nodata             => 0,
        time_indeterminate_notrunning         => 0,
        time_indeterminate_outside_timeperiod => 0,
    };
    $data->{'timestamp'} = $timestamp if $timestamp;
    if($breakdown != BREAK_NONE) {
        $data->{'breakdown'} = {};
        for my $cur (@{$self->{'breakpoints'}}) {
            my $timestr = $self->_get_break_timestr($cur);
            next if defined $data->{'breakdown'}->{$timestr};
            $data->{'breakdown'}->{$timestr} = $self->_new_host_data(BREAK_NONE, $cur);
        }
    }
    return $data;
}

########################################
sub _get_break_timestr {
    my($self, $timestamp) = @_;

    my @localtime = localtime($timestamp);

    if($self->{'report_options'}->{'breakdown'} == BREAK_DAYS) {
        return POSIX::strftime('%Y-%m-%d', @localtime);
    }
    elsif($self->{'report_options'}->{'breakdown'} == BREAK_WEEKS) {
        return POSIX::strftime('%G-WK%V', @localtime);
    }
    elsif($self->{'report_options'}->{'breakdown'} == BREAK_MONTHS) {
        return POSIX::strftime('%Y-%m', @localtime);
    }
    die("report failed, debug data is available in ".$self->_write_debug_file("unknown break definition"));
}

########################################
sub _set_breakpoints {
    my($self) = @_;
    $self->{'breakpoints'} = [];

    return if $self->{'report_options'}->{'breakdown'} == BREAK_NONE;

    my $cur   = $self->{'report_options'}->{'start'};
    my $start = $self->{'report_options'}->{'start'} - 86400;
    # round to next 0:00
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($cur);
    $cur = POSIX::mktime(0, 0, 0, $mday, $mon, $year, $wday, $yday, $isdst);
    while($cur < $self->{'report_options'}->{'end'}) {
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($cur);
        $cur = POSIX::mktime(0, 0, 0, $mday, $mon, $year, $wday, $yday, $isdst);
        push @{$self->{'breakpoints'}}, $cur if $cur >= $start;
        $cur = $cur + 86400;
    }
    return;
}

########################################
sub _write_debug_file {
    my($self, $msg) = @_;
    my($fh, $filename) = tempfile();
    print $fh "error: $msg\n";
    print $fh "version: $VERSION\n\n";
    print $fh Dumper($self), "\n\n";
    close($fh);
    if($self->{'report_options'}->{'log_file'}) {
        `cat "$self->{'report_options'}->{'log_file'}" >> $filename`;
    }
    return $filename;
}

########################################

1;

=head1 BUGS

Please report any bugs or feature requests to L<http://github.com/sni/Monitoring-Availability/issues>.

=head1 DEBUGING

You may enable the debug mode by setting MONITORING_AVAILABILITY_DEBUG environment variable.
This will create a logfile: /tmp/Monitoring-Availability-Debug.log which gets overwritten with
every calculation.
You will need the Log4Perl module to create this logfile.

=head1 SEE ALSO

You can also look for information at:

=over 4

=item * Search CPAN

L<http://search.cpan.org/dist/Monitoring-Availability/>

=item * Github

L<http://github.com/sni/Monitoring-Availability>

=back

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
