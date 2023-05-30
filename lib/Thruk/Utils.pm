package Thruk::Utils;

=head1 NAME

Thruk::Utils - Utilities Collection for Thruk

=head1 DESCRIPTION

Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Carp qw/confess longmess/;
use Data::Dumper qw/Dumper/;
use Date::Calc qw/Localtime Monday_of_Week Week_of_Year Today Add_Delta_Days/;
use File::Copy qw/copy/;
use POSIX ();
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Action::AddDefaults ();
use Thruk::Base qw/:compat/;
use Thruk::Utils::DateTime ();
use Thruk::Utils::Encode ();
use Thruk::Utils::Filter ();
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;

##############################################
=head1 METHODS

=head2 parse_date

  my $timestamp = parse_date($c, $string)

Format: 2010-03-02 00:00:00
parse given date and return timestamp

=cut
sub parse_date {
    my($c, $string) = @_;
    return(_parse_date($string)) unless defined $c;
    my $timestamp;
    eval {
        $timestamp = _parse_date($string);
        if(defined $timestamp) {
            _debug("parse_date: '".$string."' to -> '".(scalar localtime $timestamp)."'");
        } else {
            _debug("error parsing data: '".$string."'");
        }
    };
    if($@) {
        _error("parse_date error for '".$string."' - ".$@);
        _error(longmess());
    }
    return $timestamp;
}


##############################################

=head2 format_date

  my $date_string = format_date($string, $format)

return date from timestamp in given format

=cut
sub format_date {
    my($timestamp, $format) = @_;
    confess("no format") unless defined $format;
    confess("no timestamp") unless defined $timestamp;
    if($format =~ m/%MILLI/mx) {
        my $millis = sprintf("%03d", ($timestamp-int($timestamp))*1000);
        $format =~ s|%MILLI|$millis|gmx;
    }
    my $date = POSIX::strftime($format, localtime($timestamp));
    return $date;
}


##############################################

=head2 format_number

  my $string = format_number($number)

return number with thousands seperator

=cut
sub format_number {
    my($number) = @_;
    my $abs = $number;
    if(!$abs) {
        return $number;
    }
    if($abs < 0) { $abs = $abs * -1; }
    for ($number) {
        /\./mx
        ? s/(?<=\d)(?=(\d{3})+(?:\.))/,/gmx
        : s/(?<=\d)(?=(\d{3})+(?!\d))/,/gmx;
    }
    # shorten decimals for larger numbers
    if($abs > 1000) {
        $number =~ s/(\.\d{2})\d*/$1/gmx;
    }
    if($abs > 10000) {
        $number =~ s/(\.\d{1})\d*/$1/gmx;
    }
    if($abs > 100000) { # no fractions here
        $number =~ s/\.\d*//gmx;
    }
    return $number;
}

##############################################

=head2 format_cronentry

  my $cron_string = format_cronentry($cron_entry)

return cron entry as string

=cut
sub format_cronentry {
    my($c, $entry) = @_;
    my $cron;
    my $cr = {};
    for my $key (keys %{$entry}) {
        $cr->{$key} = Thruk::Utils::Filter::escape_html($entry->{$key});
    }
    if($cr->{'type'} eq 'month') {
        my $app = 'th';
        if($cr->{'day'} == 1) { $app = 'st'; }
        if($cr->{'day'} == 2) { $app = 'nd'; }
        if($cr->{'day'} == 3) { $app = 'rd'; }
        $cron = sprintf("every %s%s at %02s:%02s", $cr->{'day'}, $app, $cr->{'hour'}, $cr->{'minute'});
    }
    elsif($cr->{'type'} eq 'week') {
        if(defined $cr->{'week_day'} and $cr->{'week_day'} ne '') {
            my @days;
            my @daynr = split/,/mx, $cr->{'week_day'};
            my $lastconcated = [];
            for my $x (0..$#daynr) {
                my $nr = $daynr[$x];
                $nr = 7 if $nr == 0;
                my $next = $daynr[$x+1] || 0;
                $next = 7 if $next == 0;
                if($next == $nr+1) {
                    if(!defined $lastconcated->[0]) {
                        $lastconcated->[0] = $c->config->{'weekdays'}->{$nr};
                    } else {
                        $lastconcated->[1] = $c->config->{'weekdays'}->{$nr};
                    }
                } else {
                    if(defined $lastconcated->[0]) {
                        push @days, $lastconcated->[0].'-'.$c->config->{'weekdays'}->{$nr};
                        $lastconcated = [];
                    } else {
                        push @days, $c->config->{'weekdays'}->{$nr};
                    }
                }
            }
            if(defined $lastconcated->[1]) {
                push @days, $lastconcated->[0].'-'.$lastconcated->[1];
            }
            elsif(defined $lastconcated->[0]) {
                push @days, $lastconcated->[0];
            }
            $cron = sprintf("%s at %02s:%02s", join(', ', @days), $cr->{'hour'}, $cr->{'minute'});
        } else {
            $cron = 'never';
        }
    }
    elsif($cr->{'type'} eq 'day') {
        $cron = sprintf("daily at %02s:%02s", $cr->{'hour'}, $cr->{'minute'});
    }
    elsif($cr->{'type'} eq 'monthday') {
        my $month_day = lcfirst $cr->{'month_day'};
        $month_day =~ s/_/ /gmx;
        $cron = sprintf("every %s at %02s:%02s", $month_day, $cr->{'hour'}, $cr->{'minute'});
    }
    elsif($cr->{'type'} eq 'cust') {
        my @tst = split/\s+/mx, $cr->{'cust'};
        if(scalar @tst == 5) {
            $cron = $cr->{'cust'};
        } else {
            $cron = '<font color="red" title="invalid cron syntax">'.$cr->{'cust'}.'</font>';
        }
    } else {
        confess("unknown cron type: ".$cr->{'type'});
    }
    return $cron;
}

######################################

=head2 is_valid_regular_expression

  my $result = is_valid_regular_expression($expression)

return true if this is a valid regular expression

=cut
sub is_valid_regular_expression {
    my $c          = shift;
    my $expression = shift;
    return 1 unless defined $expression;
    local $SIG{__DIE__} = '';
    eval { "test" =~ m/$expression/mx; };
    my $err = $@;
    if($err) {
        chomp($err);
        $err =~ s/\Q; marked by <-- HERE in \Em\/.*?\Q<-- HERE\E.*?\/\ at\ .*?\ line\ \d+\.//gmx;
        my $error_message = "invalid regular expression: ".Thruk::Utils::Filter::escape_html($err);
        set_message($c, { style => 'fail_message', msg => $error_message, escape => 0}) if $c;
        return;
    }
    return 1;
}


########################################

=head2 calculate_overall_processinfo

  my $process_info = calculate_overall_processinfo($process_info)

computes a combined status for process infos

=cut
sub calculate_overall_processinfo {
    my($pi, $selected) = @_;
    my $return = {};

    # if no backend is available
    return($return) if ref $pi ne 'HASH';

    for my $peer (@{$selected}) {
        for my $key (keys %{$pi->{$peer}}) {
            my $value = $pi->{$peer}->{$key};
            if(defined $value and ($value eq "0" or $value eq "1")) {
                if(!defined $return->{$key}) {
                    $return->{$key} = $value;
                }elsif($return->{$key} == -1) {
                    # do nothing, result already varies
                }elsif($return->{$key} == $value) {
                    # do nothing, result is the same
                }elsif($return->{$key} != $value) {
                    # set result to vary
                    $return->{$key} = -1;
                }
            }
        }
    }
    return($return);
}


########################################

=head2 get_start_end_for_timeperiod

  my($start, $end) = get_start_end_for_timeperiod($c,
                                                  $timeperiod,
                                                  $smon,
                                                  $sday,
                                                  $syear,
                                                  $shour,
                                                  $smin,
                                                  $ssec,
                                                  $emon,
                                                  $eday,
                                                  $eyear,
                                                  $ehour,
                                                  $emin,
                                                  $esec,
                                                  $t1,
                                                  $t2);

returns a start and end timestamp for a report date definition

=cut
sub get_start_end_for_timeperiod {
    my($c,$timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2) = @_;

    my $start;
    my $end;
    $timeperiod = 'custom' unless defined $timeperiod;
    my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
    if($timeperiod eq 'today') {
        $start = Thruk::Utils::DateTime::mktime($year,$month,$day,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last24hours') {
        $end   = time();
        $start = $end - 86400;
    }
    elsif($timeperiod eq 'yesterday') {
        $start = Thruk::Utils::DateTime::mktime($year,$month,$day,  0,0,0) - 86400;
        $end   = $start + 86400;
    }
    elsif($timeperiod eq 'thisweek') {
        # start on last sunday 0:00 till now
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        if($c->config->{'first_day_of_week'} == 1) {
            $start = Thruk::Utils::DateTime::mktime(@monday,  0,0,0);
        } else {
            $start = Thruk::Utils::DateTime::mktime(@monday,  0,0,0) - 86400;
        }
        $end       = time();
    }
    elsif($timeperiod eq 'last7days') {
        $end   = time();
        $start = $end - 7 * 86400;
    }
    elsif($timeperiod eq 'lastweek') {
        # start on last weeks sunday 0:00 till last weeks saturday 24:00
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        if($c->config->{'first_day_of_week'} == 1) {
            $end   = Thruk::Utils::DateTime::mktime(@monday,  0,0,0);
        } else {
            $end   = Thruk::Utils::DateTime::mktime(@monday,  0,0,0) - 86400;
        }
        $start     = $end - 7*86400;
    }
    elsif($timeperiod eq 'thismonth') {
        # start on first till now
        $start = Thruk::Utils::DateTime::mktime($year,$month,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last31days') {
        $end   = time();
        $start = $end - 31 * 86400;
    }
    elsif($timeperiod eq 'lastmonth') {
        $end   = Thruk::Utils::DateTime::mktime($year,$month,1,  0,0,0);
        my $lastmonth = $month - 1;
        if($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        $start = Thruk::Utils::DateTime::mktime($year,$lastmonth,1,  0,0,0);
    }
    elsif($timeperiod =~ /last(\d+)months?/mx) {
        my $months = $1;
        $end   = Thruk::Utils::DateTime::mktime($year,$month,1,  0,0,0);
        my $lastmonth = $month - $months;
        while($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        $start = Thruk::Utils::DateTime::mktime($year,$lastmonth,1,  0,0,0);
    }
    elsif($timeperiod eq 'thisyear') {
        $start = Thruk::Utils::DateTime::mktime($year,1,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'lastyear') {
        $start = Thruk::Utils::DateTime::mktime($year-1,1,1,  0,0,0);
        $end   = Thruk::Utils::DateTime::mktime($year,1,1,  0,0,0);
    }
    else {
        if(defined $t1) {
            $start = _parse_date($t1);
        } else {
            $start = Thruk::Utils::DateTime::normal_mktime($syear,$smon,$sday, $shour,$smin,$ssec);
        }

        if(defined $t2) {
            $end = _parse_date($t2);
        } else {
            $end   = Thruk::Utils::DateTime::normal_mktime($eyear,$emon,$eday, $ehour,$emin,$esec);
        }
    }

    if(!defined $start || !defined $end) {
        return(undef, undef);
    }

    _debug("start: ".$start." - ".(scalar localtime($start)));
    _debug("end  : ".$end." - ".(scalar localtime($end)));

    if($end >= $start) {
        return($start, $end);
    }
    return($end, $start);
}


########################################

=head2 get_start_end_for_timeperiod_from_param

  my($start, $end) = get_start_end_for_timeperiod_from_param($c)

returns a start and end timestamp for a report date definition
will use cgi params for input

=cut
sub get_start_end_for_timeperiod_from_param {
    my($c) = @_;

    confess("no c") unless defined($c);

    # get timeperiod
    my $timeperiod   = $c->req->parameters->{'timeperiod'};
    my $smon         = $c->req->parameters->{'smon'};
    my $sday         = $c->req->parameters->{'sday'};
    my $syear        = $c->req->parameters->{'syear'};
    my $shour        = $c->req->parameters->{'shour'}  || 0;
    my $smin         = $c->req->parameters->{'smin'}   || 0;
    my $ssec         = $c->req->parameters->{'ssec'}   || 0;
    my $emon         = $c->req->parameters->{'emon'};
    my $eday         = $c->req->parameters->{'eday'};
    my $eyear        = $c->req->parameters->{'eyear'};
    my $ehour        = $c->req->parameters->{'ehour'}  || 0;
    my $emin         = $c->req->parameters->{'emin'}   || 0;
    my $esec         = $c->req->parameters->{'esec'}   || 0;
    my $t1           = $c->req->parameters->{'t1'};
    my $t2           = $c->req->parameters->{'t2'};

    $timeperiod = 'last24hours' if(!defined $timeperiod && !defined $t1 && !defined $t2);
    return Thruk::Utils::get_start_end_for_timeperiod($c, $timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2);
}


########################################

=head2 get_start_end_from_date_select_params

  my($start, $end) = get_start_end_from_date_select_params($c)

returns a start and end timestamp from date select, like ex.: on the showlog page

=cut
sub get_start_end_from_date_select_params {
    my($c) = @_;
    confess("no c") unless defined($c);

    my($start,$end);
    my $archive     = $c->req->parameters->{'archive'} || 0;
    my $param_start = $c->req->parameters->{'start'};
    my $param_end   = $c->req->parameters->{'end'};

    # start / end date from formular values?
    if(defined $param_start && defined $param_end) {
        # convert to timestamps
        $start = parse_date($c, $param_start);
        $end   = parse_date($c, $param_end);
    }
    if(!defined $start || $start == 0 || !defined $end || $end == 0) {
        # start with today 00:00
        $start = Thruk::Utils::DateTime::mktime(Today(), 0,0,0);
        $end   = Thruk::Utils::DateTime::mktime(Add_Delta_Days(Today(), 1), 0,0,0);
    }
    if($archive eq '+1') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime($start);
        $start = Thruk::Utils::DateTime::mktime(Add_Delta_Days($year,$month,$day, 1), 0,0,0);
        ($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime($end);
        $end = Thruk::Utils::DateTime::mktime(Add_Delta_Days($year,$month,$day, 1), 0,0,0);
    }
    elsif($archive eq '-1') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime($start);
        $start = Thruk::Utils::DateTime::mktime(Add_Delta_Days($year,$month,$day, -1), 0,0,0);
        ($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime($end);
        $end = Thruk::Utils::DateTime::mktime(Add_Delta_Days($year,$month,$day, -1), 0,0,0);
    }

    # swap date if they are mixed up
    if($start > $end) {
        my $tmp = $start;
        $start = $end;
        $end   = $tmp;
    }
    return($start, $end);
}

########################################

=head2 set_message

  set_message($c, $style, $text, [ $details ], [$code], [$escape])
  set_message($c, {
      'style'   => 'class', # usually fail_message or success_message
      'msg'     => 'text',
      'details' => 'more details',
      'code'    => 'http response code',
      'escape'  => 'flag wether html should be escaped, default is true',
    })

set a message in an cookie for later display

=cut
sub set_message {
    my $c   = shift;
    my $dat = shift;
    my($style, $message, $details, $code, $escape);

    if(ref $dat eq 'HASH') {
        $style   = $dat->{'style'};
        $message = $dat->{'msg'};
        $details = $dat->{'details'};
        $code    = $dat->{'code'};
        $escape  = $dat->{'escape'};
    } else {
        $style   = $dat;
        $message = shift;
        $details = shift;
        $code    = shift;
        $escape  = shift;
    }
    $escape = $escape // 1;
    my($escaped_message, $escaped_details);
    if($escape) {
        $escaped_message = Thruk::Utils::Filter::escape_html($message);
        $escaped_details = Thruk::Utils::Filter::escape_html($details);
    }

    # cookie does not get escaped, it will be escaped upon read
    $c->cookie('thruk_message', $style.'~~'.$message, { httponly => 0 });
    # use escaped data if possible, but store original data as well
    $c->stash->{'thruk_message'}         = $style.'~~'.($escaped_message // $message);
    $c->stash->{'thruk_message_details'} = $escaped_details // $details;
    $c->stash->{'thruk_message_style'}       = $style;
    $c->stash->{'thruk_message_raw'}         = $message;
    $c->stash->{'thruk_message_details_raw'} = $details;
    $c->res->code($code) if defined $code;

    _debug(sprintf("set_message: %s - %s", $style, $message));
    _debug(sprintf("set_message: %s", $details)) if $details;
    return 1;
}


########################################

=head2 append_message

  append_message($text)

append text to current message

=cut
sub append_message {
    my($c, $txt) = @_;
    if(defined $c->res->cookies->{'thruk_message'}) {
        $c->res->cookies->{'thruk_message'}->{'value'} .= ' '.$txt;
    }
    if(defined $c->stash->{'thruk_message'}) {
        $c->stash->{'thruk_message'} .= ' '.$txt;
    }
    return 1;
}


########################################

=head2 ssi_include

  ssi_include($c)

puts the ssi templates into the stash

=cut
sub ssi_include {
    my($c, $page) = @_;
    $page = $c->stash->{'page'} unless defined $page;

    $c->stash->{ssi_header}  = read_ssi($c, 'common', 'header');
    $c->stash->{ssi_header} .= read_ssi($c, $page, 'header');
    $c->stash->{ssi_footer}  = read_ssi($c, 'common', 'footer');
    $c->stash->{ssi_footer} .= read_ssi($c, $page, 'footer');

    $c->stash->{real_page} = "";
    if($c->stash->{controller} =~ m/Thruk::Controller::([^:]*)::.*?$/gmx) {
        $c->stash->{real_page} = $1;
    }

    return 1;
}


########################################

=head2 read_ssi

  read_ssi($c, $page, $type)

finds all ssi files for a page of the specified type and returns the ssi content.
Executable ssi files are executed and the output is appended to the ssi content.
Otherwise the content of the ssi file is append to the ssi content.

=cut
sub read_ssi {
    my($c, $page, $type) = @_;
    my @files = sort grep { /\/${page}-${type}(-.*)?.ssi\z/mx } keys %{$c->config->{ssi_includes}};
    my $output = "";
    for my $inc (@files) {
        $output .= "\n<!-- BEGIN SSI $inc -->\n" if Thruk::Base->verbose;
        if(-x $inc) {
          if(open(my $ph, '-|', "$inc 2>&1")) {
            while(defined(my $line = <$ph>)) { $output .= $line; }
            CORE::close($ph);
          } else {
            carp("cannot execute ssi $inc: $!");
          }
        } elsif(-r $inc) {
            my $content = Thruk::Utils::IO::read($inc);
            $content = Thruk::Utils::Encode::decode_any($content);
            unless(defined $content) { carp("cannot open ssi $inc: $!") }
            $output .= $content;
        } else {
            _warn("$inc is no longer accessible, please restart thruk to initialize ssi information");
        }
        $output .= "\n<!-- END SSI $inc -->\n" if Thruk::Base->verbose;
    }
    return $output;
}

########################################

=head2 read_resource_file

  read_resource_file($files, [ $macros ], [$with_comments])

returns a hash with all USER1-32 macros. macros can
be a predefined hash.

=cut

sub read_resource_file {
    my($files, $macros, $with_comments) = @_;

    $files = Thruk::Base::list($files);
    return unless scalar @{$files} > 0;

    my $comments    = {};
    my $lastcomment = "";
    $macros         = {} unless defined $macros;
    for my $file (@{$files}) {
        my @lines = Thruk::Utils::IO::saferead_as_list($file);
        for my $line (@lines) {
            if($line =~ m/^\s*(\$[A-Z0-9_]+\$)\s*=\s*(.*)$/mx) {
                $macros->{$1}   = $2;
                $comments->{$1} = $lastcomment;
                $lastcomment    = "";
            }
            elsif($line =~ m/^(\#.*$)/mx) {
                $lastcomment .= $1;
            }
            elsif($line =~ m/^\s*$/mx) {
                $lastcomment = '';
            }
        }
    }
    return($macros) unless $with_comments;
    return($macros, $comments);
}


########################################

=head2 version_compare

  version_compare($version1, $version2)

compare too version strings and return 1 if v1 >= v2

=cut
sub version_compare {
    my($v1,$v2) = @_;
    confess("version_compare() needs two params") unless defined $v1;
    confess("version_compare() needs two params") unless defined $v2;

    # replace non-numerical characters
    $v1 =~ s/[^\d\.]/./gmx;
    $v2 =~ s/[^\d\.]/./gmx;

    my @v1 = split/\./mx,$v1;
    my @v2 = split/\./mx,$v2;

    for(my $x = 0; $x < scalar @v1; $x++) {
        my $cmp1 = 0;
        my $cmp2 = 0;
        if(defined $v1[$x] and $v1[$x] =~ m/^(\d+)/gmx) { $cmp1 = $1; }
        if(defined $v2[$x] and $v2[$x] =~ m/^(\d+)/gmx) { $cmp2 = $1; }
        if ($cmp1 > $cmp2) {
            return 1;
        }
        if ($cmp1 < $cmp2) {
            return 0;
        }
    }
    return 1;
}


########################################

=head2 combine_filter

  combine_filter($operator, $filter)

combine filter by operator

=cut
sub combine_filter {
    my $operator = shift;
    my $filter   = shift;

    if(!defined $operator && $operator ne '-or' && $operator ne '-and') {
        confess("unknown operator: ".Dumper($operator));
    }

    return unless defined $filter;

    if(ref $filter ne 'ARRAY') {
        confess("expected arrayref, got: ".Dumper(ref $filter));
    }

    return if scalar @{$filter} == 0;

    if(scalar @{$filter} == 1) {
        return $filter->[0];
    }

    return { $operator => $filter };
}

########################################

=head2 set_paging_steps

  set_paging_steps($c, $data)

sets the pagins stepts, needs string like:

  *100, 500, 1000, all

=cut
sub set_paging_steps {
    my $c    = shift;
    my $data = shift;

    $c->stash->{'paging_steps'}      = [ '100', '500', '1000', '5000', 'all' ];
    $c->stash->{'default_page_size'} = 100;

    return unless defined $data;

    # we need an array
    $data = ref $data eq 'ARRAY' ? $data : [split(/\s*,\s*/mx, $data)];

    $c->stash->{'paging_steps'}      = [];
    $c->stash->{'default_page_size'} = undef;

    for my $step (@{$data}) {
        if($step =~ m/^\*(.*)$/mx) {
            $step                            = $1;
            $c->stash->{'default_page_size'} = $step;
        }
        push @{$c->stash->{'paging_steps'}}, $step;
    }

    # no default yet?
    unless(defined $c->stash->{'default_page_size'}) {
        $c->stash->{'default_page_size'} = $c->stash->{'paging_steps'}->[0];
    }

    return;
}

########################################

=head2 get_exposed_custom_vars

  get_exposed_custom_vars($config, [$skip_wildcards])

return combined list of show_custom_vars and expose_custom_vars

=cut
sub get_exposed_custom_vars {
    my($config, $skip_wildcards) = @_;
    confess("no config") unless defined $config;
    my $vars = {};
    for my $src (qw/show_custom_vars expose_custom_vars/) {
        for my $var (@{Thruk::Base::list($config->{$src})}) {
            next if($skip_wildcards && $var =~ m/\*/mx);
            $vars->{$var} = 1;
        }
    }
    for my $src (qw/default_service_columns default_host_columns/) {
        next unless $config->{$src};
        my @dfl = split(/\s*,\s*/mx, $config->{$src});
        for my $d (@dfl) {
            if($d =~ m/^cust_([a-zA-Z0-9]+?)(:.*|)$/mx) {
                my $var  = $1;
                $vars->{$var} = 1;
            }
        }
    }
    return([sort keys %{$vars}]);
}

########################################

=head2 get_custom_vars

  get_custom_vars($c, $obj, [$prefix], [$add_host])

return custom variables in a hash

=cut
sub get_custom_vars {
    my($c, $data, $prefix, $add_host, $add_action_menu) = @_;
    $prefix = '' unless defined $prefix;
    $add_action_menu = 1 unless defined $add_action_menu;

    my %hash;

    if(   defined $data
      and defined $data->{$prefix.'custom_variable_names'}
      and defined $data->{$prefix.'custom_variable_values'}
      and ref $data->{$prefix.'custom_variable_names'} eq 'ARRAY')
    {
        # merge custom variables into a hash
        @hash{@{$data->{$prefix.'custom_variable_names'}}} = @{$data->{$prefix.'custom_variable_values'}};
    }

    if($add_host
      and defined $data
      and defined $data->{'host_custom_variable_names'}
      and defined $data->{'host_custom_variable_values'}
      and ref $data->{'host_custom_variable_names'} eq 'ARRAY')
    {
        for(my $x = 0; $x < scalar @{$data->{'host_custom_variable_names'}}; $x++) {
            my $key = $data->{'host_custom_variable_names'}->[$x];
            $hash{"HOST".$key} = $data->{'host_custom_variable_values'}->[$x];
        }
    }

    # add action menu from apply rules
    if($add_action_menu && $c && $c->config->{'action_menu_apply'} && !$hash{'THRUK_ACTION_MENU'}) {
        APPLY:
        for my $menu (sort keys %{$c->config->{'action_menu_apply'}}) {
            for my $pattern (@{Thruk::Base::list($c->config->{'action_menu_apply'}->{$menu})}) {
                if(!$prefix && $data->{'description'}) {
                    my $test = $data->{'host_name'}.';'.$data->{'description'};
                    ## no critic
                    if($test =~ m/$pattern/) {
                    ## use critic
                        $hash{'THRUK_ACTION_MENU'} = $menu;
                        last APPLY;
                    }
                }
                elsif($data->{$prefix.'name'}) {
                    my $test = $data->{$prefix.'name'}.';';
                    ## no critic
                    if($test =~ m/$pattern/) {
                    ## use critic
                        $hash{'THRUK_ACTION_MENU'} = $menu;
                        last APPLY;
                    }
                }
            }
        }
    }

    return \%hash;
}


########################################

=head2 set_custom_vars

  set_custom_vars($c, { options... })

set stash value for all allowed custom variables

=cut
sub set_custom_vars {
    my($c, $args) = @_;

    my $prefix   = $args->{'prefix'} || '';
    my $search   = $args->{'search'} || 'show_custom_vars';
    my $dest     = $args->{'dest'}   || 'custom_vars';
    my $host     = $args->{'host'};
    my $service  = $args->{'service'};
    my $add_host = $args->{'add_host'};
    my $data;

    if (defined $host and defined $service) {
        $data = $service;
    } elsif (defined $host) {
        $data = $host;
    } else {
        return;
    }

    $c->stash->{$dest} = [];

    return unless defined $data;
    return unless defined $data->{$prefix.'custom_variable_names'};
    return unless ref $data->{$prefix.'custom_variable_names'} eq 'ARRAY';
    return unless defined $c->config->{$search};

    my $vars        = Thruk::Base::list($c->config->{$search});
    my $custom_vars = get_custom_vars($c, $data, $prefix, $add_host);

    my $already_added = {};
    for my $cust_name (sort keys %{$custom_vars}) {
        next unless Thruk::Utils::check_custom_var_list($cust_name, $vars);

        # expand macros in custom vars
        my $cust_value = $custom_vars->{$cust_name};
        if(defined $host and defined $service) {
                #($cust_value, $rc)...
                ($cust_value, undef) = $c->db->_replace_macros({
                    string  => $cust_value,
                    host    => $host,
                    service => $service,
                });
        } elsif (defined $host) {
                #($cust_value, $rc)...
                ($cust_value, undef) = $c->db->_replace_macros({
                    string  => $cust_value,
                    host    => $host,
                });
        }

        # add to dest
        my $is_host = defined $service ? 0 : 1;
        if($add_host) {
            if($cust_name =~ s/^HOST//gmx) {
                $is_host = 1;
            }
        }
        next if $already_added->{$cust_name};
        $already_added->{$cust_name} = 1;
        push @{$c->stash->{$dest}}, [ $cust_name, $cust_value, $is_host ];
    }
    return;
}

########################################

=head2 check_custom_var_list

  check_custom_var_list($varname, $allowed)

returns true if custom variable name is in the list of allowed variable names

=cut
sub check_custom_var_list {
    my($varname, $allowed) = @_;

    $varname =~ s/^_//gmx;

    for my $cust_name (@{$allowed}) {
        $cust_name =~ s/^_//gmx;
        # direct match
        if($varname eq $cust_name) {
            return(1);
        } else {
            # wildcard match
            my $v = "".$cust_name;
            next if CORE::index($v, '*') == -1;
            $v =~ s/\*/.*/gmx;

            # if variable starts with HOST, the matcher has to start with HOST too
            if($varname =~ m/^host/mxi && $v !~ m/^host/mxi) {
                next;
            }

            if($varname =~ m/^$v$/mx) {
                return(1);
            }
        }
    }
    return;
}

########################################

=head2 set_data_row_cust_vars

  set_data_row_cust_vars($obj, $allowed, $allowed_list)

set custom variables for host/service obj

=cut
sub set_data_row_cust_vars {
    my($obj, $allowed, $allowed_list) = @_;

    if($obj->{'custom_variable_names'}) {
        $obj->{'custom_variables'} = get_custom_vars(undef, $obj);
        for my $key (@{$obj->{'custom_variable_names'}}) {
            if($allowed || check_custom_var_list($key, $allowed_list)) {
                $obj->{'_'.uc($key)} = $obj->{'custom_variables'}->{$key};
            } else {
                delete $obj->{'custom_variables'}->{$key};
            }
        }
        if(!$allowed) {
            $obj->{'custom_variable_names'}  = [keys   %{$obj->{'custom_variables'}}];
            $obj->{'custom_variable_values'} = [values %{$obj->{'custom_variables'}}];
        }
    }
    if($obj->{'host_custom_variable_names'}) {
        $obj->{'host_custom_variables'} = get_custom_vars(undef, $obj, 'host_');
        for my $key (@{$obj->{'host_custom_variable_names'}}) {
            if($allowed || check_custom_var_list('_HOST'.uc($key), $allowed_list)) {
                $obj->{'_HOST'.uc($key)} = $obj->{'host_custom_variables'}->{$key};
            } else {
                delete $obj->{'host_custom_variables'}->{$key};
            }
        }
        if(!$allowed) {
            $obj->{'host_custom_variable_names'}  = [keys   %{$obj->{'host_custom_variables'}}];
            $obj->{'host_custom_variable_values'} = [values %{$obj->{'host_custom_variables'}}];
        }
    }
    return($obj);
}

########################################

=head2 get_user_data

  get_user_data($c, [$username])

returns user profile data

=cut
sub get_user_data {
    my($c, $username) = @_;

    if(!defined $username) {
        $username = $c->stash->{'remote_user'};
    }
    if(!defined $username || $username eq '?') {
        return {};
    }
    confess("username not allowed") if Thruk::Base::check_for_nasty_filename($username);

    my $user_data = {};
    my $file = $c->config->{'var_path'}."/users/".$username;
    if(-s $file) {
        $user_data = read_data_file($file);
    }
    return $user_data;
}


########################################

=head2 store_user_data

  store_user_data($c, $data, [$username])

store user profile data

=cut
sub store_user_data {
    my($c, $data, $username) = @_;

    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', 'saving user settings is disabled in demo mode');
        return;
    }

    if(defined $username) {
        confess("username not allowed") if Thruk::Base::check_for_nasty_filename($username);
    } else {
        $username = $c->stash->{'remote_user'};
    }

    if(!defined $username || $username eq '?') {
        return 1;
    }

    for my $dir ($c->config->{'var_path'}, $c->config->{'var_path'}."/users") {
        if(! -d $dir) {
            Thruk::Utils::IO::mkdir($dir) or do {
                Thruk::Utils::set_message( $c, 'fail_message', 'saving data failed: mkdir '.$dir.': '.$! );
                return;
            };
        }
    }

    my $file = $c->config->{'var_path'}."/users/".$username;
    my $rc;
    eval {
        $rc = write_data_file($file, $data);
    };
    if($@ || !$rc) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: '.$file.' '.$@ );
        return;
    }

    return 1;
}


########################################

=head2 get_global_user_data

  get_global_user_data($c)

returns global user data

=cut

sub get_global_user_data {
    my($c) = @_;

    my $file = $c->config->{'var_path'}."/global_user_data";
    return {} unless -s $file;
    return read_data_file($file);
}


########################################

=head2 store_global_user_data

  store_global_user_data($c, $data)

store global user data for section

=cut

sub store_global_user_data {
    my($c, $data) = @_;

    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', 'saving global settings disabled in demo mode');
        return;
    }

    my $dir = $c->config->{'var_path'};
    if(! -d $dir) {
        Thruk::Utils::IO::mkdir($dir) or do {
            Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: mkdir '.$dir.': '.$! );
            return;
        };
    }

    my $file = $c->config->{'var_path'}."/global_user_data";
    my $rc;
    eval {
        $rc = write_data_file($file, $data);
    };
    if($@ || !$rc) {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Data failed: '.$file.' '.$@ );
        return;
    }
    return 1;
}

########################################

=head2 logs2xls

  logs2xls($c)

save excel file by background job

=cut

sub logs2xls {
    my($c, $type) = @_;
    require Thruk::Utils::Status;
    Thruk::Utils::Status::set_selected_columns($c, [''], ($type || 'log'));
    $c->stash->{'data'} = $c->db->get_logs(%{$c->stash->{'log_filter'}});
    savexls($c);
    return;
}

########################################

=head2 savexls

  savexls($c)

save excel file by background job

=cut

sub savexls {
    my($c) = @_;
    $c->stash->{'res_header'} = [ 'Content-Disposition', qq[attachment; filename="] .  $c->stash->{'file_name'} . q["] ];
    $c->stash->{'res_ctype'}  = 'application/x-msexcel';

    my $template = $c->stash->{'template'};
    require Thruk::Views::ExcelRenderer;
    require File::Temp;
    my $output = Thruk::Views::ExcelRenderer::render($c, $template);
    if($c->config->{'no_external_job_forks'}) {
        #my($fh, $filename)...
        my(undef, $filename)     = File::Temp::tempfile();
        $c->stash->{'file_name'} = $filename;
        $c->stash->{job_dir}     = '';
        $c->stash->{cleanfile}   = 1;
    }
    Thruk::Utils::IO::write($c->stash->{job_dir}.$c->stash->{'file_name'}, $output);
    return;
}

########################################

=head2 proxifiy_url

  prepend proxy url to action url which might be proxied via thruk http

returns url with optional proxy prepended

=cut
sub proxifiy_url {
    my($c, $obj, $url) = @_;
    if($url =~ m/^https?:/mx) {
        return($url);
    }
    if(!$c->config->{'http_backend_reverse_proxy'}) {
        return($url);
    }
    my $peer_key = ref $obj eq 'HASH' ? $obj->{'peer_key'} : $obj;
    my $peer     = $c->db->get_peer_by_key($peer_key);
    return($url) unless $peer;
    if($peer->{'type'} ne 'http') {
        return($url);
    }

    my $proxy_prefix = $c->stash->{'url_prefix'}.'cgi-bin/proxy.cgi/'.$peer_key;

    # fix pnp/grafana url hacks
    $url =~ s%(\s+rel=)('|")%$1$2$proxy_prefix%gmx;

    return($proxy_prefix.$url);
}

########################################

=head2 proxifiy_me

  returns proxy url if possible

returns url with optional proxy prepended

=cut
sub proxifiy_me {
    my($c, $peer_id) = @_;
    return unless $peer_id;
    my $thruk_url = get_remote_thruk_url($c, $peer_id);
    return unless $thruk_url;
    my $url = $c->req->uri;
    $url    =~ s|^https?://[^/]+/|/|mx;
    $url    =~ s|^.*?/thruk/|$thruk_url|mx;
    my $proxy_url = proxifiy_url($c, {peer_key => $peer_id}, $url);
    return $proxy_url if $url ne $proxy_url;
    return;
}

########################################

=head2 get_remote_thruk_url

  get_remote_thruk_url($peer_key)

return url for remote thruk installation

=cut
sub get_remote_thruk_url {
    my($c, $id) = @_;
    my $peer = $c->db->get_peer_by_key($id);
    confess("got no peer for id: ".$id) unless $peer;
    my $url = "";
    if($peer->{'fed_info'}) {
        $url = $peer->{'fed_info'}->{'addr'}->[scalar @{$peer->{'fed_info'}->{'addr'}}-1];
    }
    if($peer->{'type'} eq 'http' && (!$url || $url !~ /^https?:/mx)) {
        $url = $peer->{'addr'};
    }
    if($url) {
        if($url !~ m/^https?:\/\//mx) {
            return("");
        }
        $url =~ s|^https?://[^/]*/?|/|gmx;
        $url =~ s|cgi-bin\/remote\.cgi$||gmx;
        $url =~ s|thruk/?$||gmx;
        $url =~ s|/$||gmx;
        $url = $url.'/thruk/';
    }
    return($url || "");
}

########################################

=head2 get_pnp_url

  get_pnp_url($c, $object)

return pnp url for object (host/service)

=cut
sub get_pnp_url {
    my($c, $obj, $force) = @_;

    return '' unless $c->config->{'shown_inline_pnp'} || $force;

    for my $type (qw/action_url_expanded notes_url_expanded/) {
        next unless defined $obj->{$type};
        my $regex = $c->config->{'pnp_url_regex'};
        if($obj->{$type} =~ m%(^.*?$regex)%mx) {
            return(proxifiy_url($c, $obj, $1.'/index.php'));
        }
    }

    return '';
}

########################################

=head2 get_histou_url

  get_histou_url($c, $object)

return histou url for object (host/service)

=cut

sub get_histou_url {
    my($c, $obj, $force) = @_;

    return '' unless $c->config->{'shown_inline_pnp'} || $force;

    for my $type (qw/action_url_expanded notes_url_expanded/) {
        next unless defined $obj->{$type};
        my $regex = $c->config->{'grafana_url_regex'};
        if($obj->{$type} =~ m%$regex%mx) {
            return(proxifiy_url($c, $obj, $obj->{$type}));
        }
    }

    return '';
}

########################################

=head2 get_graph_url

  get_graph_url($c, $object)

return graph url for object (host/service)

=cut

sub get_graph_url {
    my($c, $obj, $force) = @_;

    my $graph_word = $c->config->{'graph_word'};
    my $action_url = '';

    if ($graph_word && ($c->config->{'shown_inline_pnp'} || $force)) {
        for my $type (qw/action_url_expanded notes_url_expanded/) {
            next unless defined $obj->{$type};
            for my $regex (@{Thruk::Base::list($graph_word)}) {
                if ($obj->{$type} =~ m|$regex|mx){
                    $action_url = $obj->{$type};
                    last;
                }
            }
        }
    }

    if(!defined $obj->{'name'} && !defined $obj->{'host_name'}) {
        #unknown host
        return '';
    }

    return get_action_url($c, 1, 0, $action_url, $obj);
}

##########################################################

=head2 get_perf_image

  get_perf_image($c, {
    host           => $hst,
    service        => $svc,
    start          => $start,
    end            => $end,
    width          => $width,
    height         => $height,
    source         => $source,
    resize_grafana => $resize_grafana_images,
    format         => $format,
    show_title     => $showtitle,
    show_legend    => $showlegend,
    follow         => 0/1,  # flag wether we simply redirect proxy requests or fetch them
    theme          => light/dark,
    font_color     => #12345,
    bg_color       => #12345,
  })

return raw pnp/grafana image if possible.
An empty string will be returned if no graph can be exported.

=cut
sub get_perf_image {
    my($c, $options) = @_;
    my $pnpurl     = "";
    my $grafanaurl = "";
    $options->{'format'}      = 'png'  unless $options->{'format'};
    $options->{'service'}     = ''     unless defined $options->{'service'};
    $options->{'show_title'}  = 1      unless defined $options->{'show_title'};
    $options->{'show_legend'} = 1      unless defined $options->{'show_legend'};
    if(defined $options->{'end'}) {
        $options->{'end'} = _parse_date($options->{'end'});
    } else {
        $options->{'end'} = time();
    }
    if(defined $options->{'start'}) {
        $options->{'start'} = _parse_date($options->{'start'});
    } else {
        $options->{'start'} = $options->{'end'} - 86400;
    }

    if($options->{'service'} && $options->{'service'} eq '_HOST_') { $options->{'service'} = ""; }

    my $custvars;
    if($options->{'service'}) {
        my $svcdata = $c->db->get_services(filter => [{ host_name => $options->{'host'}, description => $options->{'service'} }]);
        if(scalar @{$svcdata} == 0) {
            _error("no such service ".$options->{'service'}." on host ".$options->{'host'});
            return("");
        }
        $pnpurl     = get_pnp_url($c, $svcdata->[0], 1);
        $grafanaurl = get_histou_url($c, $svcdata->[0], 1);
        $custvars   = get_custom_vars($c, $svcdata->[0]);
    } else {
        my $hstdata = $c->db->get_hosts(filter => [{ name => $options->{'host'}}]);
        if(scalar @{$hstdata} == 0) {
            _error("no such host ".$options->{'host'});
            return("");
        }
        $pnpurl                = get_pnp_url($c, $hstdata->[0], 1);
        $grafanaurl            = get_histou_url($c, $hstdata->[0], 1);
        $options->{'service'}  = '_HOST_' if $pnpurl;
        $custvars              = get_custom_vars($c, $hstdata->[0]);
    }

    $c->stash->{'last_graph_type'} = 'pnp';
    if($grafanaurl) {
        # simply redirect?
        if($grafanaurl =~ m|/thruk/cgi\-bin/proxy\.cgi/([^/]+)/|mx) {
            my $peer_id  = $1;
            my $proxyurl = Thruk::Utils::proxifiy_me($c, $peer_id);
            if($proxyurl) {
                if($options->{'follow'}) {
                    return($c->db->rpc($peer_id, "Thruk::Utils::get_perf_image", [$c, $options]));
                }
                $c->{'rendered'} = 1;
                return $c->redirect_to($proxyurl);
            }
        }

        if(!$options->{'show_title'}) {
            $grafanaurl .= '&disablePanelTitle';
            $grafanaurl .= '&reduce=1';
        }
        if(!$options->{'show_legend'} || $options->{'height'} < 200) {
            $grafanaurl .= '&legend=false';
        }
        if($options->{'theme'}) {
            $grafanaurl =~ s/\&theme=light//gmx; # removed hardcoded url from *-perf template
            $grafanaurl .= '&theme='.$options->{'theme'};
        }
        my $css = "";
        if($options->{'bg_color'} && $options->{'bg_color'} =~ m/^(transparent|\#\w+)$/mx) {
            my $color = $1;
            $css .= '.panel-container,.main-view,body,html {background:'.$color.' !important;background-color:'.$color.' !important;}';
        }
        if($options->{'font_color'} && $options->{'font_color'} =~ m/^(\#\w+)$/mx) {
            my $color = $1;
            $css .= 'A,DIV.flot-text,.graph-legend-content,body,html {color:'.$color.' !important;}';
        }
        if($css) {
            # inject custom css into histou
            require MIME::Base64;
            require URI::Escape;
            $grafanaurl .= '&customCSSFile='.URI::Escape::uri_escape('data:text/css;base64,'.MIME::Base64::encode_base64($css));
        }
        $c->stash->{'last_graph_type'} = 'grafana';
        $grafanaurl =~ s|/dashboard/|/dashboard-solo/|gmx;
        $grafanaurl =~ s|/d/|/d-solo/|gmx;
        # grafana panel ids usually start at 1 (or 2 with old versions)
        delete $options->{'source'} if(defined $options->{'source'} && $options->{'source'} eq 'null');
        $options->{'source'} = ($custvars->{'GRAPH_SOURCE'} // $c->config->{'grafana_default_panelId'} // '1') unless defined $options->{'source'};
        $grafanaurl .= '&panelId='.$options->{'source'};
        if($options->{'resize_grafana'}) {
            $options->{'width'}  = $options->{'width'} * 1.3;
            $options->{'height'} = $options->{'height'} * 2;
        }
        if($ENV{'OMD_ROOT'}) {
            # go local first if available
            my $site = $ENV{'OMD_SITE'};
            if($grafanaurl =~ m%^/$site(/grafana/.*)$%mx) {
                $grafanaurl = $c->config->{'omd_local_site_url'}.$1;
            }
        }
        if($grafanaurl !~ m|^https?:|mx) {
            my $uri = Thruk::Utils::Filter::full_uri($c, 1);
            $uri    =~ s|(https?://[^/]+?)/.*$|$1|gmx;
            $uri    =~ s|&amp;|&|gmx;
            $grafanaurl = $uri.$grafanaurl;
        }
    } else {
        # simply redirect?
        if($pnpurl =~ m|/thruk/cgi\-bin/proxy\.cgi/([^/]+)/|mx) {
            my $peer_id  = $1;
            my $proxyurl = Thruk::Utils::proxifiy_me($c, $peer_id);
            if($proxyurl) {
                if($options->{'follow'}) {
                    if($options->{'service'} && $options->{'service'} eq '_HOST_') { $options->{'service'} = ""; }
                    return($c->db->rpc($peer_id, "Thruk::Utils::get_perf_image", [$c, $options]));
                }
                $c->{'rendered'} = 1;
                return $c->redirect_to($proxyurl);
            }
        }
        $options->{'source'} = ($custvars->{'GRAPH_SOURCE'} || '0') unless defined $options->{'source'};
    }

    my $exporter = $c->config->{home}.'/script/pnp_export.sh';
    $exporter    = $c->config->{'Thruk::Plugin::Reports2'}->{'pnp_export'} if $c->config->{'Thruk::Plugin::Reports2'}->{'pnp_export'};
    if($grafanaurl) {
        $exporter = $c->config->{home}.'/script/grafana_export.sh';
        $exporter = $c->config->{'Thruk::Plugin::Reports2'}->{'grafana_export'} if $c->config->{'Thruk::Plugin::Reports2'}->{'grafana_export'};
    }

    # create fake session
    my($sessionid) = get_fake_session($c);
    local $ENV{THRUK_SESSION_ID} = $sessionid;

    # call login hook, because it might transfer our sessions to remote graphers
    if($c->config->{'cookie_auth_login_hook'}) {
        Thruk::Utils::IO::cmd($c, $c->config->{'cookie_auth_login_hook'});
    }

    require File::Temp;
    my($fh, $filename) = File::Temp::tempfile();
    CORE::close($fh);
    my $cmd = $exporter.' "'.$options->{'host'}.'" "'.$options->{'service'}.'" "'.$options->{'width'}.'" "'.$options->{'height'}.'" "'.$options->{'start'}.'" "'.$options->{'end'}.'" "'.($pnpurl||'').'" "'.$filename.'" "'.$options->{'source'}.'"';
    if($grafanaurl) {
        $cmd = $exporter.' "'.$options->{'width'}.'" "'.$options->{'height'}.'" "'.$options->{'start'}.'" "'.$options->{'end'}.'" "'.$grafanaurl.'" "'.$filename.'"';
    }
    my($rc, $out) = Thruk::Utils::IO::cmd($c, $cmd, undef, undef, undef,undef, 30);
    unlink($c->stash->{'fake_session_file'});
    if(-e $filename) {
        my $imgdata  = Thruk::Utils::IO::read($filename);
        unlink($filename);
        if($options->{'format'} eq 'png') {
            # check if this is a real image
            if(substr($imgdata, 0, 10) =~ m/PNG/mx) {
                return $imgdata;
            }
            if($imgdata) {
                _debug("failed to fetch png image, got this instead:");
                _debug($imgdata);
            }
        } else {
            return $imgdata;
        }
    }
    _debug($out) if $out;
    $c->stash->{'last_graph_output'} = $out;
    return '';
}

##############################################

=head2 encode_arg_refs

  encode_arg_refs($args)

returns array with replaced args, ex. replace $c with placeholder

=cut
sub encode_arg_refs {
    my($args) = @_;
    if(!$args || ref $args ne 'ARRAY') {
        return($args);
    }
    for(my $x = 0; $x <= scalar @{$args}; $x++) {
        # reverse function is in Thruk::Utils::CLI
        if(ref $args->[$x] eq 'Thruk::Context') {
            $args->[$x] = 'Thruk::Context';
        }
        if(ref $args->[$x] eq 'Thruk::Utils::Cluster') {
            $args->[$x] = 'Thruk::Utils::Cluster';
        }
    }
    return($args);
}

##############################################

=head2 unencode_arg_refs

  unencode_arg_refs($c, $args)

returns array with replaced args, ex. replace placeholder with $c

=cut
sub unencode_arg_refs {
    my($c, $args) = @_;
    if(!$args || ref $args ne 'ARRAY') {
        return($args);
    }
    for(my $x = 0; $x <= scalar @{$args}; $x++) {
        if(!ref $args->[$x] && $args->[$x]) {
            if($args->[$x] eq 'Thruk::Context') {
                $args->[$x] = $c;
            }
            if($args->[$x] eq 'Thruk::Utils::Cluster') {
                $args->[$x] = $c->cluster;
            }
        }
    }
    return($args);
}

##############################################

=head2 absolute_url

  returns a absolute url

  expects
  $VAR1 = origin url
  $VAR2 = target link

=cut
sub absolute_url {
    my($baseurl, $link, $force) = @_;

    return($link) if $link =~ m/^https?:/mx;

    $baseurl = '' unless defined $baseurl;
    confess("empty") if($baseurl eq '' and $link eq '');

    my $c = $Thruk::Globals::c or die("not initialized!");
    my $product_prefix = $c->config->{'product_prefix'};

    # append trailing slash
    if($baseurl =~ m/^https?:\/\/[^\/]+$/mx) {
        $baseurl .= '/';
    }

    if($link !~ m/^https?:/mx && $link !~ m|^/|mx) {
        my $newloc = $baseurl;
        $newloc    =~ s/^(.*\/).*$/$1/gmxo;
        $newloc    .= $link;
        while($newloc =~ s|/[^\/]+/\.\./|/|gmxo) {}
        $link = $newloc;
    }

    if(!$force && $link =~ m%^(/||[^/]*/|/[^/]*/)\Q$product_prefix\E/%mx) {
        return($link);
    }

    # split original baseurl in host, path and file
    if($baseurl =~ m/^(http|https):\/\/([^\/]*)(|\/|:\d+)(.*?)$/mx) {
        my $host     = $1."://".$2.$3;
        my $fullpath = $4 || '';
        $host        =~ s/\/$//mx;      # remove last /
        $fullpath    =~ s/\?.*$//mx;
        $fullpath    =~ s/^\///mx;
        my($path,$file) = ('', '');
        if($fullpath =~ m/^(.+)\/(.*)$/mx) {
            $path = $1;
            $file = $2;
        }
        else {
            $file = $fullpath;
        }
        $path =~ s/^\///mx; # remove first /

        if($link =~ m/^(http|https):\/\//mx) {
            return $link;
        }
        elsif($link =~ m/^\//mx) { # absolute link
            return $host.$link;
        }
        elsif($path eq '') {
            return $host."/".$link;
        } else {
            return $host."/".$path."/".$link;
        }
    }

    if($link =~ m/^\//mx) {
        return($link);
    }

    confess("unknown url scheme in absolute_url('".$baseurl."', '".$link."')");
}

##############################################

=head2 get_fake_session

  get_fake_session($c, [$sessionid], [$roles], [$address], $extra)

create and return fake session id along with session data for current user

=cut

sub get_fake_session {
    my($c, $id, $username, $roles, $ip, $extra) = @_;

    if(!$c->user_exists) {
        confess("no user");
    }
    if(!$c->user->{'superuser'}) {
        $username = $c->stash->{'remote_user'};
    }

    # get intersection of roles
    if($roles && ref $roles eq 'ARRAY') {
        $roles = $c->user->clean_roles($roles);
    }

    my $sessiondata = {
        hash     => 'none',
        address  => $ip,
        username => ($username // $c->stash->{'remote_user'}),
        fake     => 1,
    };
    if($roles && ref $roles eq 'ARRAY') {
        $sessiondata->{'roles'} = $roles;
    }
    if($extra) {
        for my $key (sort keys %{$extra}) {
            $sessiondata->{$key} = $extra->{$key};
        }
    }
    require Thruk::Utils::CookieAuth;
    $sessiondata = Thruk::Utils::CookieAuth::store_session($c->config, $id, $sessiondata);
    $c->stash->{'fake_session_id'}   = $sessiondata->{'private_key'};
    $c->stash->{'fake_session_file'} = $sessiondata->{'file'};
    return($sessiondata->{'private_key'}, $sessiondata) if wantarray;
    return($sessiondata->{'private_key'});
}

########################################

=head2 get_action_url

  get_action_url($c, $escape_fun, $remove_render, $action_url, $obj)

return action_url modified for object (host/service) if we use graphite
escape_fun is use to escape special char (html or quotes)
remove_render remove /render in action url

=cut

sub get_action_url {
    my($c, $escape_fun, $remove_render, $action_url, $obj, $obj_prefix) = @_;

    my $new_action_url = $action_url;
    my $graph_word = $c->config->{'graph_word'};

    # don't escape pnp links, they often contain quotes on purpose
    if($action_url =~ m/\/pnp(|4nagios)\//mx) {
        # add theme
        if($action_url !~ m/theme=/mx) {
            $action_url =~ s/(index.php.*?)'/$1&theme=smoothness'/mx;
        }
        $action_url =~ s/&amp;/&/gmx;
        $action_url =~ s/&/&amp;/gmx;
        return($action_url);
    }
    elsif($action_url =~ m/\/histou\.js\?/mx || $action_url =~ m/\/grafana\//mx) {
        my $custvars = get_custom_vars($c, $obj, $obj_prefix);
        $action_url =~ s/&amp;/&/gmx;
        $action_url =~ s/&/&amp;/gmx;
        my $popup_url = $action_url;
        $popup_url =~ s|/dashboard/|/dashboard-solo/|gmx;
        $popup_url =~ s|/d/|/d-solo/|gmx;
        $popup_url .= '&amp;panelId='.($custvars->{'GRAPH_SOURCE'} // $c->config->{'grafana_default_panelId'} // '1');
        $action_url .= "' class='histou_tips' rel='".$popup_url;
        return($action_url);
    }

    if ($graph_word) {
        my $host = $obj->{'host_name'} // $obj->{'host_name'};
        my $svc  = $obj->{'description'};
        for my $regex (@{Thruk::Base::list($graph_word)}) {
            if ($action_url =~ m|$regex|mx){
                my $new_host = $host;
                for my $regex (@{$c->config->{'graph_replace'}}) {
                    ## no critic
                    eval('$new_host =~ '.$regex);
                    ## use critic
                }

                if ($svc) {
                    my $new_svc = $svc;
                    for my $regex (@{$c->config->{'graph_replace'}}) {
                        ## no critic
                        eval('$new_svc =~ '.$regex);
                        ## use critic
                    }
                    $new_action_url =~ s/\Q$svc\E/$new_svc/gmx;
                }
                $new_action_url =~ s/\Q$host\E/$new_host/gmx;

                last;
            }
        }
    }

    if ($escape_fun == 2) {
        $new_action_url = Thruk::Utils::Filter::escape_html($new_action_url);
    }
    elsif($escape_fun == 1) {
        $new_action_url = Thruk::Utils::Filter::escape_quotes($new_action_url);
    }

    if ($remove_render != 0) {
        $new_action_url =~ s|/render||gmx;
    }

    return $new_action_url;
}

########################################

=head2 extract_list

  extract_list($var, $separator)

return list by splitting $var by $sep ($var can be an array or string)

=cut

sub extract_list {
    my($var, $sep) = @_;
    my $result = [];
    for my $v (@{Thruk::Base::list($var)}) {
        for my $v2 (split($sep, $v)) {
            push @{$result}, $v2;
        }
    }
    return($result);
}

########################################

=head2 array_chunk

  array_chunk($list, $number)

return list of <number> evenly chunked parts

=cut

sub array_chunk {
    my($list, $number) = @_;
    return([$list]) if $number <= 1;
    my $size   = POSIX::ceil(scalar @{$list} / $number);
    my $chunks = array_chunk_fixed_size($list, $size);
    return($chunks);
}

########################################

=head2 array_chunk_fixed_size

  array_chunk_fixed_size($list, $size)

return list of chunked parts each with $size

=cut

sub array_chunk_fixed_size {
    my($list, $size) = @_;
    if(scalar @{$list} < $size) {
        return([$list]);
    }
    my $chunks = [];
    while(my @chunk = splice( @{$list}, 0, $size ) ) {
        push @{$chunks}, \@chunk;
    }
    return($chunks);
}

########################################

=head2 translate_host_status

  translate_host_status($status)

return name for status

=cut

sub translate_host_status {
    my $status = shift;
    return 'UP'          if $status == 0;
    return 'DOWN'        if $status == 1;
    return 'UNREACHABLE' if $status == 2;
    return 'UNKNOWN';
}

##############################################

=head2 expand_duration

  expand_duration($value)

returns expanded seconds from given abbreviation

possible conversions are
1w => 604800
1d => 86400
1h => 3600
1m => 60

=cut
sub expand_duration {
    my($value) = @_;
    if($value =~ m/^(\-?[\.\d]+)(y|w|d|h|m|s)/gmx) {
        if($2 eq 'y') { return $1 * 86400*365; }# year
        if($2 eq 'w') { return $1 * 86400*7; }  # weeks
        if($2 eq 'd') { return $1 * 86400; }    # days
        if($2 eq 'h') { return $1 * 3600; }     # hours
        if($2 eq 'm') { return $1 * 60; }       # minutes
        if($2 eq 's') { return $1 }             # seconds
    }
    return $value;
}

##############################################

=head2 update_cron_file

  update_cron_file($c, $section, $entries)

write crontab section

=cut

sub update_cron_file {
    my($c, $section, $entries) = @_;

    if(!$c->config->{'cron_file'}) {
        set_message($c, 'fail_message', 'no \'cron_file\' set, check your settings!');
        return;
    }

    # this function must be run on all cluster nodes
    return if $c->cluster->run_cluster("all", "cmd: cron install");

    my $errorlog = $c->config->{'var_path'}.'/cron.log';
    # ensure proper cron.log permission
    open(my $fh, '>>', $errorlog);

    require File::Temp;
    if($c->config->{'cron_pre_edit_cmd'}) {
        local $< = $> if $< == 0; # set real and effective uid to user, crontab will still be run as root on some systems otherwise
        my($fh2, $tmperror) = File::Temp::tempfile();
        Thruk::Utils::IO::close($fh2, $tmperror);
        my $cmd = $c->config->{'cron_pre_edit_cmd'}." 2>>".$tmperror;
        my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd);
        my $errors = Thruk::Utils::IO::read($tmperror);
        unlink($tmperror);
        print $fh $errors;
        # override know error with initial crontab
        if($rc != 0 && ($rc != 1 || $errors !~ m/no\ crontab\ for/mx)) {
            die(sprintf("cron_pre_edit_cmd (".$cmd.") exited with value %d: %s\n%s\n", $rc, $output, $errors));
        }
    }
    Thruk::Utils::IO::close($fh, $errorlog);

    # read complete file
    my $sections = {};
    my @orig_cron;
    my $thruk_started = 0;
    if(-e $c->config->{'cron_file'}) {
        open(my $fh, '<', $c->config->{'cron_file'}) or die('cannot read '.$c->config->{'cron_file'}.': '.$!);
        my $lastsection;
        while(my $line = <$fh>) {
            chomp($line);
            $thruk_started = 1 if $line =~ m/^\#\ THIS\ PART\ IS\ WRITTEN\ BY\ THRUK/mx;
            unless($thruk_started) {
                push @orig_cron, $line;
                next;
            }
            $thruk_started = 0 if $line =~ m/^\#\ END\ OF\ THRUK/mx;

            if($line =~ m/^\#\ ([\w\s]+)$/mx) {
                $lastsection = $1;
                next;
            }
            next if $line =~ m/^\#/mx;
            next if $line =~ m/^\s*$/mx;
            next unless defined $lastsection;
            $sections->{$lastsection} = [] unless defined $sections->{$lastsection};
            push @{$sections->{$lastsection}}, $line;
        }
        CORE::close($fh) or die("cannot close file ".$c->config->{'cron_file'}.": ".$!);
    }

    # write out new file
    if(defined $section) {
        delete $sections->{$section};
        my $user = '';
        if(substr($c->config->{'cron_file'}, 0, 12) eq '/etc/cron.d/') {
            $user = ' root ';
        }
        $sections->{$section} = [];
        for my $entry (@{$entries}) {
            next unless $entry->[0];
            push @{$sections->{$section}}, $entry->[0]." ".$user.$entry->[1];
        }
    }

    open($fh, '>', $c->config->{'cron_file'}) or die('cannot write '.$c->config->{'cron_file'}.': '.$!);
    for my $line (@orig_cron) {
        print $fh $line, "\n";
    }

    if(defined $section) {
        my $header_printed = 0;
        for my $s (sort keys %{$sections}) {
            next if scalar @{$sections->{$s}} == 0;
            unless($header_printed) {
                print $fh "# THIS PART IS WRITTEN BY THRUK, CHANGES WILL BE OVERWRITTEN\n";
                print $fh "##############################################################\n";
                print $fh "THRUK_CRON=1\n";
                $header_printed = 1;
            }
            print $fh '# '.$s."\n";
            for my $line (@{$sections->{$s}}) {
                print $fh $line, "\n";
            }
        }
        if($header_printed) {
            print $fh "##############################################################\n";
            print $fh "# END OF THRUK\n";
        }
    }
    Thruk::Utils::IO::close($fh, $c->config->{'cron_file'});

    if($c->config->{'cron_post_edit_cmd'}) {
        local $< = $> if $< == 0; # set real and effective uid to user, crontab will still be run as root on some systems otherwise
        my $cmd = $c->config->{'cron_post_edit_cmd'}." 2>>".$errorlog;
        my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd);
        if($rc != 0) {
            die(sprintf("cron_post_edit_cmd (".$cmd.") exited with value %d: %s\n", $rc, $output));
        }
    }
    return 1;
}

##########################################################

=head2 update_cron_file_maintenance

    update_cron_file_maintenance($c)

update maintenance cronjobs

=cut
sub update_cron_file_maintenance {
    my($c) = @_;
    my $cron_entries = [[
         '20,50 * * * *',
         sprintf("cd %s && %s '%s maintenance' >/dev/null 2>>%s/cron.log",
                                $c->config->{'project_root'},
                                $c->config->{'thruk_shell'},
                                $c->config->{'thruk_bin'},
                                $c->config->{'var_path'},
                ),
    ]];
    Thruk::Utils::update_cron_file($c, 'general', $cron_entries);
    return;
}

##############################################

=head2 get_cron_time_entry

  get_cron_time_entry($cronentry)

return time part of crontab entry

=cut

sub get_cron_time_entry {
    my($cr) = @_;
    my $cron;
    if($cr->{'type'} eq 'month') {
        $cron = sprintf("% 2s % 2s % 2s  *  *", $cr->{'minute'}, $cr->{'hour'}, $cr->{'day'});
    }
    elsif($cr->{'type'} eq 'week') {
        if(defined $cr->{'week_day'} and $cr->{'week_day'} ne '') {
            $cron = sprintf("% 2s % 2s  *  * % 2s", $cr->{'minute'}, $cr->{'hour'}, $cr->{'week_day'});
        }
    }
    elsif($cr->{'type'} eq 'day') {
        $cron = sprintf("% 2s % 2s  *  *  *", $cr->{'minute'}, $cr->{'hour'});
    }
    elsif($cr->{'type'} eq 'monthday') {
        my($t, $d) = split(/_/mx, $cr->{'month_day'}, 2);
        my $weeks;
        $weeks = 1 if $t eq '1st';
        $weeks = 2 if $t eq '2nd';
        $weeks = 3 if $t eq '3rd';
        $weeks = 4 if $t eq '4th';
        $weeks = 1 if $t eq 'Last';
        my $daycheck = '[ $(date +"\\%m") -ne $(date -d "-'.(7*$weeks).'days" +"\\%m") ] && ';
        if($t eq 'Last') {
            $daycheck = '[ $(date +"\\%m") -ne $(date -d "'.(7*$weeks).'days" +"\\%m") ] && ';
        }
        my $day;
        $day = 1 if $d eq 'Monday';
        $day = 2 if $d eq 'Tuesday';
        $day = 3 if $d eq 'Wednesday';
        $day = 4 if $d eq 'Thursday';
        $day = 5 if $d eq 'Friday';
        $day = 6 if $d eq 'Saturday';
        $day = 0 if $d eq 'Sunday';
        $cron = sprintf("% 2s % 2s *  *  % 2s %s", $cr->{'minute'}, $cr->{'hour'}, $day, $daycheck);
    }
    elsif($cr->{'type'} eq 'cust') {
        my @tst = split/\s+/mx, $cr->{'cust'};
        if(scalar @tst == 5) {
            $cron = $cr->{'cust'};
        }
    } else {
        confess("unknown cron type: ".$cr->{'type'});
    }
    return $cron;
}


##############################################

=head2 set_user

  set_user($c, %options)

set and authenticate a user

options are: {
    username     => username of the resulting user
    auth_src     => hint about where this user came from
    superuser    => superuser can change to other user names, roles will not exceed initial role set
    internal     => internal technical user can change into any user and has admin roles
    force        => force setting new user, even if already authenticated
    roles        => maximum set of roles
    keep_session => do not update current session cookie
}

=cut

sub set_user {
    my($c, %options) = @_;
    confess("no username") unless $options{'username'};
    confess("no auth_src") unless $options{'auth_src'};
    _debug(sprintf("set_user: %s, superuser: %s, internal: %s", $options{'username'}, $options{'superuser'} ? 'yes' : 'no', $options{'internal'} ? 'yes' : 'no'));
    if($c->user_exists) {
        if($c->user->{'internal'} || $options{'force'}) {
            # ok
            delete $c->{'user'};
            delete $c->stash->{'remote_user'};
            delete $c->{'session'};
        } elsif($c->user->{'superuser'}) {
            return(change_user($c, $options{'username'}, $options{'auth_src'}));
        } else {
            # not allowed
            confess('changing user not allowed');
        }
    }
    $c->authenticate(
            username     => $options{'username'},
            superuser    => $options{'superuser'},
            internal     => $options{'internal'},
            auth_src     => $options{'auth_src'},
            roles        => $options{'roles'},
            keep_session => $options{'keep_session'},
    );
    confess("no user") unless $c->user_exists;
    $c->user->{'auth_src'} = $options{'auth_src'};
    return $c->user;
}

##############################################

=head2 change_user

  change_user($c, $username)

changes username to given user, cannot exceed current roles and permissions

=cut

sub change_user {
    my($c, $username, $auth_src) = @_;
    confess("no username") unless $username;
    confess("not yet authenticated") unless $c->user_exists;
    confess("not allowed") unless $c->user->{'superuser'};
    return $c->user if $c->user->{'username'} eq $username;

    _debug(sprintf("change_user: %s", $username));
    my $previous_user = delete $c->{'user'};
    delete $c->stash->{'remote_user'};
    delete $c->{'session'};

    # replace current user
    $c->authenticate(
        username => $username,
        auth_src => $auth_src,
        roles    => $previous_user->{'roles'},
    );

    return $c->user;
}

##############################################

=head2 switch_realuser

  switch_realuser($uid, $groups)

switch real user and groups

=cut

sub switch_realuser {
    ## no critic
    if($< != $>) {
        $< = $> or confess("setuid failed: ".$!);
    }
    if($) != $() {
        $( = $) or confess("setgid failed: ".$!);
    }
    ## use critic
    return;
}

##############################################

=head2 check_pid_file

  check_pid_file($c)

check and write pid file if none exists

=cut

sub check_pid_file {
    my($c) = @_;
    my $pidfile  = $c->config->{'tmp_path'}.'/thruk.pid';
    if(Thruk::Base->mode eq 'FASTCGI' && ! -f $pidfile) {
        eval {
            Thruk::Utils::IO::write($pidfile, $$."\n");
        };
        warn("cannot write $pidfile: $@") if $@;
    }
    return;
}

##############################################

=head2 restart_later

  restart_later($c, $redirect_url)

restart fcgi process and redirects to given page

=cut

sub restart_later {
    my($c, $redirect) = @_;
    if(Thruk::Base->mode eq 'FASTCGI') {
        my $pidfile  = $c->config->{'tmp_path'}.'/thruk.pid';
        if(-f $pidfile) {
            for my $pid (Thruk::Utils::IO::read_as_list($pidfile)) {
                next unless($pid and $pid =~ m/^\d+$/mx);
                system("sleep 1 && kill -HUP $pid &");
            }
        } else {
            my $pid = $$;
            system("sleep 1 && kill -HUP $pid &");
        }
        Thruk::Utils::append_message($c, ' Thruk has been restarted.');
        return $c->redirect_to($redirect);
    } else {
        Thruk::Utils::append_message($c, ' Changes take effect after Restart.');
        return $c->redirect_to($redirect);
    }
    return;
}


##############################################

=head2 wait_after_reload

  wait_after_reload($c, [$backend], [$timestamp])

wait up to 30 seconds till the core responds

=cut

sub wait_after_reload {
    my($c, $pkey, $last_reload) = @_;
    my $max_wait = 30;
    $c->stats->profile(begin => "wait_after_reload");
    $pkey = $c->stash->{'param_backend'} unless $pkey;
    my $start = time();
    if(!$pkey) {
        _debug('no peer key, waiting 3 seconds');
        sleep 3;
    }
    $last_reload = time() unless $last_reload;

    # wait until core responds again
    my $procinfo = {};
    my $done     = 0;
    my $options = {};
    if($ENV{'THRUK_USE_LMD'}) {
        $options = {
                'header' => {
                    'WaitTimeout'   => 2000,
                    'WaitTrigger'   => 'all', # using something else seems not to work all the time
                    'WaitCondition' => "program_start > ".$last_reload,
                },
        };
    }
    my $msg;
    while($start > time() - $max_wait) {
        $procinfo = {};
        eval {
            local $SIG{ALRM}   = sub { die "alarm\n" };
            alarm(5);
            $c->db->reset_failed_backends();
            $procinfo = $c->db->get_processinfo(backend => $pkey, options => $options);
        };
        alarm(0);
        if($@) {
            $c->stats->profile(comment => "get_processinfo: ".$@);
            $msg = 'still waiting for core reload for '.(time()-$start).'s: '.$@;
            _debug($msg);
        }
        elsif($pkey && $c->stash->{'failed_backends'}->{$pkey}) {
            $c->stats->profile(comment => "get_processinfo: ".$c->stash->{'failed_backends'}->{$pkey});
            $msg = 'still waiting for core reload for '.(time()-$start).'s: '.$c->stash->{'failed_backends'}->{$pkey};
            _debug($msg);
        }
        elsif($pkey and $last_reload) {
            # not yet restarted
            if($procinfo and $procinfo->{$pkey} and $procinfo->{$pkey}->{'program_start'}) {
                $c->stats->profile(comment => "core program_start: ".$procinfo->{$pkey}->{'program_start'});
                if($procinfo->{$pkey}->{'program_start'} > $last_reload) {
                    $done = 1;
                    _debug('core reloaded after '.(time()-$start).'s, last program_start: '.(scalar localtime($procinfo->{$pkey}->{'program_start'})));
                    last;
                } else {
                    $msg = 'still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($procinfo->{$pkey}->{'program_start'}));
                    _debug($msg);
                }
                # assume reload worked if last restart is exactly the time we started to wait
                if(int($procinfo->{$pkey}->{'program_start'}) == int($last_reload) && $start <= (time() - 3)) {
                    $done = 1;
                    _debug('core reloaded after '.(time()-$start).'s, last program_start: '.(scalar localtime($procinfo->{$pkey}->{'program_start'})));
                    last;
                }
            }
        }
        elsif($last_reload) {
            my $newest_core = 0;
            if($procinfo) {
                for my $key (keys %{$procinfo}) {
                    if($procinfo->{$key}->{'program_start'} > $newest_core) { $newest_core = $procinfo->{$key}->{'program_start'}; }
                }
                $c->stats->profile(comment => "core program_start: ".$newest_core);
                if($newest_core > $last_reload) {
                    $done = 1;
                    last;
                } else {
                    $msg = 'still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($newest_core));
                    _debug($msg);
                }
            }
        } else {
            $done = 1;
            last;
        }
        if((time() - $start) <= 5) {
            Time::HiRes::sleep(0.3);
        } else {
            sleep(1);
        }
    }
    $c->stats->profile(end => "wait_after_reload");
    if($done) {
        # clean up cached groups which may have changed
        $c->cache->clear();
    } else {
        _error('waiting for core reload failed (%s)', $pkey // 'all sites');
        _error("details: %s", $msg) if $msg;
        return(0);
    }
    return(1);
}

##############################################

=head2 get_cron_entries_from_param

  get_cron_entries_from_param($cronentry)

return array of cron entries from param

=cut

sub get_cron_entries_from_param {
    my($params) = @_;

    my $cron_entries = [];
    for my $x (1..99) {
        if(defined $params->{'send_type_'.$x}) {
            $params->{'week_day_'.$x} = [] unless defined $params->{'week_day_'.$x};
            my @weekdays = ref $params->{'week_day_'.$x} eq 'ARRAY' ? @{$params->{'week_day_'.$x}} : ($params->{'week_day_'.$x});
            @weekdays = grep {!/^$/mx} @weekdays;
            my $type = $params->{'send_type_'.$x} || '';
            my $cust = $params->{'send_cust_'.$x} || '';
            push @{$cron_entries}, {
                'type'      => $type,
                'hour'      => defined $params->{'send_hour_'.$x}     ? $params->{'send_hour_'.$x}     : '',
                'minute'    => defined $params->{'send_minute_'.$x}   ? $params->{'send_minute_'.$x}   : '',
                'week_day'  => join(',', @weekdays),
                'day'       => defined $params->{'send_day_'.$x}      ? $params->{'send_day_'.$x}      : '',
                'month_day' => defined $params->{'send_monthday_'.$x} ? $params->{'send_monthday_'.$x} : '',
                'cust'      => $cust,
            };
        }
    }
    return $cron_entries;
}

##############################################

=head2 read_data_file

  read_data_file($filename, [$c])

return data for datafile

=cut

sub read_data_file {
    my($filename, $c) = @_;

    my $res;
    eval {
        $res = Thruk::Utils::IO::json_lock_retrieve($filename);
    };
    if(!$@ && $res) {
        return($res);
    }
    if($c) {
        _warn("error loading $filename - ".$@);
    } else {
        warn("error loading $filename - ".$@);
    }
    return;
}

##############################################

=head2 write_data_file

  write_data_file($filename, $data, [$changed_only])

write data to datafile

=cut

sub write_data_file {
    my($filename, $data, $changed_only) = @_;

    # store new data files in json format
    return(Thruk::Utils::IO::json_lock_store($filename, $data, { pretty => 1, changed_only => $changed_only }));
}

##############################################

=head2 backup_data_file

  backup_data_file($filename, $targetfile, $mode, $max_backups, [$save_interval], [$force])

write data to datafile

=cut

sub backup_data_file {
    my($filename, $targetfile, $mode, $max_backups, $save_interval, $force) = @_;

    my @backups     = sort glob($targetfile.'.*.'.$mode);
    @backups        = grep(!/\.runtime$/mx, @backups);
    my $num         = scalar @backups;
    my $last_backup = $backups[$num-1];
    my $now         = time();

    if($save_interval && $last_backup && $last_backup =~ m/\.(\d+)\.\w$/mx) {
        my $ts = $1;
        if($save_interval > $now - $ts) {
            return;
        }
    }

    require Thruk::Utils::Crypt;
    my $old_hash = $last_backup ? Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($last_backup)) : '';
    my $new_hash = Thruk::Utils::Crypt::hexdigest(Thruk::Utils::IO::read($filename));
    if($force || $new_hash ne $old_hash) {
        copy($filename, $targetfile.'.'.$now.'.'.$mode);

        # cleanup old backups
        while($num > $max_backups) {
            unlink(shift(@backups));
            $num--;
        }
    }

    return;
}

########################################

=head2 which

    which($prog)

returns path to program or undef

=cut
sub which {
    my($prog) = @_;
    my $path = Thruk::Utils::IO::cmd("which $prog 2>/dev/null");
    return unless $path;
    chomp($path);
    return($path);
}

########################################

=head2 reduce_number

  reduce_number($number, $unit, [$divisor])

return reduced number, ex 1024B -> 1KiB

=cut

sub reduce_number {
    my($number, $unit, $divisor) = @_;
    $divisor = 1000 unless defined $divisor;
    my $unitprefix = '';

    my $divs = [
        [ 'P', 5 ],
        [ 'T', 4 ],
        [ 'G', 3 ],
        [ 'M', 2 ],
        [ 'K', 1 ],
    ];
    if($divisor == 1024 && $number > 1024) {
        $unit = "i".$unit;
    }
    for my $div (@{$divs}) {
        my $pow   = $div->[1];
        my $limit = $divisor ** $pow;
        if($number > $limit) {
            $unitprefix = $div->[0];
            $number     = $number / $limit;
            last;
        }
    }
    return($number, $unitprefix.$unit);
}

########################################

=head2 get_template_variable

  get_template_variable($c, $template, $variable)

return variable defined from template

=cut

sub get_template_variable {
    my($c, $template, $var, $stash, $noerror) = @_;

    $stash = {} unless defined $stash;

    # more stash variables to set?
    $stash = { %{$c->stash}, %{$stash} };

    $stash->{'temp'}  = $template;
    $stash->{'var'}   = $var;
    my $default_time_locale = POSIX::setlocale(POSIX::LC_TIME);
    my $data;
    require Thruk::Views::ToolkitRenderer;
    eval {
        Thruk::Views::ToolkitRenderer::render($c, 'get_variable.tt', $stash, \$data);
    };
    if($@) {
        return "" if $noerror;
        _error($@);
        return $c->detach('/error/index/13');
    }
    POSIX::setlocale(POSIX::LC_TIME, $default_time_locale);

    my $VAR1;
    ## no critic
    eval($data);
    ## use critic
    return $VAR1;
}

##############################################

=head2 precompile_templates

  precompile_templates($c)

precompile and load templates into memory

=cut

sub precompile_templates {
    my($c) = @_;
    return if $c->config->{'precompile_templates'} == 2;
    my $t0 = [gettimeofday];
    my $uniq     = {};
    for my $path (@{$c->get_tt_template_paths()}) {
        next unless -d $path;
        my $files = Thruk::Utils::IO::find_files($path, '\.tt$');
        for my $file (@{$files}) {
            $file =~ s|^$path/||gmx;
            $uniq->{$file} = 1;
        }
    }

    # no backends required
    $c->db->disable_backends() if $c->db();

    my $num = 0;
    my $stderr_output;
    do {
        ## no critic
        local *STDERR;
        ## use critic
        eval {
            open(STDERR, ">>", \$stderr_output);
        };
        _error($@) if $@;

        for my $file (keys %{$uniq}) {
            next if $file eq 'error.tt';
            next if $file =~ m|^cmd/cmd_typ_|mx;
            eval {
                $c->view("TT")->render($c, $file);
            };
            $num++;
        }
    };
    _debug($stderr_output) if $stderr_output;

    $c->config->{'precompile_templates'} = 2;
    my $elapsed = tv_interval ( $t0 );
    my $result = sprintf("%s templates precompiled in %.2fs\n", $num, $elapsed);
    _debug($result);
    return $result;
}

##########################################################

=head2 beautify_diff

  beautify_diff($text)

make diff output beauty

=cut

sub beautify_diff {
    my($text) = @_;
    $text =~ s/^\-\-\-(.*)$/<font color="#0776E8"><b>---$1<\/b><\/font>/gmx;
    $text =~ s/^\+\+\+(.*)$//gmx;
    $text =~ s/^index\ .*$//gmx;
    $text =~ s/^diff\ .*$//gmx;
    $text =~ s/^\@\@(.*)$/<font color="#0776E8"><b>\@\@$1<\/b><\/font>/gmx;
    $text =~ s/^\-(.*)$/<font color="red">-$1<\/font>/gmx;
    $text =~ s/^\+(.*)$/<font color="green">+$1<\/font>/gmx;
    return $text;
}

##########################################################

=head2 check_memory_usage

  check_memory_usage($c)

check if memory limit is above the threshold

=cut

sub check_memory_usage {
    my($c) = @_;
    my $mem = $c->stash->{'memory_end'} || Thruk::Utils::IO::get_memory_usage();
    _debug2("checking memory limit: ".$mem.' (limit: '.$c->config->{'max_process_memory'}.')');
    if($mem > $c->config->{'max_process_memory'}) {
        my $inc = "";
        if($c->app->{'previous_reqest_memory'}) {
            $inc = sprintf(" (+%dmb)", $mem - $c->app->{'previous_reqest_memory'});
        }
        my $msg = sprintf("Thruk exiting process due to memory usage: %dmb%s (limit: %dmb, pid: %d)", $mem, $inc, $c->config->{'max_process_memory'}, $$);
        log_error_with_details($c, $msg);
        print STDERR $msg,"\n";
        $c->app->graceful_stop($c);
    }
    $c->app->{'previous_reqest_memory'} = $mem;
    return;
}

##########################################################

=head2 log_error_with_details

  log_error_with_details($c, $message, $errorDetails)

log error along with details about url and logged in user

=cut

sub log_error_with_details {
    my($c, @errorDetails) = @_;
    _error("***************************");
    _error(sprintf("page:    %s %s\n", $c->req->method(), $c->req->url)) if defined $c->req->url;
    _error(sprintf("params:  %s\n", dump_params($c->req->parameters))) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
    _error(sprintf("user:    %s\n", ($c->stash->{'remote_user'} // 'not logged in')));
    _error(sprintf("address: %s%s\n", $c->req->address, ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' : '')));
    _error(sprintf("time:    %.1fs\n", scalar tv_interval($c->stash->{'time_begin'})));
    for my $details (@errorDetails) {
        for my $line (@{Thruk::Base::list($details)}) {
            if(ref $line ne '') {
                $line = dump_params($line, 0, 0);
            }
            for my $splitted (split(/\n|<br>/mx, $line)) {
                _error($splitted);
            }
        }
    }
    _error("***************************");
    return;
}

##########################################################

=head2 stop_all

    stop_all()

stop all thruk pids

=cut
sub stop_all {
    my($c) = @_;
    $c->app->stop_all();
    $c->app->graceful_stop($c);
    return(1);
}

##########################################################

=head2 base_folder

    base_folder($c)

return base etc folder

=cut
sub base_folder {
    my($c) = @_;
    return($c->config->{'etc_path'});
}

########################################

=head2 is_post

    is_post($c)

make sure this is a post request

=cut
sub is_post {
    my($c) = @_;
    return(1) if $c->req->method eq 'POST';
    $c->error("insecure request, post method required");
    $c->detach('/error/index/24');
    return;
}

########################################

=head2 check_csrf

    check_csrf($c)

ensure valid cross site request forgery token

=cut
sub check_csrf {
    my($c, $skip_request_method) = @_;

    # script generated sessions are ok, we only want to protect browsers here
    return 1 if Thruk::Base->mode_cli();
    return 1 if $c->req->header('X-Thruk-Auth-Key');
    return 1 if($c->{'session'} && $c->{'session'}->{'fake'});

    return unless($skip_request_method || is_post($c));
    my $req_addr = $c->env->{'HTTP_X_FORWARDED_FOR'} || $c->req->address;
    for my $addr (@{$c->config->{'csrf_allowed_hosts'}}) {
        return 1 if $req_addr eq $addr;
        if(CORE::index( $addr, '*' ) >= 0) {
            # convert wildcards into real regexp
            my $search = $addr;
            $search =~ s/\.\*/*/gmx;
            $search =~ s/\*/.*/gmx;
            return 1 if $req_addr =~ m/$search/mx;
        }
    }
    my $post_token  = $c->req->parameters->{'CSRFtoken'} // $c->req->parameters->{'token'};
    my $valid_token = Thruk::Utils::Filter::get_user_token($c);
    if($valid_token && $post_token && $valid_token eq $post_token) {
        return(1);
    }
    $c->error("possible csrf, no or invalid token");
    $c->detach('/error/index/24');
    return;
}


########################################

=head2 get_plugin_name

    get_plugin_name(__FILE__, __PACKAGE__)

returns the name of the plugin

=cut
sub get_plugin_name {
    my($file, $pkg) = @_;
    $pkg =~ s|::|/|gmx;
    $pkg .= '.pm';
    $file =~ s|/lib/\Q$pkg\E$||gmx;
    $file =~ s|/routes||gmx;
    $file =~ s|^.*/||gmx;
    return($file);
}

########################################

=head2 backends_list_to_hash

    backends_list_to_hash($c, $list)

returns array of backend ids converted as list of hashes

=cut
sub backends_list_to_hash {
    my($c, $backends) = @_;
    if(!defined $backends) {
        confess("backends uninitialized") unless $c->db();
        ($backends) = $c->db->select_backends('get_status');
    }
    if(ref $backends eq 'HASH') {
        # expand first
        $backends = backends_hash_to_list($c, $backends);
    }
    $backends = Thruk::Base::list($backends);
    my $backendslist = [];
    for my $back (@{$backends}) {
        my $name;
        if(ref $back eq 'HASH') {
            my $key  = (keys %{$back})[0];
            $name    = $back->{$key};
            $back    = $key;
        }
        my $backend = $c->db->get_peer_by_key($back);
        $name = $backend->{'name'} if $backend;
        push @{$backendslist}, { $back => $name };
    }
    my $hashlist = {
        backends => $backendslist,
    };
    if($c->db->{'sections_depth'} >= 1) {
        # save original list
        my($selected_backends) = $c->db->select_backends('get_hosts');

        # save completly enabled sections
        Thruk::Action::AddDefaults::update_site_panel_hashes($c, $backends);
        my $sections = _collect_enabled_sections($c->stash->{'sites'}, "/");
        $hashlist->{'sections'} = $sections if scalar @{$sections} > 0;

        # restore original list
        Thruk::Action::AddDefaults::update_site_panel_hashes($c, $selected_backends);
    }
    return($hashlist);
}

########################################
sub _collect_enabled_sections {
    my($sites, $prefix) = @_;
    my $sections = [];
    if(defined $sites->{'disabled'} && $sites->{'disabled'} == 0) {
        push @{$sections}, $prefix;
    } elsif(defined $sites->{'sub'}) {
        for my $sub (sort keys %{$sites->{'sub'}}) {
            my $name = $prefix.'/'.$sub;
            $name =~ s|^/+|/|gmx;
            push @{$sections}, @{_collect_enabled_sections($sites->{'sub'}->{$sub}, $name)};
        }
    }
    return([sort @{$sections}]);
}

########################################

=head2 backends_hash_to_list

    backends_hash_to_list($c, $hashlist)

returns array of backends (inverts backends_list_to_hash function)

=cut
sub backends_hash_to_list {
    my($c, $hashlist) = @_;
    my $backends = [];

    # hash format
    if(ref $hashlist eq 'HASH') {
        $backends = backends_hash_to_list($c, $hashlist->{'backends'});
        if($hashlist->{'sections'}) {
            Thruk::Action::AddDefaults::update_site_panel_hashes($c) unless $c->stash->{'sites'};
            for my $id (sort keys %{$c->stash->{'initial_backends'}}) {
                for my $section (@{$hashlist->{'sections'}}) {
                    if('/'.$c->stash->{'initial_backends'}->{$id} eq $section) {
                        push @{$backends}, $id;
                        last;
                    }
                }
            }
        }
        $backends = Thruk::Base::array_uniq($backends);
        return($backends);
    }

    # array format
    for my $b (@{Thruk::Base::list($hashlist)}) {
        if(ref $b eq '') {
            confess("backends uninitialized") unless $c->db();
            my $backend = $c->db->get_peer_by_key($b) || $c->db->get_peer_by_name($b);
            push @{$backends}, ($backend ? $backend->peer_key() : $b);
        } else {
            for my $key (keys %{$b}) {
                confess("backends uninitialized") unless $c->db();
                my $backend = $c->db->get_peer_by_key($key);
                if(!defined $backend && defined $b->{$key}) {
                    $backend = $c->db->get_peer_by_key($b->{$key});
                }
                if($backend) {
                    push @{$backends}, $backend->peer_key();
                } else {
                    push @{$backends}, $key;
                }
            }
        }
    }
    return($backends);
}

##############################################
sub _parse_date {
    my($string) = @_;

    # simply try to expand first
    return(_expand_timestring($string)) if $string =~ m/:/mx;

    # time arithmetic
    my @parts = split(/\s*(\-|\+)\s*/mx, $string);
    my $timestamp;

    if(scalar @parts >= 3 && $parts[0] eq '') { $parts[0] = time(); }
    if(scalar @parts == 1 && $parts[0] =~ m/^\d+$/mx && length($parts[0]) <= 8) { unshift(@parts, "now", "+"); }

    while(scalar @parts > 0) {
        my $part1 = shift @parts;
        my $val1  = _expand_timestring($part1);
        if(!defined $val1) {
            die("parse error, cannot expand '".$part1."' in ".$string);
        }
        if(!defined $timestamp) {
            $timestamp = $val1;
        }
        if(scalar @parts == 0) {
            return($timestamp);
        }
        if(scalar @parts == 1) {
            die("operator expected, got '".$parts[0]."' in ".$string);
        }
        my $op    = shift @parts;
        my $part2 = shift @parts;
        my $val2  = _expand_timestring($part2);
        if(!defined $val2) {
            die("parse error, cannot expand '".$part2."' in ".$string);
        }
        if($op eq '+') {
            $timestamp += $val2;
        }
        elsif($op eq '-') {
            $timestamp -= $val2;
        } else {
            die("unknown operator: "+$op+", +- are supported only");
        }
    }

    return($timestamp);
}

##############################################
sub _expand_timestring {
    my($string) = @_;

    # just a timestamp?
    if($string =~ m/^(\d+)$/mx && length($string) >= 9) {
        return($1);
    }

    # real date (YYYY-MM-DD HH:MM:SS)
    if($string =~ m/(\d{1,4})\-(\d{1,2})\-(\d{1,2})\ (\d{1,2}):(\d{1,2}):(\d{1,2})/mx) {
        my $timestamp = Thruk::Utils::DateTime::mktime($1,$2,$3, $4,$5,$6);
        return($timestamp);
    }

    # real date without seconds (YYYY-MM-DD HH:MM)
    if($string =~ m/(\d{1,4})\-(\d{1,2})\-(\d{1,2})\ (\d{1,2}):(\d{1,2})/mx) {
        my $timestamp = Thruk::Utils::DateTime::mktime($1,$2,$3, $4,$5,0);
        return($timestamp);
    }

    # US date format (MM-DD-YYYY HH:MM:SS)
    if($string =~ m/(\d{1,2})\-(\d{1,2})\-(\d{2,4})\ (\d{1,2}):(\d{1,2}):(\d{1,2})/mx) {
        my $timestamp = Thruk::Utils::DateTime::mktime($3,$1,$2, $4,$5,$6);
        return($timestamp);
    }

    # relative time?
    if($string =~ m/^(\-|\+|)(\d+\w*)$/mx) {
        my $direction = $1;
        my $val = expand_duration($2);
        if($direction eq '-') {
            return -$val;
        }
        return $val;
    }

    # known terms
    if($string eq 'lastmonday' || $string eq 'thisweek') {
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        my $ts = Thruk::Utils::DateTime::mktime(@monday, 0,0,0);
        return($ts);
    }
    elsif($string eq 'lastweek') {
        my @lastmonday = Monday_of_Week(Week_of_Year(Add_Delta_Days(Today(), -7)));
        my $ts = Thruk::Utils::DateTime::mktime(@lastmonday, 0,0,0);
        return($ts);
    }
    elsif($string eq 'nextweek') {
        my @lastmonday = Monday_of_Week(Week_of_Year(Add_Delta_Days(Today(), 7)));
        my $ts = Thruk::Utils::DateTime::mktime(@lastmonday, 0,0,0);
        return($ts);
    }
    elsif($string eq 'thismonth') {
        # start on month
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        my $ts = Thruk::Utils::DateTime::mktime($year,$month,1,  0,0,0);
        return($ts);
    }
    elsif($string eq 'lastmonth') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        my $lastmonth = $month - 1;
        if($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        my $ts = Thruk::Utils::DateTime::mktime($year,$lastmonth,1,  0,0,0);
        return($ts);
    }
    elsif($string eq 'nextmonth') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        my $nextmonth = $month + 1;
        if($nextmonth > 12) { $nextmonth = $nextmonth - 12; $year++; }
        my $ts = Thruk::Utils::DateTime::mktime($year,$nextmonth,1,  0,0,0);
        return($ts);
    }
    elsif($string eq 'thisyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        my $ts = Thruk::Utils::DateTime::mktime($year,1,1,  0,0,0);
        return($ts);
    }
    elsif($string eq 'lastyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        my $ts = Thruk::Utils::DateTime::mktime($year-1,1,1,  0,0,0);
        return($ts);
    }
    elsif($string eq 'nextyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        my $ts = Thruk::Utils::DateTime::mktime($year+1,1,1,  0,0,0);
        return($ts);
    }

    # everything else
    # Date::Manip increases start time, so load it here upon request
    require Date::Manip;
    Date::Manip->import(qw/UnixDate/);
    my $timestamp = UnixDate($string, '%s');
    return($timestamp);
}

########################################

=head2 expand_relative_timefilter

    expand_relative_timefilter($string)

returns expanded timefilter value

=cut
sub expand_relative_timefilter {
    my($key, $op, $val) = @_;
    # expand relative time filter for some operators
    if($op =~ m%^(>|<|>=|<=)$%mx) {
        if($val =~ m/^\-?\d+\w{1}$/mxo) {
            my $duration = expand_duration($val);
            if($duration ne $val) {
                $val = time() + $duration;
            }
        } elsif($val =~ m/(today|now|yesterday)/imxo || $val =~ m/(this|last|next)(week|day|month|year)/imxo) {
            $val = _parse_date($val);
        }
    }
    return($val);
}

########################################

=head2 convert_wildcards_to_regex

    convert_wildcards_to_regex($string)

returns regular expression with wildcards replaced

=cut
sub convert_wildcards_to_regex {
    my($str) = @_;
    $str =~ s/^\*/.*/gmx;
    return($str);
}

##############################################

=head2 find_modules

    find_modules($pattern)

returns list of found modules

=cut
sub find_modules {
    my($pattern) = @_;
    my $modules = {};
    for my $folder (@INC) {
        next unless -d $folder;
        for my $file (glob($folder.$pattern)) {
            $file =~ s|^\Q$folder/\E||gmx;
            $modules->{$file} = 1;
        }
    }
    return([sort keys %{$modules}]);
}

##############################################

=head2 get_cli_modules

    get_cli_modules()

returns list of cli modules

=cut
sub get_cli_modules {
    my $modules = find_modules('/Thruk/Utils/CLI/*.pm');
    @{$modules} = sort map {
            my $mod = $_;
            if($mod =~ s/.*\/([^\/]+)\.pm/$1/gmx) {
                $mod = lc($1);
            }
            $mod;
        } @{$modules};
    return($modules);
}

##############################################

=head2 clean_regex

    clean_regex()

returns cleaned regular expression, ex.: removes trailing .*

=cut
sub clean_regex {
    my($regex) = @_;

    $regex = Thruk::Base::trim_whitespace($regex);

    return $regex if $regex eq '.*';

    # trim leading and trailing .*(?)
    $regex =~ s/^\.\*\??//mx;
    $regex =~ s/\.\*\??$//mx;

    return($regex);
}

##############################################

=head2 get_timezone_data

    get_timezone_data()

returns list of available timezones

=cut
sub get_timezone_data {
    my($c, $add_server) = @_;

    $c->stats->profile(begin => "get_timezone_data");
    my $timezones = [];
    require Thruk::Utils::Cache;
    my $cache = Thruk::Utils::Cache->new($c->config->{'var_path'}.'/timezones.cache');
    my $data  = $cache->get('timezones');
    my $timestamp = Thruk::Utils::format_date(int(time()/600)*600, "%Y-%m-%d %H:%M");
    if(defined $data && $data->{'timestamp'} eq $timestamp) {
        $timezones = $data->{'timezones'};
    } else {
        require Date::Manip::TZ;
        my $tz  = Date::Manip::TZ->new();
        # https://metacpan.org/pod/distribution/Date-Manip/lib/Date/Manip/TZ.pod#$date
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
        my $date = [$year+1900, $mon+1, $mday, $hour, $min, $sec];
        for my $tzname (sort values %Date::Manip::Zones::ZoneNames) {
            next unless($tzname =~ m%/%mx || $tzname eq 'UTC');
            my $zone = $tz->date_period($date, $tzname);
            my $offset = $zone->[3];
            if(ref $offset ne "ARRAY") {
                $offset = [split(":", $offset)];
            }
            $offset = ($offset->[0] * 3600) + ($offset->[1] * 60) + ($offset->[2]);
            push @{$timezones}, {
                text   => $tzname,
                abbr   => $zone->[4],
                offset => $offset, # in seconds
                isdst  => $zone->[5] ? 1 : 0,
            };
        }
        $cache->set('timezones', {
            timestamp => $timestamp,
            timezones => $timezones,
        });
    }

    unshift @{$timezones}, {
        text   => 'Local Browser',
        abbr   => '',
        offset => 0,
    };
    if($add_server) {
        unshift @{$timezones}, {
            text   => 'Server Setting',
            abbr   => '',
            offset => 0,
        };
    }

    $c->stats->profile(end => "get_timezone_data");
    return($timezones);
}

##############################################

=head2 command_disabled

    command_disabled($c, $nr)

returns true if command is disabled for current user

=cut
sub command_disabled {
    my($c, $nr) = @_;

    # command disabled should be a hash
    if(ref $c->stash->{'_command_disabled'} ne 'HASH') {
        $c->stash->{'_command_disabled'} = Thruk::Base::array2hash(Thruk::Base::expand_numeric_list($c->config->{'command_disabled'}));
    }
    if(ref $c->stash->{'_command_enabled'} ne 'HASH') {
        $c->stash->{'_command_enabled'} = Thruk::Base::array2hash(Thruk::Base::expand_numeric_list($c->config->{'command_enabled'}));
        if(scalar keys %{$c->stash->{'_command_enabled'}} > 0) {
            # set disabled commands from enabled list
            for my $nr (0..999) {
                $c->stash->{'_command_disabled'}->{$nr} = $nr;
            }
            for my $nr (keys %{$c->stash->{'_command_enabled'}}) {
                delete $c->stash->{'_command_disabled'}->{$nr};
            }
        }
    }
    return 1 if defined $c->stash->{'_command_disabled'}->{$nr};
    return 0;
}

##############################################

=head2 code2name

    code2name($coderef)

returns name for given code reference

=cut
sub code2name {
    my($code) = @_;
    require B;
    my $cv = B::svref_2object ($code);
    my $gv = $cv->GV;
    return($gv->NAME);
}

##############################################

=head2 merge_service_dependencies

    merge_service_dependencies($service, [$list, $list, ...])

merge parents, depends_exec and depends_notifiy lists into a single list

=cut
sub merge_service_dependencies {
    my($service, @list) = @_;
    my $depends = [];
    for my $l (@list) {
        next unless $l;
        for my $el (@{$l}) {
            if(ref $el eq 'ARRAY') {
                @{$el} = grep(!/^$/mx,@{$el});
                push @{$depends}, $el if scalar @{$el} == 2;
            } else {
                push @{$depends}, [$service->{'host_name'}, $el] if(defined $el && $el ne "");
            }
        }
    }
    $depends = Thruk::Base::array_uniq_list($depends);
    return($depends);
}

##############################################

=head2 merge_host_dependencies

    merge_host_dependencies([$list, $list, ...])

merge depends_exec and depends_notifiy into a single list

=cut
sub merge_host_dependencies {
    my(@list) = @_;
    my $depends = [];
    for my $l (@list) {
        next unless $l;
        push @{$depends}, @{$l};
    }
    $depends = Thruk::Base::array_uniq($depends);

    # remore empty strings from the list
    @{$depends} = grep(!/^$/mx,@{$depends});

    return($depends);
}

###################################################

=head2 dump_params

    dump_params($c->req->parameters, [$max_length], [$flat])

returns stringified parameters

=cut
sub dump_params {
    my($params, $max_length, $flat) = @_;
    $max_length = 250 unless defined $max_length;
    $flat       = 1   unless defined $flat;
    $params = Thruk::Utils::IO::dclone($params) if ref $params;
    local $Data::Dumper::Indent = 0 if $flat;
    my $dump = ref $params ? Dumper($params) : $params;
    $dump    =~ s%^\$VAR1\s*=\s*%%gmx;
    $dump    = Thruk::Base::clean_credentials_from_string($dump);
    if($max_length && $max_length > 3 && length($dump) > $max_length) {
        $dump    = substr($dump, 0, ($max_length-3)).'...';
    }
    $dump    =~ s%;$%%gmx;
    return($dump);
}

##############################################

=head2 dclone

    dclone($obj)

deep clones any object

=cut
sub dclone {
    return(Thruk::Utils::IO::dclone(@_));
}

##############################################

=head2 text_table

    text_table( keys => [keys], data => <list of hashes>, [noheader => 1] )

    a key can be:

        - "string"
        - ["column name", "data key"]
        - { "name" => "column header", "key" => "data key", type => $type, format => $formatstring }

returns ascii text table or undef on errors or no data/columns

=cut
sub text_table {
    my %opt = @_;
    my $keys = $opt{'keys'};
    my $data = $opt{'data'};
    confess("data must be an array") unless ref $data eq 'ARRAY';
    return if scalar @{$data} == 0;
    if(!$keys) {
        $keys = [sort keys %{$data->[0]}];
    }
    # normalize columns
    my $columns  = [];
    my $colnames = [];
    for my $key (@{$keys}) {
        my $col = {};
        if(ref $key eq 'HASH') {
            $col = $key;
        }
        elsif(ref $key eq 'ARRAY') {
            $col->{'name'} = $key->[0];
            $col->{'key'}  = $key->[1];
        }
        else {
            $col->{'name'} = $key;
            $col->{'key'}  = $key;
        }
        $col->{'data'} = [];
        push @{$colnames}, $col->{'name'};
        push @{$columns},  $col;
    }
    return if scalar @{$columns} == 0;

    # normalize data and create format string
    my $rowformat = "";
    my $separator = "";
    for my $col (@{$columns}) {
        # find longest item
        my $key = $col->{'key'};
        my $maxsize = length($col->{"name"});
        for my $row (@{$data}) {
            my $val = $row->{$key} // "";
            if($col->{'type'}) {
                if($col->{'type'} eq 'date') {
                    if(!$val) {
                        $val = '';
                    }
                    elsif($col->{'format'}) {
                        $val = POSIX::strftime($col->{'format'}, localtime($val));
                    } else {
                        $val = scalar localtime $val;
                    }
                }
                elsif($col->{'type'} eq 'bytes') {
                    if(!defined $val || $val eq '') {
                        $val = "";
                    } else {
                        my($val1,$unit1) = reduce_number($val, 'B', 1024);
                        if($col->{'format'}) {
                            $val1 = sprintf($col->{'format'}, $val1);
                        }
                        $val = $val1.$unit1;
                    }
                }
                elsif($col->{'format'}) {
                    $val = sprintf($col->{'format'}, $val);
                }
            }
            if(ref($val) eq 'ARRAY') {
                $val = join(',', @{$val});
            }
            elsif(ref($val) eq 'HASH') {
                my @list;
                for my $k (sort keys %{$val}) {
                    my $v = $val->{$k};
                    push @list, sprintf("%s:%s", $k, $v);
                }
                $val = join(',', @list);
            }
            my $l = length($val);
            if($l > $maxsize) { $maxsize = $l; }
            push @{$col->{'data'}}, $val;
        }
        $rowformat .= "| %-".$maxsize."s ";
        $separator .= "+".('-' x ($maxsize+2));
    }
    $rowformat .= "|\n";
    $separator .= "+\n";
    my $output = "";
    if(!$opt{'noheader'}) {
        $output .= $separator;
        $output .= sprintf($rowformat, @{$colnames});
    }
    $output .= $separator;
    for my $rownum (0 .. scalar @{$data} - 1) {
        my @values;
        for my $col (@{$columns}) {
            push @values, $col->{'data'}->[$rownum] // '';
        }
        $output .= sprintf($rowformat, @values);
        $rownum++;
    }
    $output .= $separator;
    return($output);
}

########################################

=head2 get_expanded_start_date

  get_expanded_start_date($c, $blocksize)

returns start of day for expanded duration

=cut
sub get_expanded_start_date {
    my($c, $blocksize) = @_;
    # blocksize is given in days unless specified
    if($blocksize !~ m/^\d+$/mx) {
        $blocksize = expand_duration($blocksize) / 86400;
    }
    my $ts = Thruk::Utils::DateTime::start_of_day(time() - ($blocksize*86400));
    return($ts);
}

########################################

=head2 extract_time_filter

  extract_time_filter($filter)

returns start and end time filter from given query

=cut
sub extract_time_filter {
    my($filter) = @_;
    my($start, $end);
    if(ref $filter eq 'ARRAY') {
        for my $f (@{$filter}) {
            if(ref $f eq 'HASH') {
                my($s, $e) = Thruk::Utils::extract_time_filter($f);
                $start = $s if defined $s;
                $end   = $e if defined $e;
            }
        }
    }
    if(ref $filter eq 'HASH') {
        if($filter->{'-and'}) {
            my($s, $e) = Thruk::Utils::extract_time_filter($filter->{'-and'});
            $start = $s if defined $s;
            $end   = $e if defined $e;
        } else {
            if($filter->{'time'}) {
                if(ref $filter->{'time'} eq 'HASH') {
                    my $op  = (keys %{$filter->{'time'}})[0];
                    my $val = $filter->{'time'}->{$op};
                    if($op eq '>' || $op eq '>=') {
                        $start = $val;
                        return($start, $end);
                    }
                    if($op eq '<' || $op eq '<=') {
                        $end = $val;
                        return($start, $end);
                    }
                }
            }
        }
    }
    return($start, $end);
}

########################################

=head2 find_files

  find_files(...)

alias for Thruk::Utils::IO::find_files

=cut
sub find_files {
    return(Thruk::Utils::IO::find_files(@_));
}

##############################################

=head2 scale_out

    scale_out( scale => worker_num, jobs => list of jobs, worker => sub ref, collect => sub ref )

scale out worker, run jobs and returns result from collect sub.

=cut
sub scale_out {
    my %opt = @_;

    return if scalar @{$opt{'jobs'}} == 0;

    if($opt{'scale'} == 1 || scalar @{$opt{'jobs'}} == 1) {
        my $res = [];
        for my $job (@{$opt{'jobs'}}) {
            my $item = [&{$opt{'worker'}}(ref $job eq 'ARRAY' ? @{$job} : $job)];
            $item = &{$opt{'collect'}}($item);
            push @{$res}, $item if $item;
        }
        return(@{$res});
    }

    require Thruk::Pool::Simple;
    my $pool = Thruk::Pool::Simple->new(
        size    => $opt{'scale'},
        handler => $opt{'worker'},
    );
    $pool->add_bulk($opt{'jobs'});
    return($pool->remove_all($opt{'collect'}));
}

########################################

=head2 page_data

  page_data($c, $data, [$result_size], [$total_size], [$already_paged])

adds paged data set to the template stash.
Data will be available as 'data'
The pager itself as 'pager'

=cut

sub page_data {
    my($c, $data, $default_result_size, $total_size, $already_paged) = @_;
    $c    = $Thruk::Globals::c unless $c;
    $data = [] unless $data;
    return $data unless defined $c;
    $default_result_size = $c->stash->{'default_page_size'} unless defined $default_result_size;

    # set some defaults
    $c->stash->{'data'}  = $data;
    $c->stash->{'pager'} = {
            page        => 1,
            total_pages => 1,
            total_items => $total_size // scalar @{$data},
            entries     => $default_result_size,
    };
    my $pager = $c->stash->{'pager'};

    # page only in html mode
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    return $data unless $view_mode eq 'html';

    my $entries = $c->req->parameters->{'entries'} || $default_result_size;
    return $data unless defined $entries;
    return $data unless $entries =~ m/^(\d+|all)$/mx;
    $c->stash->{'pager'}->{'entries'} = $entries;

    if($entries eq 'all') { $entries = $pager->{'total_items'}; }
    if($entries > 0) {
        $pager->{'total_pages'} = POSIX::ceil($pager->{'total_items'} / $entries) || 1;
    } else {
        return $data;
    }
    if($pager->{'total_items'} == 0) {
        return $data;
    }

    # current page set by get parameter
    $pager->{'page'} = $c->req->parameters->{'page'} // 1;

    # current page set by jump anchor
    if(defined $c->req->parameters->{'jump'}) {
        my $nr = 0;
        my $jump = $c->req->parameters->{'jump'};
        if(exists $data->[0]->{'description'}) {
            for my $row (@{$data}) {
                $nr++;
                if(defined $row->{'host_name'} and defined $row->{'description'} and $row->{'host_name'}."_".$row->{'description'} eq $jump) {
                    $pager->{'page'} = POSIX::ceil($nr / $entries);
                    last;
                }
            }
        }
        elsif(exists $data->[0]->{'name'}) {
            for my $row (@{$data}) {
                $nr++;
                if(defined $row->{'name'} and $row->{'name'} eq $jump) {
                    $pager->{'page'} = POSIX::ceil($nr / $entries);
                    last;
                }
            }
        }
    }

    if($pager->{'page'} !~ m|^\d+$|mx) { $pager->{'page'} = 1; }
    if($pager->{'page'} < 0)           { $pager->{'page'} = 1; }
    if($pager->{'page'} > $pager->{'total_pages'}) { $pager->{'page'} = $pager->{'total_pages'}; }

    if(!$already_paged) {
        if($pager->{'page'} == $pager->{'total_pages'}) {
            $data = [splice(@{$data}, $entries*($pager->{'page'}-1), $pager->{'total_items'} - $entries*($pager->{'page'}-1))];
        } else {
            $data = [splice(@{$data}, $entries*($pager->{'page'}-1), $entries)];
        }
        $c->stash->{'data'} = $data;
    }

    return $data;
}

##############################################

=head2 render_db_profile

  render_db_profile($c, $profiles)

return rendered db query profiles

=cut
sub render_db_profile {
    my($c, $name, $db_profiles) = @_;
    return([]) unless $db_profiles;
    return([]) unless @{$db_profiles} > 0;

    my $total_duration = 0;
    for my $p (@{$db_profiles}) {
        $total_duration += $p->{duration};
    }

    my $stash = {
        profiles       => $db_profiles,
        total_duration => $total_duration,
    };
    # more stash variables to set?
    $stash = { %{$c->stash}, %{$stash} };
    my $data;
    require Thruk::Views::ToolkitRenderer;
    eval {
        local $Thruk::Globals::tt_profiling = 0;
        Thruk::Views::ToolkitRenderer::render($c, '_db_stats.tt', $stash, \$data);
    };
    if($@) {
        _warn($@);
        return([]);
    }

    my $profile = {
        name => $name,
        text => "text",
        html => $data,
        time => Time::HiRes::time(),
    };

    return($profile);
}

##############################################

=head2 has_node_module

  has_node_module($c, $module_name)

return true if npm module is installed

=cut
sub has_node_module {
    my($c, $module_name) = @_;
    return unless Thruk::Base::has_binary("node");
    return unless Thruk::Base::has_binary("npm");

    my($out, $rc) = Thruk::Utils::IO::cmd($c, ["npm", "ls", "-g"]);
    if($out =~ m/$module_name/mx) {
        return 1;
    }

    ($out, $rc) = Thruk::Utils::IO::cmd($c, ["npm", "ls"]);
    if($out =~ m/$module_name/mx) {
        return 1;
    }
    return;
}

##############################################

1;
