package Thruk::Utils::Filter;

=head1 NAME

Thruk::Utils::Filter - Filter Utilities Collection for Thruk

=head1 DESCRIPTION

Filter Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Date::Calc qw/Localtime Today/;
use URI::Escape qw/uri_escape/;
use JSON::XS;
use Encode qw/decode_utf8/;

##############################################

=head1 METHODS

=head2 throw

  throw($string)

can be used to die in templates

=cut
sub throw {
    my $string = shift;
    die($string);
}


##############################################

=head2 duration

  my $string = duration($seconds);

formats a duration into the
format: 0d 0h 29m 43s

=cut
sub duration {
    my($duration, $withdays) = @_;
    my $minus    = '';

    confess("undef duration in duration(): ".$duration) unless defined $duration;
    if($duration < 0) {
        $duration = $duration * -1;
        $minus    = '-';
    }

    $withdays = 1 unless defined $withdays;

    confess("unknown withdays in duration(): ".$withdays) if($withdays != 0 and $withdays != 1 and $withdays != 2);

    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($withdays == 1) {
        if($duration >= 86400) {
            $days     = int($duration/86400);
            $duration = $duration%86400;
        }
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

    if($withdays == 1) {
        return($minus.$days."d ".$hours."h ".$minutes."m ".$seconds."s");
    }
    if($withdays == 2) {
        return($minus.$minutes."min ".$seconds."sec");
    }
    return($minus.$hours."h ".$minutes."m ".$seconds."s");
}


##############################################

=head2 nl2br

  my $string = nl2br($string);

replace newlines with linebreaks

=cut
sub nl2br {
    my $string = shift;
    $string =~ s/\n/<br>/gmx;
    $string =~ s/\r//gmx;
    $string =~ s/\\n/<br>/gmx;
    return $string;
}


##############################################

=head2 sprintf

  my $string = sprintf($format, $list)

wrapper around the internal sprintf

=cut
sub sprintf {
    my $format = shift;
    local $SIG{__WARN__} = sub { Carp::cluck(@_); };
    return CORE::sprintf $format, @_;
}


##############################################

=head2 date_format

  my $string = date_format($c, $seconds);

formats a time definition into date format

=cut
sub date_format {
    my($c, $timestamp, $format) = @_;
    return "" unless defined $timestamp;

    # get today
    my @today;
    if(defined $c->{'stash'}->{'today'}) {
        @today = @{$c->{'stash'}->{'today'}};
    }
    else {
        @today = Today();
    }
    my($t_year,$t_month,$t_day) = @today;
    $c->{'stash'}->{'today'} = \@today;

    my($year,$month,$day, $hour,$min,$sec,$doy,$dow,$dst);
    eval {
        ($year,$month,$day, $hour,$min,$sec,$doy,$dow,$dst) = Localtime($timestamp);
    };
    if($@) {
        $c->log->warn("date_format($timestamp) failed: $@");
        return "err:$timestamp";
    }

    if(defined $format) {
        return(Thruk::Utils::format_date($timestamp, $format));
    }

    if($t_year == $year and $t_month == $month and $t_day == $day) {
        return(Thruk::Utils::format_date($timestamp, $c->{'stash'}->{'datetime_format_today'}));
    }

    return(Thruk::Utils::format_date($timestamp, $c->{'stash'}->{'datetime_format'}));
}


########################################

=head2 uri

  uri($c)

returns a correct uri

=cut
sub uri {
    my $c = shift;
    carp("no c") unless defined $c;
    my $uri = $c->request->uri();
    $uri    =~ s/^(http|https):\/\/.*?\//\//gmx;
    $uri    =~ s/&amp;/&/gmx;
    $uri    =~ s/&/&amp;/gmx;
    return $uri;
}


########################################

=head2 full_uri

  full_uri($c)

returns a correct uri

=cut
sub full_uri {
    my $c    = shift;
    my $amps = shift || 0;
    carp("no c") unless defined $c;
    my $uri = $c->request->uri_with($c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'});
    if($amps) {
        $uri    =~ s/&amp;/&/gmx;
        $uri    =~ s/&/&amp;/gmx;
    }
    return $uri;
}


########################################

=head2 as_url_arg

  as_url_arg($str)

returns encoded string for use in url args

=cut
sub as_url_arg {
    my($str) = @_;
    $str =~ s/&amp;/&/gmx;
    $str = uri_escape($str);
    return $str;
}


########################################

=head2 short_uri

  short_uri($c, $filter)

returns a correct uri but only the url part

=cut
sub short_uri {
    my($c, $data) = @_;
    my $filter = {};
    for my $key (keys %{$c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'}}) {
        $filter->{$key} = $c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'}->{$key};
    }
    if(defined $data) {
        for my $key (%{$data}) {
            $filter->{$key} = $data->{$key};
        }
    }
    my $uri = uri_with($c, $filter);
    $uri    =~ s/^(http|https):\/\/.*?\//\//gmx;
    return $uri;
}


########################################

=head2 clean_referer

  clean_referer($url)

returns a url with referer removed

=cut
sub clean_referer {
    my $uri = shift;
    for my $key (qw/referer bookmark scrollTo reload_nav _/) {
        $uri =~ s/&amp;$key=[^&]+//gmx;
        $uri =~ s/\?$key=[^&]+/?/gmx;
    }
    return $uri;
}



########################################

=head2 uri_with

  uri_with($c, $data)

returns a correct uri

=cut
sub uri_with {
    my $c    = shift;
    my $data = shift;

    my $filter = {};
    for my $key (keys %{$c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'}}) {
        $filter->{$key} = $c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'}->{$key};
    }
    for my $key (keys %{$data}) {
        next unless defined $data->{$key};
        $filter->{$key} = $data->{$key};
        $filter->{$key} = undef if $filter->{$key} eq 'undef';
    }

    my $uri;
    eval {
        $uri = $c->request->uri_with($filter);
    };
    if($@) {
        confess("ERROR in uri_with(): ".$@);
    }
    $uri =~ s/^(http|https):\/\/.*?\//\//gmx;
    $uri =~ s/&amp;/&/gmx;
    $uri =~ s/&/&amp;/gmx;
    # make relative url
    $uri =~ s|^/[^?]+/||mx;
    return $uri;
}


########################################

=head2 html_escape

  html_escape($text)

wrapper for escape_html for compatibility reasons

=cut
sub html_escape {
    return escape_html(@_);
}


########################################

=head2 escape_html

  escape_html($text)

returns an escaped string

=cut
sub escape_html {
    return HTML::Entities::encode($_[0]);
}


########################################

=head2 escape_quotes

  escape_quotes($text)

returns a string with only the single- or double-quotes escaped

=cut
sub escape_quotes {
    $_[0] =~ s/\\'/'/gmx;
    $_[0] =~ s/'/\\'/gmx;
    $_[0] =~ s/"/\\'/gmx;
    return $_[0];
}


########################################

=head2 remove_html_comments

  remove_html_comments($text)

returns string with html comments removed

=cut
sub remove_html_comments {
    # remove comments
    $_[0] =~ s/<\!\-\-.*?(--!>|-->|$)//msxi;
    return $_[0];
}

########################################

=head2 json_encode

  json_encode(...)

returns json encoded string

=cut
sub json_encode {
    if(scalar @_ > 1) {
        return JSON::XS::encode_json([@_]);
    }
    return JSON::XS::encode_json($_[0]);
}

########################################

=head2 encode_json_obj

  encode_json_obj(array, [decode])

returns json encoded object

=cut
sub encode_json_obj {
    return decode_utf8(JSON::XS::encode_json($_[0])) if $_[1];
    return JSON::XS::encode_json($_[0]);
}

########################################

=head2 escape_js

  escape_js($text)

used to escape html tags so it can be used as javascript string

=cut
sub escape_js {
    my $text = shift;
    $text = HTML::Entities::encode($text);
    $text =~ s/&amp;quot;/&quot;/gmx;
    $text =~ s/&amp;gt;/>/gmx;
    $text =~ s/&amp;lt;/</gmx;
    return $text;
}


########################################

=head2 escape_bslash

  escape_bslash($text)

used to escape backslashes

=cut
sub escape_bslash {
    my $text = shift;
    $text =~ s/\\/\\\\/gmx;
    return $text;
}


########################################

=head2 escape_xml

  escape_xml($text)

returns an escaped string for xml output

=cut
sub escape_xml {
    my $text = shift;

    my $return = HTML::Entities::encode($text, '<>&');
    $return =~ s/\\n\Z//mx;
    $return =~ s/\\n/\n/gmx;
    $return =~ tr/\x80-\xFF//d;
    return $return;
}


########################################

=head2 name2id

  my $striped_string = name2id($name)

returns a string which can be used as id in html elements

An id must begin with a letter ([A-Za-z]) and may be followed
by any number of letters, digits ([0-9]), hyphens ("-"),
underscores ("_"), colons (":"), and periods (".").

=cut
sub name2id {
    my $name       = shift;
    my $opt_prefix = shift || '';
    my $return = $name;
    $return =~ s/[^a-zA-Z0-9\-_\.]*//gmx;
    if($return =~ m/^\d+/gmx) {
        $return = $opt_prefix."_".$return;
    }
    return($return);
}


########################################

=head2 uniqnumber

  uniqnumber()

return uniq number which can be used in html ids

=cut
sub uniqnumber {
    our $uniqnumber;
    $uniqnumber = 0 unless defined $uniqnumber;
    $uniqnumber++;
    return $uniqnumber;
}


########################################

=head2 get_message

  get_message($c)

get a message from an cookie, display and delete it

=cut
sub get_message {
    my($c) = @_;

    my $has_details = 0;

    # message from cookie?
    if(defined $c->request->cookie('thruk_message')) {
        my $cookie = $c->request->cookie('thruk_message');
        $c->res->cookies->{'thruk_message'} = {
            value   => '',
            expires => '-1M',
            path    => $c->stash->{'cookie_path'}
        };
        # sometimes the cookie is empty, so delete it in every case
        # and show it if it contains data
        if(defined $cookie and defined $cookie->value) {
            my($style,$message) = split/~~/mx, $cookie->value;
            my @msg = split(/\n/mx, $message);
            if(scalar @msg > 1) {
                $has_details = 2;
                $message     = shift @msg;
                return($style, $message, $has_details, \@msg);
            }
            return($style, $message, $has_details);
        }
    }
    # message from stash
    elsif(defined $c->stash->{'thruk_message'}) {
        my($style,$message) = split/~~/mx, $c->stash->{'thruk_message'};
        delete $c->res->cookies->{'thruk_message'};

        if(defined $c->stash->{'thruk_message_details'}) {
            $has_details = 1;
        }
        return($style, $message, $has_details);
    }

    return '';
}


########################################

=head2 strip_command_args

  my $striped_string = strip_command_args($command_name)

returns a string without the arguments for a command

check_nrpe!$HOSTNAME$!check_disk -> check_nrpe

=cut
sub strip_command_args {
    my $text = shift;
    $text =~ s/!.*$//gmx;
    return($text);
}

########################################

=head2 calculate_first_notification_delay_remaining

  my $remaining = calculate_first_notification_delay_remaining($obj)

returns remaining minutes for first_notification_delay

=cut
sub calculate_first_notification_delay_remaining {
    my $obj = shift;
    return -1 unless $obj->{'state'} > 0;

    my $first_problem_time = -1;
    if(defined $obj->{'last_time_ok'}) {
        $first_problem_time = $obj->{'last_time_ok'};
        if(($obj->{'last_time_warning'} < $first_problem_time) && ($obj->{'last_time_warning'} > $obj->{'last_time_ok'})) {
            $first_problem_time = $obj->{'last_time_warning'};
        }
        if(($obj->{'last_time_unknown'} < $first_problem_time) && ($obj->{'last_time_unknown'} > $obj->{'last_time_ok'})) {
            $first_problem_time = $obj->{'last_time_unknown'};
        }
        if(($obj->{'last_time_critical'} < $first_problem_time) && ($obj->{'last_time_critical'} > $obj->{'last_time_ok'})) {
            $first_problem_time = $obj->{'last_time_critical'};
        }
    }
    elsif(defined $obj->{'last_time_up'}) {
        $first_problem_time = $obj->{'last_time_up'};
        if(($obj->{'last_time_down'} < $first_problem_time) && ($obj->{'last_time_down'} > $obj->{'last_time_up'})) {
            $first_problem_time = $obj->{'last_time_down'};
        }
        if(($obj->{'last_time_unreachable'} < $first_problem_time) && ($obj->{'last_time_unreachable'} > $obj->{'last_time_up'})) {
            $first_problem_time = $obj->{'last_time_unreachable'};
        }
    }
    return -1 if $first_problem_time == 0;
    my $remaining_min = int((time() - $first_problem_time) / 60);
    return -1 if $remaining_min > $obj->{'first_notification_delay'};

    return($obj->{'first_notification_delay'} - $remaining_min);
}

########################################

=head2 action_icon

  my $icon = action_icon($obj, $fallback)

returns action icon path

=cut
sub action_icon {
    my($obj, $fallback, $prefix) = @_;
    $prefix = '' unless defined $prefix;
    my $x = 0;
    for my $var (@{$obj->{$prefix.'custom_variable_names'}}) {
        return $obj->{$prefix.'custom_variable_values'}->[$x] if $var eq 'ACTION_ICON';
        $x++;
    }
    return $fallback;
}


########################################

=head2 logline_icon

  my $icon = logline_icon($logentry)

returns icon path

=cut
sub logline_icon {
    my($log) = @_;

    my $pic  = 'info.png';
    my $desc = '';

    if($log->{'type'} eq 'CURRENT SERVICE STATE')               { $pic = "info.png";            $desc = "Informational Message"; }
    elsif($log->{'type'} eq 'CURRENT HOST STATE')               { $pic = "info.png";            $desc = "Informational Message"; }
    elsif($log->{'type'} eq 'SERVICE NOTIFICATION')             { $pic = "notify.gif";          $desc = "Service Notification"; }
    elsif($log->{'type'} eq 'HOST NOTIFICATION')                { $pic = "notify.gif";          $desc = "Host Notification"; }
    elsif($log->{'type'} eq 'SERVICE ALERT') {
                                      if($log->{'state'} == 0)  { $pic = "recovery.png";        $desc = "Service Ok"; }
                                   elsif($log->{'state'} == 1)  { $pic = "warning.png";         $desc = "Service Warning"; }
                                   elsif($log->{'state'} == 2)  { $pic = "critical.png";        $desc = "Service Critical"; }
                                   elsif($log->{'state'} == 3)  { $pic = "unknown.png";         $desc = "Service Unknown"; }
    }
    elsif($log->{'type'} eq 'HOST ALERT') {
                                      if($log->{'state'} == 0)  { $pic = "recovery.png";        $desc = "Host Up"; }
                                   elsif($log->{'state'} == 1)  { $pic = "critical.png";        $desc = "Host Down"; }
                                   elsif($log->{'state'} == 2)  { $pic = "critical.png";        $desc = "Host Unreachable"; }
    }
    elsif($log->{'type'} eq 'SERVICE EVENT HANDLER')            { $pic = "serviceevent.gif";    $desc = "Service Event Handler"; }
    elsif($log->{'type'} eq 'HOST EVENT HANDLER')               { $pic = "hostevent.gif";       $desc = "Host Event Handler"; }
    elsif($log->{'type'} eq 'EXTERNAL COMMAND')                 { $pic = "command.png";         $desc = "External Command"; }
    elsif($log->{'type'} eq 'PASSIVE SERVICE CHECK')            { $pic = "passiveonly.gif";     $desc = "Passive Service Check"; }
    elsif($log->{'type'} eq 'PASSIVE HOST CHECK')               { $pic = "passiveonly.gif";     $desc = "Passive Host Check"; }

    elsif($log->{'type'} eq 'SERVICE FLAPPING ALERT') {
                    if($log->{'message'} =~ m/;STARTED;/mx)     { $pic = "flapping.gif";        $desc = "Service started flapping"; }
                 elsif($log->{'message'} =~ m/;STOPPED;/mx)     { $pic = "flapping.gif";        $desc = "Service stoppedflapping"; }
                 elsif($log->{'message'} =~ m/;DISABLED;/mx)    { $pic = "flapping.gif";        $desc = "Service flap detection disabled"; }
    }
    elsif($log->{'type'} eq 'HOST FLAPPING ALERT') {
                    if($log->{'message'} =~ m/;STARTED;/mx)     { $pic = "flapping.gif";        $desc = "Host started flapping"; }
                 elsif($log->{'message'} =~ m/;STOPPED;/mx)     { $pic = "flapping.gif";        $desc = "Host stoppedflapping"; }
                 elsif($log->{'message'} =~ m/;DISABLED;/mx)    { $pic = "flapping.gif";        $desc = "Host flap detection disabled"; }
    }
    elsif($log->{'type'} eq 'SERVICE DOWNTIME ALERT') {
                   if($log->{'message'} =~ m/;STARTED;/mx)      { $pic = "downtime.gif";        $desc = "Service entered a period of scheduled downtime"; }
                elsif($log->{'message'} =~ m/;STOPPED;/mx)      { $pic = "downtime.gif";        $desc = "Service exited a period of scheduled downtime"; }
                elsif($log->{'message'} =~ m/;CANCELLED;/mx)    { $pic = "downtime.gif";        $desc = "Service scheduled downtime has been cancelled"; }
    }
    elsif($log->{'type'} eq 'HOST DOWNTIME ALERT') {
                   if($log->{'message'} =~ m/;STARTED;/mx)      { $pic = "downtime.gif";        $desc = "Host entered a period of scheduled downtime"; }
                elsif($log->{'message'} =~ m/;STOPPED;/mx)      { $pic = "downtime.gif";        $desc = "Host exited a period of scheduled downtime"; }
                elsif($log->{'message'} =~ m/;CANCELLED;/mx)    { $pic = "downtime.gif";        $desc = "Host scheduled downtime has been cancelled"; }
    }
    elsif($log->{'type'} eq 'LOG ROTATION')                     { $pic = "logrotate.png";       $desc = "Log Rotation"; }
    elsif($log->{'type'} =~ m/TIMEPERIOD TRANSITION/mx)         { $pic = "info.png";            $desc = "Timeperiod Transition"; }
    elsif($log->{'type'} =~ m/restarting\.\.\./mx)              { $pic = "restart.gif";         $desc = "Program Restart"; }
    elsif($log->{'type'} =~ m/starting\.\.\./mx)                { $pic = "start.gif";           $desc = "Program Start"; }
    elsif($log->{'type'} =~ m/shutting down\.\.\./mx)           { $pic = "stop.gif";            $desc = "Program End"; }
    elsif($log->{'type'} =~ m/Bailing\ out/mx)                  { $pic = "stop.gif";            $desc = "Program End"; }
    elsif($log->{'type'} =~ m/active mode\.\.\./mx)             { $pic = "active.gif";          $desc = "Active Mode"; }
    elsif($log->{'type'} =~ m/standby mode\.\.\./mx)            { $pic = "standby.gif";         $desc = "Standby Mode"; }
    else                                                        { $pic = "info.png";            $desc = "Informational Message"; }

    return $pic;
}


########################################

=head2 button

  my $html = button($link, $value, $class, [$onclick])

returns button html source

=cut
sub button {
    my($link, $value, $class, $onclick) = @_;

    my($page, $args) = split(/\?/mx, $link, 2);
    $args =~ s/&amp;/&/gmx;

    my $html = '<form action="'.$page.'" method="POST">';
    for my $a (split/\&/mx, $args) {
        my($k,$v) = split(/=/mx,$a,2);
        $html   .= '<input type="hidden" name="'.$k.'" value="'.$v.'">';
    }
    $html   .= '<button class="'.$class.'"';
    $html   .= ' onclick="'.$onclick.'"' if $onclick;
    $html   .= '>'.$value.'</button>';
    $html   .= '</form>';
    return $html;
}


########################################

=head2 fullversion

  my $str = fullversion($c)

returns full version string

=cut
sub fullversion {
    my($c) = @_;
    die("no c") unless defined $c;
    my $str = $c->config->{'version'};
    if($c->config->{'branch'}) {
        $str .= '~'.$c->config->{'branch'};
    }
    if($c->config->{'omd_version'}) {
        $str .= '/ OMD '.$c->config->{'omd_version'};
    }
    $str = '' unless defined $str;
    return $str;
}



########################################

1;

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
