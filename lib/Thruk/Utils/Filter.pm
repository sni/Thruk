package Thruk::Utils::Filter;

=head1 NAME

Thruk::Utils::Filter - Filter Utilities Collection for Thruk

=head1 DESCRIPTION

Filter Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess cluck carp/;
use Date::Calc qw/Localtime Today/;
use URI::Escape qw/uri_escape/;
use JSON::XS ();
use Encode qw/decode_utf8/;
use Digest::MD5 qw(md5_hex);

##############################################
# use faster HTML::Escape if available
eval {
    require HTML::Escape;
    *html_escape = sub {
        return HTML::Escape::escape_html(@_);
    };
};
if($@) {
    eval {
        require HTML::Entities;
        *html_escape = sub {
            return HTML::Entities::encode_entities(@_);
        };
    };
}
if($@) {
    die("either HTML::Escape or HTML::Entities required: ".$!);
}
*escape_html = *html_escape;

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

=head2 contains

  contains($haystack, $needle)

returns true if needle is found in haystack or needle equals haystack

=cut
sub contains {
    my($haystack, $needle) = @_;
    if(ref $haystack eq 'ARRAY') {
        for my $test (@{$haystack}) {
            return 1 if $test eq $needle;
        }
    }
    return 1 if $haystack eq $needle;
    return 0;
}


##############################################

=head2 duration

  my $string = duration($seconds, [$options]);

formats a duration into the
format: 0d 0h 29m 43s

  $options:
        0    =>    0h 0m 15s
        1    => 0d 0h 0m 15s  (default)
        2    =>   0min 14sec
        3    =>       0m 04s

=cut
sub duration {
    my($duration, $options) = @_;
    my $minus    = '';

    confess("undef duration in duration(): ".$duration) unless defined $duration;
    if($duration < 0) {
        $duration = $duration * -1;
        $minus    = '-';
    }

    $options = 1 unless defined $options;

    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($options == 1) {
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

    if($options == 0) {
        return($minus.$hours."h ".$minutes."m ".$seconds."s");
    }
    elsif($options == 1) {
        return($minus.$days."d ".$hours."h ".$minutes."m ".$seconds."s");
    }
    elsif($options == 2) {
        return($minus.$minutes."min ".$seconds."sec");
    }
    elsif($options == 3) {
        return(CORE::sprintf("%s%dm %02ds", $minus, $minutes, $seconds));
    }
    confess("unknown options in duration(): ".$options);
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
    return '' unless defined $timestamp;
    confess("no c") unless defined $c;

    if($format) {
        return(Thruk::Utils::format_date($timestamp, $format));
    }

    # get today
    my @today;
    if(defined $c->stash->{'today'}) {
        @today = @{$c->stash->{'today'}};
    }
    else {
        @today = Today();
        $c->stash->{'today'} = \@today;
    }
    my($t_year,$t_month,$t_day) = @today;

    my($year,$month,$day, $hour,$min,$sec,$doy,$dow,$dst);
    eval {
        ($year,$month,$day, $hour,$min,$sec,$doy,$dow,$dst) = Localtime($timestamp);
    };
    if($@) {
        $c->log->warn("date_format($timestamp) failed: $@");
        return "err:$timestamp";
    }

    if($t_year == $year and $t_month == $month and $t_day == $day) {
        #confess("no datetime_format_today") unless $c->stash->{'datetime_format_today'};
        return(Thruk::Utils::format_date($timestamp, $c->stash->{'datetime_format_today'}));
    }

    #confess("no datetime_format") unless $c->stash->{'datetime_format'};
    return(Thruk::Utils::format_date($timestamp, $c->stash->{'datetime_format'}));
}


########################################

=head2 uri

  uri($c)

returns a correct uri

=cut
sub uri {
    my $c = shift;
    carp("no c") unless defined $c;
    my $uri = $c->req->url();
    $uri    =~ s/^(http|https):\/\/.*?\//\//gmx;
    $uri    = &escape_ampersand($uri);
    return $uri;
}


########################################

=head2 full_uri

  full_uri($c, $return_full_url)

returns uri to current page.

    $return_full_url   -> return http://host/thruk/... instead of /thruk/...

=cut
sub full_uri {
    my $c        = shift;
    my $full     = shift || 0;
    carp("no c") unless defined $c;
    my $uri = ''.uri_with($c, $c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'}, 1);

    # uri always contains /thruk/, so replace it with our product prefix
    my $url_prefix = $c->stash->{'url_prefix'};
    if($full) {
        $uri =~ s|(https?://[^/]+)/thruk/|$1$url_prefix|gmx;
    } else {
        $uri =~ s|(https?://[^/]+)/thruk/|$url_prefix|gmx;
    }
    $uri = &escape_ampersand($uri);
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
    my %uri_filter = %{$c->config->{'View::TT'}->{'PRE_DEFINE'}->{'uri_filter'}};
    for my $key (sort keys %uri_filter) {
        $filter->{$key} = $uri_filter{$key};
    }
    if(defined $data) {
        for my $key (sort keys %{$data}) {
            $filter->{$key} = $data->{$key};
        }
    }
    return(uri_with($c, $filter));
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

  uri_with($c, $data, $keep_absolute)

returns a relative uri to current page

=cut
sub uri_with {
    my($c, $data, $keep_absolute) = @_;
    my $uri = $c->req->uri;
    my @old_param = $uri->query_form();
    my @new_param;
    while(my $k = shift @old_param) {
        my $v = shift @old_param;
        if(exists $data->{$k}) {
            if(!defined $data->{$k} || $data->{$k} eq 'undef') {
                next;
            } else {
                push(@new_param, $k, delete $data->{$k});
            }
        } else {
            push(@new_param, $k, $v);
        }
    }
    for my $k (sort keys %{$data}) {
        push(@new_param, $k, $data->{$k}) if(defined $data->{$k} && $data->{$k} ne 'undef');
    }
    $uri->query_form(@new_param);
    $uri = $uri->as_string;
    unless($keep_absolute) {
        $uri =~ s/^(http|https):\/\/.*?\//\//gmx;
        $uri = &escape_ampersand($uri);
        # make relative url
        $uri =~ s|^/[^?]+/||mx;
    }
    return $uri;
}


########################################

=head2 html_escape

  html_escape($text)

wrapper for escape_html for compatibility reasons

=cut

########################################

=head2 escape_html

  escape_html($text)

returns an escaped string

=cut

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

=head2 escape_ampersand

  escape_ampersand($text)

returns a string with & escaped to &amp;

=cut
sub escape_ampersand{
    $_[0] =~ s/&amp;/&/gmx;
    $_[0] =~ s/&/&amp;/gmx;
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

=head2 validate_json

  validate_json(...)

returns error if json is invalid

=cut
sub validate_json {
    my($str) = @_;
    eval {
        JSON::XS->new->decode($str);
    };
    if($@) {
        my $err = $@;
        chomp($err);
        return($err);
    }
    return("");
}

########################################

=head2 get_action_menu

  get_action_menu(c, [name|menu])

returns menu and error

=cut
sub get_action_menu {
    my($c, $menu) = @_;
    our $already_checked_action_menus;
    $already_checked_action_menus = {} unless defined $already_checked_action_menus;

    if($menu !~ m/^[\[\{]/mx) {
        my $new = $c->config->{'action_menu_items'}->{$menu};
        if(!$new) {
            return(["no $menu in action_menu_items", "{}"]);
        }
        # fix trailing commas in menu
        $new =~ s/\,\s*([\}\]\)]+)/$1/gmx;
        unless(exists $already_checked_action_menus->{$menu}) {
            $already_checked_action_menus->{$menu} = validate_json($new);
            if($already_checked_action_menus->{$menu}) {
                $c->log->error("error in action menu: ".$already_checked_action_menus->{$menu}."\nsource:\n".$new);
            }
        }
        return([$already_checked_action_menus->{$menu}, $new]);
    }

    # fix trailing commas in menu
    $menu =~ s/\,\s*([\}\]\)]+)/$1/gmx;

    my $err = validate_json($menu);
    if($err) {
        $c->log->error("error in action menu: ".$err."\nsource:\n".$menu);
    }
    return([$err, $menu]);
}

########################################

=head2 json_encode

  json_encode(...)

returns json encoded string

=cut
sub json_encode {
    # do not use utf8 here, results in double encoding because object should be utf8 already
    # for example business processes having utf8 characters in the plugin output
    if(scalar @_ > 1) {
        return JSON::XS->new->encode([@_]);
    }
    return JSON::XS->new->encode($_[0]);
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
    my($text) = @_;
    $text = escape_html($text);
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
    my($text) = @_;
    $text =~ s/\\/\\\\/gmx;
    return $text;
}


########################################

=head2 escape_xml

  escape_xml($text)

returns an escaped string for xml output

=cut
sub escape_xml {
    my($text) = @_;
    $text =~ s/&/&amp;/gmx;
    $text =~ s/</&lt;/gmx;
    $text =~ s/>/&gt;/gmx;
    $text =~ s/\\n\Z//gmx;
    $text =~ s/\\n/\n/gmx;
    $text =~ tr/\x80-\xFF//d;
    $text =~ s/\p{Cc}//gmx;
    return $text;
}

########################################

=head2 escape_regex

  escape_regex($text)

returns an escaped string for regular expression

=cut
sub escape_regex {
    return(quotemeta($_[0]));
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
    if(defined $c->cookie('thruk_message')) {
        my $cookie = $c->cookie('thruk_message');
        $c->cookie('thruk_message' => '', {
            expires => 0,
            path    => $c->stash->{'cookie_path'},
        });
        # sometimes the cookie is empty, so delete it in every case
        # and show it if it contains data
        if(defined $cookie and $cookie->value) {
            my($style,$message) = split(/~~/mx, $cookie->value, 2);
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
        delete $c->res->{'cookies'}->{'thruk_message'};
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
    return $fallback unless ref $obj->{$prefix.'custom_variable_names'} eq 'ARRAY';
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

=head2 has_business_process

  has_business_process($host)

returns true if host is part of an business process

=cut
sub has_business_process {
    my($obj, $prefix) = @_;
    $prefix = '' unless defined $prefix;
    my $x = 0;
    for my $var (@{$obj->{$prefix.'custom_variable_names'}}) {
        return $obj->{$prefix.'custom_variable_values'}->[$x] if $var eq 'THRUK_BP_ID';
        $x++;
    }
    return 0;
}

########################################

=head2 button

  my $html = button($link, $value, $class, [$onclick], [$formstyle], [$keeplink])

returns button html source

=cut
sub button {
    my($link, $value, $class, $onclick, $formstyle, $keeplink) = @_;

    my($page, $args);
    if($keeplink) {
        $page = $link;
        $args = "";
    } else {
        ($page, $args) = split(/\?/mx, $link, 2);
        $args =~ s/&amp;/&/gmx;
    }

    my $html = '<form action="'.$page.'" method="POST"'.($formstyle ? 'style="'.$formstyle.'"' : '').'>';
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
    if($c->config->{'extra_version'}) {
        $str .= '/ '.$c->config->{'extra_version'};
    }
    $str = '' unless defined $str;
    return $str;
}

########################################

=head2 split_perfdata

  split_perfdata($string)

return splitted performance data which can be used for tabular display

=cut
sub split_perfdata {
    my($perfdata_str) = @_;

    return([]) unless $perfdata_str;

    my $data = [];
    my @matches  = $perfdata_str =~ m/([^\s]+|'[^']+')=([^\s]*)/gmxoi;
    my $last_parent = '';
    my $has_parents = 0;
    my $has_warn    = 0;
    my $has_crit    = 0;
    my $has_min     = 0;
    my $has_max     = 0;
    for(my $x = 0; $x < scalar @matches; $x=$x+2) {
        my $key = $matches[$x];
        my $val = $matches[$x+1];
        my $orig = $key.'='.$val;
        $key =~ s/^'//gmxo;
        $key =~ s/'$//gmxo;
        $val =~ s/,/./gmxo;
        $val = $val.';;;;';
        my($var, $unit, $warn, $crit, $min, $max);
        if($val =~ m/^(\-?[\d\.]+)([^;]*?);([^;]*);([^;]*);([^;]*);([^;]*)/mxo) {
            ($var, $unit, $warn, $crit, $min, $max) = ($1, $2, $3, $4, $5, $6);
        }
        elsif($val =~ m/^U;/mxi) {
            $var  = 'Unknown';
            $unit = '';
            $warn = '';
            $crit = '';
            $min  = '';
            $max  = '';
        }

        if($key =~ m/^(.*)::(.*?)$/mx) {
            $last_parent = $1;
            $key = $2;
            $has_parents = 1;
        }
        $warn =~ s/^(\-?[\d\.]+):(\-?[\d\.]+)$/$1-$2/mxo;
        $crit =~ s/^(\-?[\d\.]+):(\-?[\d\.]+)$/$1-$2/mxo;
        push @{$data}, {
            'parent'    => $last_parent,
            'name'      => $key,
            'value'     => $var,
            'unit'      => $unit,
            'min'       => $min,
            'max'       => $max,
            'warn'      => $warn,
            'crit'      => $crit,
            'orig'      => $orig,
        } if defined $var;
        $has_warn = 1 if $warn ne '';
        $has_crit = 1 if $crit ne '';
        $has_min  = 1 if $min  ne '';
        $has_max  = 1 if $max  ne '';
    }
    return($data, $has_parents, $has_warn, $has_crit, $has_min, $has_max);
}

########################################

=head2 get_user_token

  get_user_token($c)

returns user token which can be used to validate requests

=cut
sub get_user_token {
    my($c) = @_;
    return $c->stash->{'user_token'} if $c->stash->{'user_token'};
    if(!defined $c->stash->{'remote_user'} || $c->stash->{'remote_user'} eq '?') {
        return("");
    }
    my $store  = Thruk::Utils::Cache->new($c->config->{'var_path'}.'/token');
    my $tokens = $store->get('token');
    my $minage = time() - 7200;
    for my $usr (keys %{$tokens}) {
        delete $tokens->{$usr} if $tokens->{$usr}->{'time'} < $minage;
    }
    if(!defined $tokens->{$c->stash->{'remote_user'}}) {
        $tokens->{$c->stash->{'remote_user'}} = {
            'token' => md5_hex($c->stash->{'remote_user'}.time().rand()),
        };
    }
    $tokens->{$c->stash->{'remote_user'}}->{'time'} = time();
    $store->set('token', $tokens);
    $c->stash->{'user_token'} = $tokens->{$c->stash->{'remote_user'}}->{'token'};
    return $c->stash->{'user_token'};
}

########################################

=head2 get_cmd_submit_hash

  get_cmd_submit_hash($data)

create hash used in service/host details page

=cut
sub get_cmd_submit_hash {
    my($data, $type) = @_;
    return('{}') unless $data;
    my $hash = {};
    my $x = 0;
    if($type eq 'svc') {
        for my $d (@{$data}) {
            $hash->{'r'.$x} = $d->{'host_name'}.';'.$d->{'description'}.';'.$d->{'peer_key'};
            $x++;
        }
    }
    elsif($type eq 'hst') {
        for my $d (@{$data}) {
            $hash->{'r'.$x} = $d->{'name'}.';;'.$d->{'peer_key'};
            $x++;
        }
    }
    else {
        confess("no such type: $type");
    }
    return(JSON::XS::encode_json($hash));
}

########################################

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
