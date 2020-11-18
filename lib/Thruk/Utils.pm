package Thruk::Utils;

=head1 NAME

Thruk::Utils - Utilities Collection for Thruk

=head1 DESCRIPTION

Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Thruk::Utils::IO ();
use Thruk::Utils::CookieAuth ();
use Thruk::Utils::DateTime ();
use Thruk::Utils::Log qw/:all/;
use Carp qw/confess croak longmess/;
use Data::Dumper qw/Dumper/;
use Date::Calc qw/Localtime Monday_of_Week Week_of_Year Today Add_Delta_Days/;
use File::Slurp qw/read_file/;
use Encode qw/encode encode_utf8 decode is_utf8/;
use File::Copy qw/move copy/;
use File::Temp qw/tempfile/;
use Time::HiRes qw/gettimeofday tv_interval/;
use POSIX ();
use MIME::Base64 ();
use URI::Escape ();

use Module::Load qw/load/;

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
    for ($number) {
        /\./mx
        ? s/(?<=\d)(?=(\d{3})+(?:\.))/,/gmx
        : s/(?<=\d)(?=(\d{3})+(?!\d))/,/gmx;
    }
    return $number;
}

##############################################

=head2 format_disk_size

  my $string = format_disk_size($number)

return human readable disk size

=cut
sub format_disk_size {
    my($number) = @_;
    my $str = sprintf("%.1f%s", reduce_number($number, "B", 1024));
    return $str;
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
    if($@) {
        my $error_message = "invalid regular expression: ".Thruk::Utils::Filter::escape_html($@);
        $error_message =~ s/\s+at\s+.*$//gmx;
        $error_message =~ s/in\s+regex\;/in regex<br \/>/gmx;
        $error_message =~ s/HERE\s+in\s+m\//HERE in <br \/>/gmx;
        $error_message =~ s/\/$//gmx;
        set_message($c, { style => 'fail_message', msg => $error_message, escape => 0});
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
    $c->cookie('thruk_message' => $style.'~~'.$message, { path  => $c->stash->{'cookie_path'} });
    # use escaped data if possible, but store original data as well
    $c->stash->{'thruk_message'}         = $style.'~~'.($escaped_message // $message);
    $c->stash->{'thruk_message_details'} = $escaped_details // $details;
    $c->stash->{'thruk_message_style'}       = $style;
    $c->stash->{'thruk_message_raw'}         = $message;
    $c->stash->{'thruk_message_details_raw'} = $details;
    $c->res->code($code) if defined $code;

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
    my $dir  = $c->config->{ssi_path};
    my @files = sort grep { /\A${page}-${type}(-.*)?.ssi\z/mx } keys %{ $c->config->{ssi_includes} };
    my $output = "";
    for my $inc (@files) {
        $output .= "\n<!-- BEGIN SSI $dir/$inc -->\n" if Thruk->verbose;
        if( -x "$dir/$inc" ) {
          if(open(my $ph, '-|', "$dir/$inc 2>&1")) {
            while(defined(my $line = <$ph>)) { $output .= $line; }
            CORE::close($ph);
          } else {
            carp("cannot execute ssi $dir/$inc: $!");
          }
        } elsif( -r "$dir/$inc" ) {
            my $content = read_file("$dir/$inc");
            $content = Thruk::Utils::decode_any($content);
            unless(defined $content) { carp("cannot open ssi $dir/$inc: $!") }
            $output .= $content;
        } else {
            _warn("$dir/$inc is no longer accessible, please restart thruk to initialize ssi information");
        }
        $output .= "\n<!-- END SSI $dir/$inc -->\n" if Thruk->verbose;
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

    $files = Thruk::Utils::list($files);
    return unless scalar @{$files} > 0;

    my $comments    = {};
    my $lastcomment = "";
    $macros         = {} unless defined $macros;
    for my $file (@{$files}) {
        next unless -f $file;
        open(my $fh, '<', $file) or die("cannot read file ".$file.": ".$!);
        while(my $line = <$fh>) {
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
        CORE::close($fh) or die("cannot close file ".$file.": ".$!);
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

=head2 array2hash

  array2hash($data, [ $key, [ $key2 ]])

create a hash by key

=cut
sub array2hash {
    my($data, $key, $key2) = @_;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key2) {
        for my $d (@{$data}) {
            $hash{$d->{$key}}->{$d->{$key2}} = $d;
        }
    } elsif(defined $key) {
        %hash = map { $_->{$key} => $_ } @{$data};
    } else {
        %hash = map { $_ => $_ } @{$data};
    }

    return \%hash;
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

=head2 get_custom_vars

  get_custom_vars($c, $obj, [$prefix], [$add_host])

return custom variables in a hash

=cut
sub get_custom_vars {
    my($c, $data, $prefix, $add_host) = @_;
    $prefix = '' unless defined $prefix;

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
    if($c && $c->config->{'action_menu_apply'} && !$hash{'THRUK_ACTION_MENU'}) {
        APPLY:
        for my $menu (sort keys %{$c->config->{'action_menu_apply'}}) {
            for my $pattern (@{list($c->config->{'action_menu_apply'}->{$menu})}) {
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

    my $vars        = Thruk::Utils::list($c->config->{$search});
    my $custom_vars = get_custom_vars($c, $data, $prefix, $add_host);

    my $already_added = {};
    for my $cust_name (sort keys %{$custom_vars}) {
        next unless Thruk::Utils::check_custom_var_list($cust_name, $vars);

        # expand macros in custom vars
        my $cust_value = $custom_vars->{$cust_name};
        if(defined $host and defined $service) {
                #($cust_value, $rc)...
                ($cust_value, undef) = $c->{'db'}->_replace_macros({
                    string  => $cust_value,
                    host    => $host,
                    service => $service,
                });
        } elsif (defined $host) {
                #($cust_value, $rc)...
                ($cust_value, undef) = $c->{'db'}->_replace_macros({
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
    confess("username not allowed") if check_for_nasty_filename($username);

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
        confess("username not allowed") if check_for_nasty_filename($username);
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

=head2 array_uniq

  array_uniq($array)

return uniq elements of array

=cut

sub array_uniq {
    my($array) = @_;

    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @{$array};

    return \@unique;
}


########################################

=head2 array_uniq_obj

  array_uniq_obj($array_of_hashes)

return uniq elements of array, examining all hash keys except peer_key

=cut

sub array_uniq_obj {
    my($array) = @_;

    my @unique;
    my %seen;
    my $x = 0;
    for my $el (@{$array}) {
        my $values = [];
        for my $key (sort keys %{$el}) {
            if($key =~ /^peer_(key|addr|name)$/mx) {
                $el->{$key} = list($el->{$key});
                next;
            }
            push @{$values}, ($el->{$key} // "");
        }
        my $ident = join(";", @{$values});
        if(defined $seen{$ident}) {
            # join peer_* information
            for my $key (qw/peer_key peer_addr peer_name/) {
                next unless $el->{$key};
                push @{$unique[$seen{$ident}]->{$key}}, @{$el->{$key}};
            }
            next;
        }
        $seen{$ident} = $x;
        push @unique, $el;
        $x++;
    }

    return \@unique;
}

########################################

=head2 array_uniq_list

  array_uniq_list($array_of_lists)

return uniq elements of array, examining all list members

=cut

sub array_uniq_list {
    my($array) = @_;

    my @unique;
    my %seen;
    for my $el (@{$array}) {
        my $ident = join(";", @{$el});
        next if $seen{$ident};
        $seen{$ident} = 1;
        push @unique, $el;
    }

    return \@unique;
}

########################################

=head2 hash_invert

  hash_invert($hash)

return hash with keys and values inverted

=cut

sub hash_invert {
    my($hash) = @_;

    my %invert;
    for my $k (sort keys %{$hash}) {
        my $v = $hash->{$k};
        $invert{$v} = $k;
    }

    return \%invert;
}

########################################

=head2 logs2xls

  logs2xls($c)

save excel file by background job

=cut

sub logs2xls {
    my($c, $type) = @_;
    Thruk::Utils::Status::set_selected_columns($c, [''], ($type || 'log'));
    $c->stash->{'data'} = $c->{'db'}->get_logs(%{$c->stash->{'log_filter'}});
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
    my $output = Thruk::Views::ExcelRenderer::render($c, $template);
    if($c->config->{'no_external_job_forks'}) {
        #my($fh, $filename)...
        my(undef, $filename)     = tempfile();
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
    my $peer = $c->{'db'}->get_peer_by_key($obj->{'peer_key'});
    return($url) unless $peer;
    if($peer->{'type'} ne 'http') {
        return($url);
    }

    my $proxy_prefix = $c->stash->{'url_prefix'}.'cgi-bin/proxy.cgi/'.$obj->{'peer_key'};

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
    my $peer = $c->{'db'}->get_peer_by_key($id);
    my $url = "";
    if($peer->{'fed_info'}) {
        $url = $peer->{'fed_info'}->{'addr'}->[scalar @{$peer->{'fed_info'}->{'addr'}}-1];
    }
    if($peer->{'type'} eq 'http') {
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
        for my $regex (qw|/pnp[^/]*/|) {
            if($obj->{$type} =~ m|(^.*?$regex)|mx) {
                return(proxifiy_url($c, $obj, $1.'/index.php'));
            }
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
        if($obj->{$type} =~ m%histou\.js\?|/grafana/%mx) {
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
            for my $regex (@{list($graph_word)}) {
                if ($obj->{$type} =~ m|$regex|mx){
                    $action_url = $obj->{$type};
                    last;
                }
            }
        }
    }

    if(defined $obj->{'name'}) {
        #host obj
        return get_action_url($c, 1, 0, $action_url, $obj->{'name'});
    }
    elsif(defined $obj->{'host_name'} && defined $obj->{'description'}) {
        #service obj
        return get_action_url($c, 1, 0, $action_url, $obj->{'host_name'}, $obj->{'description'});
    }
    else {
        #unknown host
        return '';
    }
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
        my $svcdata = $c->{'db'}->get_services(filter => [{ host_name => $options->{'host'}, description => $options->{'service'} }]);
        if(scalar @{$svcdata} == 0) {
            _error("no such service ".$options->{'service'}." on host ".$options->{'host'});
            return("");
        }
        $pnpurl     = get_pnp_url($c, $svcdata->[0], 1);
        $grafanaurl = get_histou_url($c, $svcdata->[0], 1);
        $custvars   = Thruk::Utils::get_custom_vars($c, $svcdata->[0]);
    } else {
        my $hstdata = $c->{'db'}->get_hosts(filter => [{ name => $options->{'host'}}]);
        if(scalar @{$hstdata} == 0) {
            _error("no such host ".$options->{'host'});
            return("");
        }
        $pnpurl                = get_pnp_url($c, $hstdata->[0], 1);
        $grafanaurl            = get_histou_url($c, $hstdata->[0], 1);
        $options->{'service'}  = '_HOST_' if $pnpurl;
        $custvars              = Thruk::Utils::get_custom_vars($c, $hstdata->[0]);
    }

    $c->stash->{'last_graph_type'} = 'pnp';
    if($grafanaurl) {
        # simply redirect?
        if($grafanaurl =~ m|/thruk/cgi\-bin/proxy\.cgi/([^/]+)/|mx) {
            my $peer_id  = $1;
            my $proxyurl = Thruk::Utils::proxifiy_me($c, $peer_id);
            if($proxyurl) {
                if($options->{'follow'}) {
                    return($c->{'db'}->rpc($peer_id, "Thruk::Utils::get_perf_image", [$c, $options]));
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
            $grafanaurl .= '&customCSSFile='.URI::Escape::uri_escape('data:text/css;base64,'.MIME::Base64::encode_base64($css));
        }
        $c->stash->{'last_graph_type'} = 'grafana';
        $grafanaurl =~ s|/dashboard/|/dashboard-solo/|gmx;
        # grafana panel ids usually start at 1 (or 2 with old versions)
        delete $options->{'source'} if(defined $options->{'source'} && $options->{'source'} eq 'null');
        $options->{'source'} = ($custvars->{'GRAPH_SOURCE'} || $c->config->{'grafana_default_panelId'} || '1') unless defined $options->{'source'};
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
                    return($c->{'db'}->rpc($peer_id, "Thruk::Utils::get_perf_image", [$c, $options]));
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
    local $ENV{PHANTOMJSSCRIPTOPTIONS} = '--cookie=thruk_auth,'.$sessionid.' --format='.$options->{'format'};

    # call login hook, because it might transfer our sessions to remote graphers
    if($c->config->{'cookie_auth_login_hook'}) {
        Thruk::Utils::IO::cmd($c, $c->config->{'cookie_auth_login_hook'});
    }

    my($fh, $filename) = tempfile();
    CORE::close($fh);
    my $cmd = $exporter.' "'.$options->{'host'}.'" "'.$options->{'service'}.'" "'.$options->{'width'}.'" "'.$options->{'height'}.'" "'.$options->{'start'}.'" "'.$options->{'end'}.'" "'.($pnpurl||'').'" "'.$filename.'" "'.$options->{'source'}.'"';
    if($grafanaurl) {
        $cmd = $exporter.' "'.$options->{'width'}.'" "'.$options->{'height'}.'" "'.$options->{'start'}.'" "'.$options->{'end'}.'" "'.$grafanaurl.'" "'.$filename.'"';
    }
    Thruk::Utils::IO::cmd($c, $cmd);
    unlink($c->stash->{'fake_session_file'});
    if(-s $filename) {
        my $imgdata  = read_file($filename);
        unlink($filename);
        if($options->{'format'} eq 'png') {
            return '' if substr($imgdata, 0, 10) !~ m/PNG/mx; # check if this is a real image
        }
        return $imgdata;
    }
    return "";
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

    my $c = $Thruk::Request::c or die("not initialized!");
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

    if($ENV{'OMD_SITE'}) {
        my $site = $ENV{'OMD_SITE'};
        if($link =~ m/^\/\Q$site\E\/logos\/([^\.]*\.\w+)$/mx) {
            return($link);
        }
    }

    confess("unknown url scheme in absolute_url('".$baseurl."', '".$link."')");
}

##############################################

=head2 get_fake_session

  get_fake_session($c, [$sessionid], [$roles], [$address])

create and return fake session id along with session data for current user

=cut

sub get_fake_session {
    my($c, $id, $username, $roles, $ip) = @_;

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
    $sessiondata = Thruk::Utils::CookieAuth::store_session($c->config, $id, $sessiondata);
    $c->stash->{'fake_session_id'}   = $sessiondata->{'private_key'};
    $c->stash->{'fake_session_file'} = $sessiondata->{'file'};
    return($sessiondata->{'private_key'}, $sessiondata) if wantarray;
    return($sessiondata->{'private_key'});
}

########################################

=head2 get_action_url

  get_action_url($c, $escape_fun, $remove_render, $action_url, $host, $svc)

return action_url modified for object (host/service) if we use graphite
escape_fun is use to escape special char (html or quotes)
remove_render remove /render in action url

=cut

sub get_action_url {
    my($c, $escape_fun, $remove_render, $action_url, $host, $svc) = @_;

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
    elsif($action_url =~ m/\/histou\.js\?/mx) {
        $action_url =~ s/&amp;/&/gmx;
        $action_url =~ s/&/&amp;/gmx;
        my $popup_url = $action_url;
        $popup_url =~ s|/dashboard/|/dashboard-solo/|gmx;
        $popup_url .= '&amp;panelId='.$c->config->{'grafana_default_panelId'};
        $action_url .= "' class='histou_tips' rel='".$popup_url;
        return($action_url);
    }

    if ($graph_word) {
        for my $regex (@{list($graph_word)}) {
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

=head2 list

  list($ref)

return list of ref unless it is already a list

=cut

sub list {
    my($d) = @_;
    return [] unless defined $d;
    return $d if ref $d eq 'ARRAY';
    return([$d]);
}

########################################

=head2 extract_list

  extract_list($var, $separator)

return list by splitting $var by $sep ($var can be an array or string)

=cut

sub extract_list {
    my($var, $sep) = @_;
    my $result = [];
    for my $v (@{list($var)}) {
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

=head2 choose_mobile

  choose_mobile($c, $url)

let the user choose a mobile page or not

=cut

sub choose_mobile {
    my($c,$url) = @_;

    return unless defined $c->config->{'use_feature_mobile'};
    return unless defined $c->req->header('user-agent');
    my $found = 0;
    for my $agent (split(/\s*,\s*/mx, $c->config->{'mobile_agent'})) {
        $found++ if $c->req->header('user-agent') =~ m/$agent/mx;
    }
    return unless $found;

    my $choose_mobile;
    if(defined $c->cookie('thruk_mobile')) {
        my $cookie = $c->cookie('thruk_mobile');
        $choose_mobile = $cookie->value;
        return if $choose_mobile == 0;
    }

    $c->stash->{'title'}     = $c->config->{'name'};
    $c->stash->{'template'} = 'mobile_choose.tt';
    $c->stash->{'redirect'}  = $url;
    if(defined $choose_mobile and $choose_mobile == 1) {
        return $c->redirect_to($c->stash->{'redirect'});
    }
    return 1;
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

    if($c->config->{'cron_pre_edit_cmd'}) {
        local $< = $> if $< == 0; # set real and effective uid to user, crontab will still be run as root on some systems otherwise
        my($fh2, $tmperror) = tempfile();
        Thruk::Utils::IO::close($fh2, $tmperror);
        my $cmd = $c->config->{'cron_pre_edit_cmd'}." 2>>".$tmperror;
        my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd);
        my $errors = read_file($tmperror);
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
    username  => username of the resulting user
    auth_src  => hint about where this user came from
    superuser => superuser can change to other user names, roles will not exceed initial role set
    internal  => internal technical user can change into any user and has admin roles
    force     => force setting new user, even if already authenticated
    roles     => maximum set of roles
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
        } elsif($c->user->{'superuser'}) {
            return(change_user($c, $options{'username'}, $options{'auth_src'}));
        } else {
            # not allowed
            return;
        }
        delete $c->{'user'};
        delete $c->stash->{'remote_user'};
        delete $c->{'session'};
    }
    $c->authenticate(
            username  => $options{'username'},
            superuser => $options{'superuser'},
            internal  => $options{'internal'},
            auth_src  => $options{'auth_src'},
            roles     => $options{'roles'},
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
    if(Thruk->mode eq 'FASTCGI' && ! -f $pidfile) {
        open(my $fh, '>', $pidfile) || warn("cannot write $pidfile: $!");
        print $fh $$."\n";
        Thruk::Utils::IO::close($fh, $pidfile);
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
    if(Thruk->mode eq 'FASTCGI') {
        my $pidfile  = $c->config->{'tmp_path'}.'/thruk.pid';
        if(-f $pidfile) {
            my $pids = [split(/\s/mx, read_file($pidfile))];
            for my $pid (@{$pids}) {
                next unless($pid and $pid =~ m/^\d+$/mx);
                system("sleep 1 && kill -HUP $pid &");
            }
        } else {
            my $pid = $$;
            system("sleep 1 && kill -HUP $pid &");
        }
        Thruk::Utils::append_message($c, ' Thruk has been restarted.');
        return $c->redirect_to($c->stash->{'url_prefix'}.'startup.html?wait#'.$redirect);
    } else {
        Thruk::Utils::append_message($c, ' Changes take effect after Restart.');
        return $c->redirect_to($redirect);
    }
    return;
}


##############################################

=head2 wait_after_reload

  wait_after_reload($c, [$backend], [$timestamp])

wait up to 60 seconds till the core responds

=cut

sub wait_after_reload {
    my($c, $pkey, $time) = @_;
    $c->stats->profile(begin => "wait_after_reload ($time)");
    $pkey = $c->stash->{'param_backend'} unless $pkey;
    my $start = time();
    if(!$pkey && !$time) { sleep 3; }

    # wait until core responds again
    my $procinfo = {};
    my $done     = 0;
    my $options = {};
    if($ENV{'THRUK_LMD_VERSION'} && Thruk::Utils::version_compare($ENV{'THRUK_LMD_VERSION'}, '1.3.3')) {
        $options = {
                'header' => {
                    'WaitTimeout'   => 2000,
                    'WaitTrigger'   => 'all', # using something else seems not to work all the time
                    'WaitCondition' => "program_start > ".$time,
                },
        };
    }
    while($start > time() - 30) {
        $procinfo = {};
        eval {
            local $SIG{ALRM}   = sub { die "alarm\n" };
            alarm(5);
            $c->{'db'}->reset_failed_backends();
            $procinfo = $c->{'db'}->get_processinfo(backend => $pkey, options => $options);
        };
        alarm(0);
        if($@) {
            $c->stats->profile(comment => "get_processinfo: ".$@);
            _debug('still waiting for core reload for '.(time()-$start).'s: '.$@);
        }
        elsif($pkey && $c->stash->{'failed_backends'}->{$pkey}) {
            $c->stats->profile(comment => "get_processinfo: ".$c->stash->{'failed_backends'}->{$pkey});
            _debug('still waiting for core reload for '.(time()-$start).'s: '.$c->stash->{'failed_backends'}->{$pkey});
        }
        elsif($pkey and $time) {
            # not yet restarted
            if($procinfo and $procinfo->{$pkey} and $procinfo->{$pkey}->{'program_start'}) {
                $c->stats->profile(comment => "core program_start: ".$procinfo->{$pkey}->{'program_start'});
                if($procinfo->{$pkey}->{'program_start'} > $time) {
                    $done = 1;
                    last;
                } else {
                    _debug('still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($procinfo->{$pkey}->{'program_start'})));
                }
            }
        }
        elsif($time) {
            my $newest_core = 0;
            if($procinfo) {
                for my $key (keys %{$procinfo}) {
                    if($procinfo->{$key}->{'program_start'} > $newest_core) { $newest_core = $procinfo->{$key}->{'program_start'}; }
                }
                $c->stats->profile(comment => "core program_start: ".$newest_core);
                if($newest_core > $time) {
                    $done = 1;
                    last;
                } else {
                    _debug('still waiting for core reload for '.(time()-$start).'s, last restart: '.(scalar localtime($newest_core)));
                }
            }
        } else {
            $done = 1;
            last;
        }
        if(time() - $start <= 5) {
            Time::HiRes::sleep(0.3);
        } else {
            sleep(1);
        }
    }
    $c->stats->profile(end => "wait_after_reload ($time)");
    if($done) {
        # clean up cached groups which may have changed
        $c->cache->clear();
    } else {
        _error('waiting for core reload failed');
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

    my $old_hash = $last_backup ? Thruk::Utils::Crypt::hexdigest(scalar read_file($last_backup)) : '';
    my $new_hash = Thruk::Utils::Crypt::hexdigest(scalar read_file($filename));
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

##########################################################

=head2 decode_any

read and decode string from either utf-8 or iso-8859-1

=cut
sub decode_any {
    eval { $_[0] = decode( "utf8", $_[0], Encode::FB_CROAK ) };
    if($@) { # input was not utf8
        return($_[0]) if $@ =~ m/\QCannot decode string with wide characters\E/mxo; # since Encode.pm 2.53 decode_utf8 no longer noops when utf8 is already on
        return($_[0]) if $@ =~ m/\QWide character at\E/mxo;                         # since Encode.pm ~2.90 message changed
        $_[0] = decode( "iso-8859-1", $_[0], Encode::FB_WARN );
    }
    return $_[0];
}

########################################

=head2 ensure_utf8

    ensure_utf8($str)

makes sure the given string is utf8

=cut
sub ensure_utf8 {
    $_[0] = decode_any($_[0]);
    return($_[0]) if is_utf8($_[0]); # since Encode.pm 2.53 decode_utf8 no longer noops when utf8 is already on
    return(encode_utf8($_[0]));
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

return reduced number, ex 1024B -> 1KB

=cut

sub reduce_number {
    my($number, $unit, $divisor) = @_;
    $divisor = 1000 unless defined $divisor;
    my $unitprefix = '';

    my $divs = [
        [ 'T', 4 ],
        [ 'G', 3 ],
        [ 'M', 2 ],
        [ 'K', 1 ],
    ];
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

    # more stash variables to set?
    $stash = {} unless defined $stash;
    for my $key (keys %{$stash}) {
        $c->stash->{$key} = $stash->{$key};
    }

    $c->stash->{'temp'}  = $template;
    $c->stash->{'var'}   = $var;
    my $default_time_locale = POSIX::setlocale(POSIX::LC_TIME);
    my $data;
    eval {
        Thruk::Views::ToolkitRenderer::render($c, 'get_variable.tt', undef, \$data);
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
        my $files = find_files($path, '\.tt$');
        for my $file (@{$files}) {
            $file =~ s|^$path/||gmx;
            $uniq->{$file} = 1;
        }
    }

    # no backends required
    $c->{'db'}->disable_backends() if $c->{'db'};

    my $stderr_output;
    # First, save away STDERR
    open my $savestderr, ">&STDERR";
    eval {
        # breaks on fastcgi server with strange error
        close STDERR;
        open(STDERR, ">", \$stderr_output);
    };
    _error($@) if $@;

    my $num = 0;
    for my $file (keys %{$uniq}) {
        next if $file eq 'error.tt';
        next if $file =~ m|^cmd/cmd_typ_|mx;
        eval {
            $c->view("TT")->render($c, $file);
        };
        $num++;
    }
    # Now close and restore STDERR to original condition.
    eval {
        # breaks on fastcgi server with strange error
        close STDERR;
        ## no critic
        open STDERR, ">&".$savestderr;
        ## use critic
    };
    _error($@) if $@;

    $c->config->{'precompile_templates'} = 2;
    my $elapsed = tv_interval ( $t0 );
    my $result = sprintf("%s templates precompiled in %.2fs\n", $num, $elapsed);
    _debug($result);
    return $result;
}

##########################################################

=head2 find_files

  find_files($folder, $pattern)

return list of files for folder and pattern

=cut

sub find_files {
    my ( $dir, $match ) = @_;
    my @files;
    $dir =~ s/\/$//gmxo;

    my @tmpfiles;
    opendir(my $dh, $dir) or confess("cannot open directory $dir: $!");
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        push @tmpfiles, $file;
    }
    closedir $dh;

    for my $file (@tmpfiles) {
        # follow sub directories
        if(-d $dir."/".$file."/.") {
            push @files, @{find_files($dir."/".$file, $match)};
        }

        # if its a file, make sure it matches our pattern
        if(defined $match) {
            my $test = $dir."/".$file;
            next unless $test =~ m/$match/mx;
        }

        push @files, $dir."/".$file;
    }

    return \@files;
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
    my $mem = $c->stash->{'memory_end'} || Thruk::Backend::Pool::get_memory_usage();
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
    _error(sprintf("page:    %s\n", $c->req->url)) if defined $c->req->url;
    _error(sprintf("params:  %s\n", Thruk::Utils::dump_params($c->req->parameters))) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
    _error(sprintf("user:    %s\n", ($c->stash->{'remote_user'} // 'not logged in')));
    _error(sprintf("address: %s%s\n", $c->req->address, ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' : '')));
    _error(sprintf("time:    %.1fs\n", scalar tv_interval($c->stash->{'time_begin'})));
    for my $details (@errorDetails) {
        for my $line (@{list($details)}) {
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
    return 1 if(Thruk->mode eq 'CLI');
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
        confess("backends uninitialized") unless $c->{'db'};
        ($backends) = $c->{'db'}->select_backends('get_status');
    }
    if(ref $backends eq 'HASH') {
        # expand first
        $backends = backends_hash_to_list($c, $backends);
    }
    $backends = list($backends);
    my $backendslist = [];
    for my $back (@{$backends}) {
        my $name;
        if(ref $back eq 'HASH') {
            my $key  = (keys %{$back})[0];
            $name    = $back->{$key};
            $back    = $key;
        }
        my $backend = $c->{'db'}->get_peer_by_key($back);
        $name = $backend->{'name'} if $backend;
        push @{$backendslist}, { $back => $name };
    }
    my $hashlist = {
        backends => $backendslist,
    };
    if($c->{'db'}->{'sections_depth'} >= 1) {
        # save original list
        my($selected_backends, undef, undef) = $c->{'db'}->select_backends('get_hosts');

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
        $backends = Thruk::Utils::array_uniq($backends);
        return($backends);
    }

    # array format
    for my $b (@{list($hashlist)}) {
        if(ref $b eq '') {
            confess("backends uninitialized") unless $c->{'db'};
            my $backend = $c->{'db'}->get_peer_by_key($b) || $c->{'db'}->get_peer_by_name($b);
            push @{$backends}, ($backend ? $backend->peer_key() : $b);
        } else {
            for my $key (keys %{$b}) {
                confess("backends uninitialized") unless $c->{'db'};
                my $backend = $c->{'db'}->get_peer_by_key($key);
                if(!defined $backend && defined $b->{$key}) {
                    $backend = $c->{'db'}->get_peer_by_key($b->{$key});
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
        } elsif($val =~ m/(today|now|yesterday)/mxo || $val =~ m/(this|last|next)(week|day|month|year)/mxo) {
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

    # trim leading and trailing whitespace
    $regex =~ s/^\s+//mx;
    $regex =~ s/\s+$//mx;

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

    my $timezones = [];
    my $cache = Thruk::Utils::Cache->new($c->config->{'var_path'}.'/timezones.cache');
    my $data  = $cache->get('timezones');
    my $timestamp = Thruk::Utils::format_date(time(), "%Y-%m-%d %H");
    if(defined $data && $data->{'timestamp'} eq $timestamp) {
        $timezones = $data->{'timezones'};
    } else {
        load "DateTime";
        load "DateTime::TimeZone";
        my $dt = DateTime->now;
        for my $name (DateTime::TimeZone->all_names) {
            $dt->set_time_zone($name);
            push @{$timezones}, {
                text   => $name,
                abbr   => $dt->time_zone()->short_name_for_datetime($dt),
                offset => $dt->offset(),
                isdst  => $dt->is_dst() ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false,
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
        $c->stash->{'_command_disabled'} = array2hash(Thruk::Config::expand_numeric_list($c->config->{'command_disabled'}));
    }
    if(ref $c->stash->{'_command_enabled'} ne 'HASH') {
        $c->stash->{'_command_enabled'} = array2hash(Thruk::Config::expand_numeric_list($c->config->{'command_enabled'}));
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

=head2 check_for_nasty_filename

    check_for_nasty_filename($filename)

returns true if nasty characters have been found and the filename is NOT safe for use

=cut
sub check_for_nasty_filename {
    my($name) = @_;
    confess("no name") unless defined $name;
    if($name =~ m/(\.\.|\/|\n)/mx) {
        return(1);
    }
    return;
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
                push @{$depends}, $el;
            } else {
                push @{$depends}, [$service->{'host_name'}, $el];
            }
        }
    }
    $depends = array_uniq_list($depends);
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
    $depends = array_uniq($depends);
    return($depends);
}

###################################################

=head2 dump_params

    dump_params($c->req->parameters)

returns stringified parameters

=cut
sub dump_params {
    my($params) = @_;
    $params = dclone($params);
    local $Data::Dumper::Indent = 0;
    my $dump = Dumper($params);
    $dump    =~ s%^\$VAR1\s*=\s*%%gmx;
    $dump    = clean_credentials_from_string($dump);
    $dump    = substr($dump, 0, 247).'...' if length($dump) > 250;
    $dump    =~ s%;$%%gmx;
    return($dump);
}

##############################################

=head2 clean_credentials_from_string

    clean_credentials_from_string($string)

returns strings with potential credentials removed

=cut
sub clean_credentials_from_string {
    my($str) = @_;

    for my $key (qw/credential credentials CSRFtoken/) {
        $str    =~ s%("|')($key)("|'):"[^"]+"(,?)%$1$2$3:"..."$4%gmx; # remove from json encoded data
        $str    =~ s%("|')($key)("|'):'[^"]+'(,?)%$1$2$3:'...'$4%gmx; # same, but with single quotes
        $str    =~ s|(%22)($key)(%22%3A%22).*?(%22)|$1$2$3...$4|gmx;  # remove from url encoded data

        $str    =~ s%("|')($key)("|')(\s*=>\s*')[^']+(',?)%$1$2$3$4...$5%gmx; # remove from perl structures
        $str    =~ s%("|')($key)("|')(\s*=>\s*")[^']+(",?)%$1$2$3$4...$5%gmx; # same, but with single quotes
    }

    return($str);
}

##############################################

=head2 basename

    basename($path)

returns basename for given path

=cut
sub basename {
    my($path) = @_;
    my $basename = $path;
    $basename    =~ s%^.*/%%gmx;
    return($basename);
}

##############################################

=head2 dirname

    dirname($path)

returns dirname for given path

=cut
sub dirname {
    my($path) = @_;
    my $dirname = $path;
    $dirname    =~ s%/[^/]*$%%gmx;
    return($dirname);
}

##############################################

=head2 looks_like_regex

    looks_like_regex($str)

returns true if $string looks like a regular expression

=cut
sub looks_like_regex {
    my($str) = @_;
    if($str =~ m%[\^\|\*\{\}\[\]]%gmx) {
        return(1);
    }
    return;
}

##############################################

=head2 dclone

    dclone($obj)

deep clones any object

=cut
sub dclone {
    my($obj) = @_;
    return unless defined $obj;

    # use faster Clone module if available
    return(Clone::clone($obj)) if $INC{'Clone.pm'};

    # else use Storable
    return(Storable::dclone($obj));
}

##############################################

=head2 text_table

    text_table( keys => [keys], data => <list of hashes> )

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
                    if($col->{'format'}) {
                        $val = POSIX::strftime($col->{'format'}, localtime($val));
                    } else {
                        $val = scalar localtime $val;
                    }
                }
                elsif($col->{'type'} eq 'bytes') {
                    my($val1,$unit1) = Thruk::Utils::reduce_number($val, 'B', 1024);
                    if($col->{'format'}) {
                        $val1 = sprintf($col->{'format'}, $val1);
                    }
                    $val = $val1.$unit1;
                }
                elsif($col->{'format'}) {
                    $val = sprintf($col->{'format'}, $val);
                }
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
    my $output = $separator;
    $output .= sprintf($rowformat, @{$colnames});
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

##############################################

1;
