package Thruk::Utils::Filter;

=head1 NAME

Thruk::Utils::Filter - Filter Utilities Collection for Thruk

=head1 DESCRIPTION

Filter Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Carp qw/confess cluck carp/;
use Cpanel::JSON::XS ();
use Data::Dumper ();
use Date::Calc qw/Localtime Today/;
use Encode qw/decode_utf8/;
use POSIX ();
use Scalar::Util qw/looks_like_number/;
use URI::Escape qw/uri_escape/;

use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Status ();

##############################################
# use faster HTML::Escape if available
eval {
    require HTML::Escape;
    *html_escape = *HTML::Escape::escape_html;
};
if($@) {
    eval {
        require HTML::Entities;
        *html_escape = *HTML::Entities::encode_entities;
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

=head2 type

  type($any)

returns ref

=cut
sub type {
    return(CORE::ref($_[0]));
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
        4    =>          15m (trimmed all non-zero)
        5    =>        15min (trimmed all non-zero)
        6    =>        2y 5d (highest 2)

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

    my $years   = 0;
    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($options == 4 || $options == 5 || $options == 6) {
        if($duration >= (365*86400)) {
            $years     = int($duration/(365*86400));
            $duration = $duration%(365*86400);
        }
    }
    if($options == 4 || $options == 5 || $options == 6 || $options == 1) {
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
    $seconds = CORE::sprintf("%d", $duration);

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
    elsif($options == 4) {
        my @res;
        if($years   > 0) { push @res, $years."y"; }
        if($days    > 0) { push @res, $days."d"; }
        if($hours   > 0) { push @res, $hours."h"; }
        if($minutes > 0) { push @res, $minutes."m"; }
        if($seconds > 0) { push @res, $seconds."s"; }
        if(scalar @res == 0) { push @res, "0s"; }
        return($minus.join(" ", @res));
    }
    elsif($options == 5) {
        my @res;
        if($years   > 0) { push @res, $years."year"._plural_s($years); }
        if($days    > 0) { push @res, $days."day"._plural_s($days); }
        if($hours   > 0) { push @res, $hours."hour"._plural_s($hours); }
        if($minutes > 0) { push @res, $minutes."min"; }
        if($seconds > 0) { push @res, $seconds."sec"; }
        if(scalar @res == 0) { push @res, "0sec"; }
        return($minus.join(" ", @res));
    }
    elsif($options == 6) {
        my @res;
        if($years   > 0) { push @res, $years."y"; }
        if($days    > 0) { push @res, $days."d"; }
        if($hours   > 0) { push @res, $hours."h"; }
        if($minutes > 0) { push @res, $minutes."m"; }
        if($seconds > 0) { push @res, $seconds."s"; }
        if(scalar @res > 2) { @res = splice(@res, 0, 2); }
        if(scalar @res == 0) { push @res, "0s"; }
        return($minus.join(" ", @res));
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
    local $SIG{__WARN__} = sub { cluck(@_); };
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
        _warn("date_format($timestamp) failed: $@");
        return "err:$timestamp";
    }

    if($t_year == $year and $t_month == $month and $t_day == $day) {
        #confess("no datetime_format_today") unless $c->stash->{'datetime_format_today'};
        return(Thruk::Utils::format_date($timestamp, $c->stash->{'datetime_format_today'}));
    }

    #confess("no datetime_format") unless $c->stash->{'datetime_format'};
    return(Thruk::Utils::format_date($timestamp, $c->stash->{'datetime_format'}));
}

##############################################

=head2 last_check

  my $string = last_check($c, $last_check);

returns formated last check date

=cut
sub last_check {
    my($c, $timestamp) = @_;
    confess("no c") unless defined $c;
    if(!$timestamp || $timestamp eq '-1') {
        return('never');
    }
    return(date_format($c, $timestamp));
}

########################################

=head2 uri

  uri($c)

returns html escaped current absolute uri without any filter

ex.: /thruk/cgi-bin/status.cgi?params...

=cut
sub uri {
    my($c) = @_;
    carp("no c") unless defined $c;
    my $uri = $c->stash->{original_uri} ? $c->stash->{original_uri} : $c->req->uri->as_string();
    $uri    =~ s/^(http|https):\/\/.*?\//\//gmx;
    $uri    = &escape_html($uri);
    return $uri;
}


########################################

=head2 full_uri

  full_uri($c, $return_full_url)

returns html escaped uri to current page with default filters.

ex.:
    /thruk/cgi-bin/status.cgi?params...

    with return_full_url:
    http://hostname/thruk/cgi-bin/status.cgi?params

=cut
sub full_uri {
    my($c, $full) = @_;
    $full = 0 unless $full;
    confess("no c") unless defined $c;
    my $uri = ''.uri_with($c, undef, 1);

    # uri always contains /thruk/, so replace it with our product prefix
    my $url_prefix = $c->stash->{'url_prefix'} || $c->config->{'url_prefix'};
    confess("no url_prefix") unless defined $url_prefix;
    if($full) {
        $uri =~ s|(https?://[^/]+)/thruk/|$1$url_prefix|gmx;
    } else {
        $uri =~ s|(https?://[^/]+)/thruk/|$url_prefix|gmx;
    }
    return $uri;
}

########################################

=head2 base_url

  base_uri($c)

returns a html escaped correct uri but only the url part and without parameters

ex.: status.cgi

=cut
sub base_url {
    my($c, $url) = @_;
    $url = uri_with($c, undef, undef, $url);
    $url =~ s/\?.*//gmx;
    return($url);
}

########################################

=head2 short_uri

  short_uri($c, [ $filter, $keep_absolute, $baseurl, $skip_escape ])

returns a html escaped correct uri but only the url part (redirects to uri_with but applies default filter)

ex.: status.cgi?params...

=cut
sub short_uri {
    my($c, $data, $keep_absolute, $baseurl, $skip_escape) = @_;
    my $filter = {};
    if(defined $data) {
        for my $key (sort keys %{$data}) {
            $filter->{$key} = $data->{$key};
        }
    } else {
        my %uri_filter = %{$c->config->{'uri_filter'}};
        for my $key (sort keys %uri_filter) {
            $filter->{$key} = $uri_filter{$key};
        }
    }
    return(uri_with($c, $filter, $keep_absolute, $baseurl, $skip_escape));
}


########################################

=head2 uri_with

  uri_with($c, $data, [$keep_absolute], [$baseurl], [$skip_escape])

returns a relative uri to current page

ex.:
    status.cgi?params...

    with keep_absolute:
    http://hostname/thruk/cgi-bin/status.cgi?params

=cut
sub uri_with {
    my($c, $data, $keep_absolute, $baseurl, $skip_escape) = @_;
    my $uri;
    if($baseurl) {
        $uri = URI->new($baseurl);
    } else {
        $uri = $c->stash->{original_uri} ? URI->new($c->stash->{original_uri}) : $c->req->uri;
    }

    my %uri_filter = %{$c->config->{'base_uri_filter'}};
    for my $key (sort keys %uri_filter) {
        $data->{$key} = $uri_filter{$key} unless exists $data->{$key};
    }

    my @old_param = $uri->query_form();
    my @new_param;
    while(my $k = shift @old_param) {
        my $v = shift @old_param;
        next if $k eq '_'; # skip reload timestamp
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
        next if $k eq '_page'; # skip new base url
        push(@new_param, $k, $data->{$k}) if(defined $data->{$k} && $data->{$k} ne 'undef');
    }
    $uri->query_form(@new_param);
    if($data->{'_page'}) {
        if($data->{'_page'} =~ m/\//mx) {
            $uri->path($data->{'_page'});
        } else {
            my $new_path = $uri->path();
            $new_path =~ s|^(.*)/.*$|$1/$data->{'_page'}|gmx;
            $uri->path($new_path);
        }
    }
    $uri = $uri->as_string;
    unless($keep_absolute) {
        $uri =~ s/^(http|https):\/\/.*?\//\//gmx;
        # make relative url
        $uri =~ s|^/[^?]+/||mx;
    }
    return($uri) if $skip_escape;
    return(&escape_html($uri));
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

=head2 html_escape

  html_escape($text)

wrapper for escape_html for compatibility reasons

=cut

########################################

=head2 html_escape_recursive

  html_escape_recursive($any)

recursively escape data

=cut
sub html_escape_recursive {
    my($data) = @_;
    if(ref $data eq "ARRAY") {
        my $x = 0;
        for my $d (@{$data}) {
            $data->[$x] = html_escape_recursive($d);
            $x++;
        }
    }
    elsif(ref $data eq "HASH") {
        for my $key (keys %{$data}) {
            $data->{$key} = html_escape_recursive($data->{$key});
        }
    }
    else {
        $data = html_escape($data);
    }
    return($data);
}

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
        Cpanel::JSON::XS->new->decode($str);
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
    $c->stash->{'checked_action_menus'} = {} unless defined $c->stash->{'checked_action_menus'};

    my $sourcefile;
    if($menu !~ m/^[\[\{]/mx) {
        if($c->stash->{'checked_action_menus'}->{$menu}) {
            return($c->stash->{'checked_action_menus'}->{$menu});
        }

        if(!$c->config->{'action_menu_items'}->{$menu}) {
            return({err => "no $menu in action_menu_items"});
        }

        if($c->config->{'action_menu_items'}->{$menu} =~ m%^file://(.*)$%mx) {
            $sourcefile = $1;
            if(!-r $sourcefile) {
                my $err = $sourcefile.': '.$!;
                _error("error in action menu ".$menu.": ".$err);
                $c->stash->{'checked_action_menus'}->{$menu} = { err => $err };
                return($c->stash->{'checked_action_menus'}->{$menu});
            }
            $c->stash->{'checked_action_menus'}->{$menu}->{'data'} = decode_utf8(Thruk::Utils::IO::read($sourcefile));
        } else {
            $c->stash->{'checked_action_menus'}->{$menu}->{'data'} = $c->config->{'action_menu_items'}->{$menu};
        }

        if($sourcefile && $sourcefile =~ m/\.js$/mx) {
            # js file
            $c->stash->{'checked_action_menus'}->{$menu}->{'type'} = 'js';
            if($c->stash->{'checked_action_menus'}->{$menu}->{'data'} =~ m/function\s+([^\(\s]+)\s*\(/mx) {
                $c->stash->{'checked_action_menus'}->{$menu}->{'function'} = $1;
            }
        } else {
            # json file
            $c->stash->{'checked_action_menus'}->{$menu}->{'type'} = 'json';
            # fix trailing commas in menu
            $c->stash->{'checked_action_menus'}->{$menu}->{'data'} =~ s/\,\s*([\}\]\)]+)/$1/gmx;
            my $err = validate_json($c->stash->{'checked_action_menus'}->{$menu}->{'data'});
            if($err) {
                $c->stash->{'checked_action_menus'}->{$menu}->{'err'} = $err;
                _error("error in action menu".($sourcefile ? " (from file ".$sourcefile.")" : "").": ".$err."\nsource:\n".$c->stash->{'checked_action_menus'}->{$menu}->{'data'});
            }
        }
        $c->stash->{'checked_action_menus'}->{$menu}->{'name'} = $menu;
        return($c->stash->{'checked_action_menus'}->{$menu});
    }

    # fix trailing commas in menu
    $menu =~ s/\,\s*([\}\]\)]+)/$1/gmx;

    my $err = validate_json($menu);
    if($err) {
        _error("error in action menu".($sourcefile ? " (from file ".$sourcefile.")" : "").": ".$err."\nsource:\n".$menu);
    }
    if($ENV{THRUK_REPORT} && !$err) {
        # workaround for images being placed by js document.write later
        my $image_data = {};
        my $items = Cpanel::JSON::XS->new->decode($menu);
        for my $item (@{Thruk::Base::list($items)}) {
            $image_data->{$item->{'icon'}} = '' if $item->{'icon'};
        }
        require Thruk::Utils::Reports::Render;
        return({err => $err, type => 'json', data => $menu, icons => Thruk::Utils::Reports::Render::set_action_image_data_urls($c, $image_data)});
    }
    return({err => $err, type => 'json', data => $menu });
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
        return _escape_tags_js(Cpanel::JSON::XS->new->encode([@_]));
    }
    return _escape_tags_js(Cpanel::JSON::XS->new->encode($_[0]));
}

########################################

=head2 json_encode_pretty

  json_encode_pretty(array|hash)

returns pretty json encoded string

=cut
sub json_encode_pretty {
    return _escape_tags_js(Cpanel::JSON::XS->new->pretty->canonical->encode($_[0]));
}

########################################

=head2 encode_json_obj

  encode_json_obj(array, [decode])

returns json encoded object

=cut
sub encode_json_obj {
    return decode_utf8(_escape_tags_js(Cpanel::JSON::XS::encode_json($_[0]))) if $_[1];
    return _escape_tags_js(Cpanel::JSON::XS::encode_json($_[0]));
}

########################################

=head2 _escape_tags_js

  _escape_tags_js($text)

used to escape html tags so it can be used as javascript string

=cut
sub _escape_tags_js {
    my($str) = @_;
    $str =~ s%</(\w+)%<\\/$1%gmx;
    return $str;
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
    $text =~ s/'/&#39;/gmx;
    $text =~ s/\\/&#92;/gmx;
    return _escape_tags_js($text);
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

  get_message($c, [$unescaped])

get a message from an cookie, display and delete it

=cut
sub get_message {
    my($c, $unescaped) = @_;

    my $has_details = 0;

    # message from cookie?
    if(defined $c->cookies('thruk_message')) {
        my $cookie = $c->cookies('thruk_message');
        $c->cookie('thruk_message', '', { expires => 0 });
        # sometimes the cookie is empty, so delete it in every case
        # and show it if it contains data
        if($cookie) {
            my($style,$message) = split(/~~/mx, $cookie, 2);
            return '' unless $message;
            $message = &escape_html($message);
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
        delete $c->res->{'cookies'}->{'thruk_message'};
        if(defined $c->stash->{'thruk_message_details'}) {
            $has_details = 1;
        }
        return($c->stash->{'thruk_message_style'}, $c->stash->{'thruk_message_raw'}, $has_details) if $unescaped;
        my(undef, $thruk_message) = split/~~/mx, $c->stash->{'thruk_message'};
        return($c->stash->{'thruk_message_style'}, $thruk_message, $has_details);
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

=head2 logline_icon

  my $icon = logline_icon($logentry)

returns icon path

=cut
sub logline_icon {
    my($log) = @_;

    my $pic  = 'fa-solid fa-info';
    my $desc = '';
    my $type = $log->{'type'} || '';

    if($type eq 'CURRENT SERVICE STATE')               { $pic = "fa-solid fa-info";   $desc = "Informational Message"; }
    elsif($type eq 'CURRENT HOST STATE')               { $pic = "fa-solid fa-info";   $desc = "Informational Message"; }
    elsif($type eq 'SERVICE NOTIFICATION')             { $pic = "fa-solid fa-bell";   $desc = "Service Notification"; }
    elsif($type eq 'HOST NOTIFICATION')                { $pic = "fa-solid fa-bell";   $desc = "Host Notification"; }
    elsif($type eq 'SERVICE ALERT') {
                             if($log->{'state'} == 0)  { $pic = "fa-solid fa-check round small green";         $desc = "Service Ok"; }
                          elsif($log->{'state'} == 1)  { $pic = "fa-solid fa-exclamation round small yellow";  $desc = "Service Warning"; }
                          elsif($log->{'state'} == 2)  { $pic = "fa-solid fa-exclamation round small red";     $desc = "Service Critical"; }
                          elsif($log->{'state'} == 3)  { $pic = "fa-solid fa-question round small orange";     $desc = "Service Unknown"; }
    }
    elsif($type eq 'HOST ALERT') {
                             if($log->{'state'} == 0)  { $pic = "fa-solid fa-check round small green";     $desc = "Host Up"; }
                          elsif($log->{'state'} == 1)  { $pic = "fa-solid fa-exclamation round small red"; $desc = "Host Down"; }
                          elsif($log->{'state'} == 2)  { $pic = "fa-solid fa-exclamation round small red"; $desc = "Host Unreachable"; }
    }
    elsif($type eq 'SERVICE EVENT HANDLER')            { $pic = "fa-solid fa-rocket";              $desc = "Service Event Handler"; }
    elsif($type eq 'HOST EVENT HANDLER')               { $pic = "fa-solid fa-rocket";              $desc = "Host Event Handler"; }
    elsif($type eq 'EXTERNAL COMMAND')                 { $pic = "fa-solid fa-hand-point-right";    $desc = "External Command"; }
    elsif($type eq 'PASSIVE SERVICE CHECK')            { $pic = "fa-solid fa-arrows-down-to-line"; $desc = "Passive Service Check"; }
    elsif($type eq 'PASSIVE HOST CHECK')               { $pic = "fa-solid fa-arrows-down-to-line"; $desc = "Passive Host Check"; }

    elsif($type eq 'SERVICE FLAPPING ALERT') {
           if($log->{'message'} =~ m/;STARTED;/mx)     { $pic = "fa-solid fa-shuffle";        $desc = "Service started flapping"; }
        elsif($log->{'message'} =~ m/;STOPPED;/mx)     { $pic = "fa-solid fa-shuffle";        $desc = "Service stopped flapping"; }
        elsif($log->{'message'} =~ m/;DISABLED;/mx)    { $pic = "fa-solid fa-shuffle";        $desc = "Service flap detection disabled"; }
    }
    elsif($type eq 'HOST FLAPPING ALERT') {
           if($log->{'message'} =~ m/;STARTED;/mx)     { $pic = "fa-solid fa-shuffle";      $desc = "Host started flapping"; }
        elsif($log->{'message'} =~ m/;STOPPED;/mx)     { $pic = "fa-solid fa-shuffle";      $desc = "Host stopped flapping"; }
        elsif($log->{'message'} =~ m/;DISABLED;/mx)    { $pic = "fa-solid fa-shuffle";      $desc = "Host flap detection disabled"; }
    }
    elsif($type eq 'SERVICE DOWNTIME ALERT') {
          if($log->{'message'} =~ m/;STARTED;/mx)      { $pic = "fa-solid fa-moon";         $desc = "Service entered a period of scheduled downtime"; }
       elsif($log->{'message'} =~ m/;STOPPED;/mx)      { $pic = "fa-solid fa-moon";         $desc = "Service exited a period of scheduled downtime"; }
       elsif($log->{'message'} =~ m/;CANCELLED;/mx)    { $pic = "fa-solid fa-moon";         $desc = "Service scheduled downtime has been cancelled"; }
    }
    elsif($type eq 'HOST DOWNTIME ALERT') {
          if($log->{'message'} =~ m/;STARTED;/mx)      { $pic = "fa-solid fa-moon";         $desc = "Host entered a period of scheduled downtime"; }
       elsif($log->{'message'} =~ m/;STOPPED;/mx)      { $pic = "fa-solid fa-moon";         $desc = "Host exited a period of scheduled downtime"; }
       elsif($log->{'message'} =~ m/;CANCELLED;/mx)    { $pic = "fa-solid fa-moon";         $desc = "Host scheduled downtime has been cancelled"; }
    }
    elsif($type eq 'LOG ROTATION')                     { $pic = "fa-solid fa-rotate";       $desc = "Log Rotation"; }
    elsif($type =~ m/TIMEPERIOD TRANSITION/mx)         { $pic = "fa-solid fa-clock";        $desc = "Timeperiod Transition"; }
    elsif($type =~ m/restarting\.\.\./mx)              { $pic = "fa-solid fa-arrows-spin";  $desc = "Program Restart"; }
    elsif($type =~ m/starting\.\.\./mx)                { $pic = "fa-solid fa-play";         $desc = "Program Start"; }
    elsif($type =~ m/shutting down\.\.\./mx)           { $pic = "fa-solid fa-power-off";    $desc = "Program End"; }
    elsif($type =~ m/Bailing\ out/mx)                  { $pic = "fa-solid fa-power-off";    $desc = "Program End"; }
    else                                               { $pic = "fa-solid fa-info";         $desc = "Informational Message"; }

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
        return $obj->{'peer_key'}.':'.$obj->{$prefix.'custom_variable_values'}->[$x] if $var eq 'THRUK_BP_ID';
        $x++;
    }
    return 0;
}

########################################

=head2 fullversion

  my $str = fullversion($c)

returns full version string

=cut
sub fullversion {
    my($c) = @_;
    die("no c") unless defined $c;
    my $str = $c->config->{'thrukversion'} // '';
    if($c->config->{'extra_version'}) {
        $str .= '/ '.$c->config->{'extra_version'};
    }
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
        $warn =~ s/^(\-?[\d\.]+):(\-?[\d\.]+)$/$1-$2/mxo if $warn;
        $crit =~ s/^(\-?[\d\.]+):(\-?[\d\.]+)$/$1-$2/mxo if $crit;
        if(defined $var) {
            my $entry = {
                'parent'    => $last_parent,
                'name'      => $key,
                'value'     => $var,
                'unit'      => $unit,
                'min'       => $min,
                'max'       => $max,
                'warn'      => $warn,
                'crit'      => $crit,
                'orig'      => $orig,
            };
            for my $key (qw/value min max warn crit/) {
                $entry->{$key} = 0+$entry->{$key} if looks_like_number($entry->{$key});
            }
            push @{$data}, $entry;
        }
        $has_warn = 1 if(defined $warn && $warn ne '');
        $has_crit = 1 if(defined $crit && $crit ne '');
        $has_min  = 1 if(defined $min  && $min  ne '');
        $has_max  = 1 if(defined $max  && $max  ne '');
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
    return("") unless $c->{'session'};
    return("") unless $c->{'session'}->{'private_key'};

    my $sessiondata = $c->{'session'};
    if(!$sessiondata->{'csrf_token'}) {
        # session but no token yet
        require Thruk::Utils::CookieAuth;
        $sessiondata = Thruk::Utils::CookieAuth::store_session($c->config, $sessiondata->{'private_key'}, $sessiondata);
    }
    return $sessiondata->{'csrf_token'};
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
    my $hosts = {};
    my $hostbackends = {};
    if($type eq 'svc') {
        for my $d (@{$data}) {
            $hash->{'r'.$x} = $d->{'host_name'}.';'.$d->{'description'}.';'.$d->{'peer_key'};
            $hosts->{$d->{'host_name'}} = 'r'.$x unless $hosts->{$d->{'host_name'}};
            $hostbackends->{$d->{'host_name'}}->{$d->{'peer_key'}} = 1;
            $x++;
        }
        for my $hst (keys %{$hosts}) {
            my $row      = $hosts->{$hst};
            my $backends = join("|", keys %{$hostbackends->{$hst}});
            $hash->{$row} .= ';'.$backends;
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
    return(&json_encode($hash));
}

########################################

=head2 replace_macros

  replace_macros($text, $macros)

return text with replaced macros

=cut
sub replace_macros {
    my($text, $macros) = @_;
    return($text) unless $macros;
    for my $key (keys %{$macros}) {
        $text =~ s/\{\{\s*$key\s*\}\}/$macros->{$key}/gmxi;
    }
    return($text);
}

##############################################

=head2 set_time_locale

  set LC_TIME locale

remember to reset to default after template processing.

=cut
sub set_time_locale {
    my($locale) = @_;
    POSIX::setlocale(POSIX::LC_TIME, $locale);
    return("");
}

##############################################

=head2 lc

  lower case text

returns lower case string

=cut
sub lc {
    my($text) = @_;
    return(lc($text));
}

##############################################

=head2 debug

  print anything to stderr

returns empty string

=cut
sub debug {
    print STDERR Data::Dumper::Dumper(@_);
    return("");
}

##############################################

=head2 dump2str

  dump2str($anything, [$max_length], [$flat])

returns string from object

=cut
sub dump2str {
    my($any, $max_length, $flat) = @_;
    if(ref $any eq "") {
        return($any);
    }
    return(Thruk::Utils::dump_params($any, $max_length, $flat));
}

##############################################

=head2 peer_name

  get peer_name from dataset

returns peer_name

=cut
sub peer_name {
    my($row) = @_;

    my $c = $Thruk::Globals::c;

    if(ref $row ne "HASH") {
        my $peer = $c->db->get_peer_by_key($row);
        if($peer && $peer->{'name'}) {
            return($peer->{'name'});
        }
        return($row);
    }

    return($row->{'peer_name'}) if $row->{'peer_name'};

    if($row->{'peer_key'}) {
        if(ref $row->{'peer_key'} eq 'ARRAY') {
            my $names = [];
            for my $key (@{$row->{'peer_key'}}) {
                if($c->stash->{'backend_detail'}->{$key}) {
                    push @{$names}, $c->stash->{'backend_detail'}->{$key}->{'name'};
                }
            }
            return($names);
        } else {
            my $key = $row->{'peer_key'};
            if($c->stash->{'backend_detail'}->{$key}) {
                return($c->stash->{'backend_detail'}->{$key}->{'name'});
            }
        }
    }
    return("");
}

##############################################

=head2 servicestatetext

    servicestatetext($svc)

return string for given service

=cut
sub servicestatetext {
    my($svc) = @_;
    if(ref $svc ne "HASH") {
        return("PENDING");
    }
    if(!$svc->{'has_been_checked'}) {
        return("PENDING");
    }
    return(state2text($svc->{'state'}));
}

##############################################

=head2 hoststatetext

    hoststatetext($hst)

return string for given host

=cut
sub hoststatetext {
    my($hst) = @_;
    if(ref $hst ne "HASH") {
        return("PENDING");
    }
    if(!$hst->{'has_been_checked'}) {
        return("PENDING");
    }
    return(hoststate2text($hst->{'state'}));
}

##############################################

=head2 state2text

    state2text($state)

return string for given numerical state

=cut
sub state2text {
    my($nr) = @_;
    return unless defined $nr;
    if($nr == 0) { return 'OK'; }
    if($nr == 1) { return 'WARNING'; }
    if($nr == 2) { return 'CRITICAL'; }
    if($nr == 3) { return 'UNKNOWN'; }
    if($nr == 4) { return 'PENDING'; }
    return;
}

##############################################

=head2 hoststate2text

    hoststate2text($state)

return string for given numerical host state

=cut
sub hoststate2text {
    my($nr) = @_;
    return unless defined $nr;
    if($nr == 0) { return 'UP'; }
    if($nr == 1) { return 'DOWN'; }
    if($nr == 2) { return 'UNREACHABLE'; }
    if($nr == 3) { return 'UNKNOWN'; }
    if($nr == 4) { return 'PENDING'; }
    return;
}

##############################################

=head2 text2state

    text2state($state)

return numerical state for given text state

=cut
sub text2state {
    my($txt) = @_;
    return unless defined $txt;
    $txt = uc($txt);
    if($txt eq 'OK')       { return(0); }
    if($txt eq 'WARNING')  { return(1); }
    if($txt eq 'CRITICAL') { return(2); }
    if($txt eq 'UNKNOWN')  { return(3); }
    if($txt eq 'PENDING')  { return(4); }
    return;
}

##############################################

=head2 text2hoststate

    text2hoststate($state)

return numerical state for given text host state

=cut
sub text2hoststate {
    my($txt) = @_;
    $txt = uc($txt);
    if($txt eq 'UP')          { return(0); }
    if($txt eq 'DOWN')        { return(1); }
    if($txt eq 'UNREACHABLE') { return(2); }
    if($txt eq 'UNKNOWN')     { return(3); }
    if($txt eq 'PENDING')     { return(4); }
    return;
}

########################################

=head2 nice_stacktrace

    nice_stacktrace($text)

return nice stacktrace with external deps collapsed

=cut
sub nice_stacktrace {
    my($txt) = @_;
    my $nice = [];
    my $has_stack = 0;
    my $in_stack  = 0;
    my $rowNum    = 0;
    for my $line (split(/\n/mx, $txt)) {
        # only fixup stracktrace lines
        if($line =~ m/^(.*)\ at\ (.*)\ line\ (\d+)\.?$/mx) {
            $in_stack++;
            my($msg, $file, $nr) = ($1, $2, $3);
            if($in_stack == 1) {
                push @{$nice}, "<table class='body rowhover cellspacing-x max-w-full'>\n";
                push @{$nice}, CORE::sprintf("<tr><th>Message</th><th>Location</th></tr>\n");
            }
            my $class = "external textHINTsoft";
            my $original = $file;
            if($file =~ m%(lib/Thruk|/script/|/Thruk/plugins/|/templates/|eval)%mxi) {
                $class = "internal";
                $file =~ s%.*/Thruk/%Thruk/%gmx;
                $file =~ s%^lib/%Thruk/lib/%gmx;
                $file =~ s%^\./%Thruk/%gmx;
                $file =~ s%^Thruk/%../%gmx;
            }
            $msg =~ s/\ called$//gmx;
            if($in_stack == 1) {
                $class = "internal";
            }
            if($rowNum == 0) {
                $class .= " textHINT font-bold";
            }
            $rowNum++;
            $msg =~ s/(Thruk::Context=HASH\(.*?\))/<i title="$1">\$c<\/i>/gmx;
            chomp($line);
            push @{$nice}, CORE::sprintf("<tr class='%s'><td class='max-w-[60vw] truncate stack-message'>%s</td><td class='truncate stack-location' style='max-width: 300px;' title='%s line %d'>%s:%d</td></tr>\n", $class, $msg, $original, $nr, $file, $nr);
            $has_stack = 1;
        } else {
            if($in_stack) {
                $in_stack = 0;
                push @{$nice}, "</table>";
            }
            chomp($line);
            push @{$nice}, "<span class='p-2 textHINT font-bold'>".$line."</span><br>";
        }
    }
    if($in_stack) {
        push @{$nice}, "</table>\n";
    }
    if($has_stack) {
        push @{$nice}, "<script type=\"text/javascript\"><!--\nnice_stacktrace_init();\n--></script>";
    }
    return(join("", @{$nice}));
}

########################################

=head2 random_id

    random_id([$max_length])

return random id

=cut
sub random_id {
    return(int(rand(1000000000)));
}

########################################

=head2 log_line_plugin_output

    log_line_plugin_output($log_entry)

return plugin output of logline

=cut
sub log_line_plugin_output {
    my($l) = @_;
    return($l->{'plugin_output'}) if defined $l->{'plugin_output'};
    my $output = $l->{'message'};
    $output =~ s/^\[\d+\]\s+//gmx;
    my @parts = split(/;/mx, $output);
    return('') unless defined $l->{'type'};
    if($l->{'type'} eq 'SERVICE NOTIFICATION') {
        return($parts[5] // '');
    }
    if($l->{'type'} eq 'SERVICE ALERT') {
        return($parts[5] // '');
    }
    if($l->{'type'} eq 'HOST NOTIFICATION') {
        return($parts[4] // '');
    }
    if($l->{'type'} eq 'HOST ALERT') {
        return($parts[4] // '');
    }
    return('');
}

########################################

=head2 get_exposed_custom_vars

    get_exposed_custom_vars([$skip_wildcards])

return list of exposed custom variable names

=cut
sub get_exposed_custom_vars {
    my($skip_wildcards) = @_;
    my $c = $Thruk::Globals::c or die("not initialized!");
    return(Thruk::Utils::get_exposed_custom_vars($c->config, $skip_wildcards));
}

########################################

=head2 get_browser_user_agent

    get_browser_user_agent()

return request user agent.

=cut
sub get_browser_user_agent {
    my $c = $Thruk::Globals::c or die("not initialized!");
    return($c->req->header('user-agent') // 'unknown');
}

########################################

=head2 replace_links

    replace_links()

return text with http/https links replaced with real links
also replace [link text](https://url...) like markup links

=cut
sub replace_links {
    my($txt) = @_;

    my $c = $Thruk::Globals::c or die("not initialized!");

    # short links
    for my $pattern (@{$c->config->{'short_link'}}) {
        my @blocks = split(/\|/mx, $pattern);
        shift @blocks if $blocks[0] eq '';
        ## no critic
        my $re1 = qr($blocks[0]);
        my $re2 = $blocks[1];
        $txt =~ s|$re1|&_replace_dollars($re2, $1, $2, $3, $4, $5)|ge;
        ## use critic
    }

    # markup link: [link text](https://url...)
    $txt =~ s/\[([^\]]+)\]\((\w+:[^\)]+)\)
             /&_replace_link($1, $2)
             /gxme;

    # standard text link: https://link.domain/...
    $txt =~ s/(?:^|\s)(https?:\/\/(?:www\.)?[-a-zA-Z0-9\@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,8}\b(?:[-a-zA-Z0-9()\@:%_\+.~#?&\/=]*))(\s|<br>|$)
             /<a class="link" href="$1" target="_blank"><i class="uil uil-external-link-alt text-sm"><\/i>$1<\/a>$2
             /gmx;

    return($txt);
}

########################################
sub _replace_link {
    my($name, $url) = @_;
    $url =~ s/\ /%20/gmx;
    return('<a class="link" href="'.$url.'" target="_blank"><i class="uil uil-external-link-alt text-sm"></i>'.$name.'</a>');
}

########################################
sub _replace_dollars {
    my($txt, @replace) = @_;
    my $x = 0;
    for my $re (@replace) {
        $x++;
        next unless defined $re;
        $txt =~ s|\$$x|$re|gmx;
    }
    return($txt);
}

########################################

=head2 set_target_link

  set_target_link($href, $target)

returns updated url/target.

=cut
sub set_target_link {
    my($href, $target) = @_;
    my $c = $Thruk::Globals::c or die("not initialized!");

    $href   = $href   // '';
    $target = $target // '';

    return($href, $target) unless $href;

    my $product = $c->config->{'product_prefix'};
    my $prefix  = $c->stash->{'url_prefix'};
    if($href =~ s|^\Q/thruk/\E||mx || $href =~ s|^\Q$product\E/||mx || $href =~ s|^\Q$prefix\E||mx) {
        $target = _get_menu_target() unless defined $target;
        $href   = "${prefix}${href}";
        return($href, $target);
    }

    $target = _find_target_for_link($href) // $target;
    $target //= _get_menu_target();

    if(!$target || $target eq 'main') {
        if(_is_frame_url_allowed($href)) {
            $target = 'embedded';
            push @{$c->stash->{'allowed_frame_links'}}, $href;
        } else {
            $target = '_blank';
        }
    }

    return($href, $target);
}


##############################################
sub _is_frame_url_allowed {
    my($url) = @_;
    return 1 unless $url;
    my $c = $Thruk::Globals::c or die("not initialized!");

    $url = URI->new($url);
    my $req = $c->req->uri;

    # relative links are allowed
    return 1 unless $url->scheme;

    # same origin is allowed
    if($req->host eq $url->host) {
        return 1;
    }

    for my $allowed (@{ $c->config->{allowed_frame_links} // []}) {
        if($allowed =~ /\*/mx or $allowed !~ /\Ahttps?:/mx) {
            my $matcher = $allowed;
            $matcher =~ s/\Q.*/*/gmx;
            $matcher =~ s/\./\./gmx;
            $matcher =~ s/\*/.*/gmx;
            if($url->host =~ /\A$matcher/mx or $url->as_string =~ /\A$matcher/mx) {
                return 1;
            }
        } else {
            my $new = URI->new_abs($allowed, $req);
            if($new->host eq $url->host and $new->scheme eq $url->scheme) {
                return 1;
            }
        }
    }

    return;
}

##############################################
sub _find_target_for_link {
    my ($href) = @_;
    my $c = $Thruk::Globals::c or die("not initialized!");
    my @targets = @{ $c->config->{link_target} };
    for my $t (@targets) {
        my ($target, $regex) = split ' ', $t, 2;
        _error("cannot parse '$t': $target not defined") unless $target;
        _error("cannot parse '$t': $regex not defined") unless $regex;
        next if (!$target || !$regex);
        if($href =~ /$regex/) { ## no critic
            return $target;
        }
    }
    return;
}

##############################################
sub _get_menu_target {
    my $c = $Thruk::Globals::c;

    return($c->{'_menu_target'} ||= _set_menu_target($c));
}
sub _set_menu_target {
    my($c) = @_;
    return $c->stash->{'target'} if defined $c->stash->{'target'} and $c->stash->{'target'} ne '';
    return('_self');
}

########################################

=head2 is_icinga2

  is_icinga2($peer_key)

returns true if peer from given key is icinga 2

=cut
sub is_icinga2 {
    my($peer_key) = @_;

    my $c = $Thruk::Globals::c or die("not initialized!");

    if($c->stash->{'pi_detail'}->{$peer_key}->{'data_source_version'}) {
        if($c->stash->{'pi_detail'}->{$peer_key}->{'data_source_version'} =~ m/^Livestatus\s+r2\./mx) {
            return(1);
        }
        if($c->stash->{'pi_detail'}->{$peer_key}->{'data_source_version'} =~ m/^r2\./mx) {
            return(1);
        }
        if($c->stash->{'pi_detail'}->{$peer_key}->{'data_source_version'} =~ m/icinga2/mx) {
            return(1);
        }
    }
    return;
}

########################################
sub _plural_s {
    my($nr) = @_;
    return "" if $nr == 1;
    return("s");
}

########################################
sub _host {
    my($obj) = @_;
    my $c = $Thruk::Globals::c;
    if(ref $obj eq 'HASH') {
        if(!defined $c->config->{'host_name_source'} || scalar @{$c->config->{'host_name_source'}} == 0) {
            return($obj->{'display_name'} // $obj->{'name'} // "?");
        }
        return(_obj_name($obj, $c->config->{'host_name_source'}) // $obj->{'display_name'} // $obj->{'name'} // "?");
    }
    elsif($c->stash->{'host_extra_info'} && $c->stash->{'host_extra_info'}->{$obj}) {
        return(_host($c->stash->{'host_extra_info'}->{$obj}));
    }
    elsif($c->stash->{'service_extra_info'} && $c->stash->{'service_extra_info'}->{$obj}) {
        my $svc = (values(%{$c->stash->{'service_extra_info'}->{$obj}}))[0];
        return(_shost($svc)) if $svc;
    }
    return($obj);
}

########################################
# same as _host, but use host from a service object (prefix attributes with host_)
sub _shost {
    my($obj) = @_;
    my $c = $Thruk::Globals::c;
    if(ref $obj eq 'HASH') {
        if(!defined $c->config->{'host_name_source'} || scalar @{$c->config->{'host_name_source'}} == 0) {
            return($obj->{'host_display_name'} // $obj->{'host_name'} // "?");
        }
        return(_obj_name($obj, $c->config->{'host_name_source'}, 'host_') // $obj->{'host_display_name'} // $obj->{'host_name'} // "?");
    }
    elsif($c->stash->{'host_extra_info'} && $c->stash->{'host_extra_info'}->{$obj}) {
        return(_host($c->stash->{'host_extra_info'}->{$obj}));
    }
    elsif($c->stash->{'service_extra_info'} && $c->stash->{'service_extra_info'}->{$obj}) {
        my $svc = (values(%{$c->stash->{'service_extra_info'}->{$obj}}))[0];
        return(_shost($svc)) if $svc;
    }
    return($obj);
}

########################################
sub _service {
    my($obj, $desc) = @_;
    my $c = $Thruk::Globals::c;
    if(ref $obj eq 'HASH') {
        if(!defined $c->config->{'service_description_source'} ||  scalar @{$c->config->{'service_description_source'}} == 0) {
            if($c->config->{'use_service_description'}) {
                return($obj->{'description'} // "?");
            }
            return($obj->{'display_name'} // $obj->{'description'} // "?");
        }
        return(_obj_name($obj, $c->config->{'service_description_source'}) // $obj->{'display_name'} // $obj->{'description'} // "?");
    }
    elsif($desc && $c->stash->{'service_extra_info'} && $c->stash->{'service_extra_info'}->{$obj} && $c->stash->{'service_extra_info'}->{$obj}->{$desc}) {
        return(_service($c->stash->{'service_extra_info'}->{$obj}->{$desc}));
    }
    return($obj);
}

########################################
sub _obj_name {
    my($obj, $config, $attr_prefix) = @_;
    $attr_prefix = "" unless $attr_prefix;
    for my $src (@{$config}) {
        my $name;
        if($src =~ m/^_/mxo) {
            next unless $obj->{$attr_prefix."custom_variable_names"};
            my $src2 = $src;
            $src2 =~ s/^_//gmx;
            my $x = 0;
            for my $var (@{$obj->{$attr_prefix."custom_variable_names"}}) {
                if($var eq $src2) {
                    $name = $obj->{$attr_prefix."custom_variable_values"}->[$x];
                    last;
                }
                $x++;
            }
            return($name) if defined $name;
        } else {
            $name = $obj->{$attr_prefix.$src};
        }
        return($name) if defined $name;
    }
    return;
}

########################################

=head2 search2text

  search2text($type, $filter)

returns text/lexical filter for structured filter

=cut
sub search2text {
    my $c = $Thruk::Globals::c;
    return(Thruk::Utils::Status::search2text($c, @_));
}

########################################

=head2 format_perf_number

  format_perf_number($number, $unit, $always_show_unit)

returns number as used in human performance data table

=cut
sub format_perf_number {
    my($number, $unit, $always_show_unit) = @_;
    return $number unless($number && $number =~ m/^\-?[\d\.]+$/mx);
    if($number ne "0" && $unit eq "B") {
        my($reduced_number, $reduced_unit) = Thruk::Utils::reduce_number($number, $unit);
        if($always_show_unit || $reduced_unit ne $unit) {
            return(CORE::sprintf("%.1f%s", $reduced_number, $reduced_unit));
        }
        return(CORE::sprintf("%.1f", $reduced_number));
    }

    return(Thruk::Utils::format_number($number).($always_show_unit ? $unit : ""));
}

########################################

=head2 prefer_date_if_timestamp

  prefer_date_if_timestamp($ts)

returns date if ts is a unix timestamp or original ts otherwise

=cut
sub prefer_date_if_timestamp {
    my($ts) = @_;
    if($ts !~ m/^\d+$/mx) {
        return($ts);
    }
    return(Thruk::Utils::format_date($ts, '%Y-%m-%d %H:%M:%S'));
}

########################################

=head2 list_intersect

  list_intersect($lista, $listb)

returns all elements from lista which are also in listb

=cut

sub list_intersect {
    my($lista, $listb) = @_;
    my @intersect;

    my $lookup = Thruk::Base::array2hash(Thruk::Base::list($listb));
    for my $el (@{Thruk::Base::list($lista)}) {
        push @intersect, $el if $lookup->{$el};
    }

    return(\@intersect);
}

########################################

=head2 list_not_intersect

  list_not_intersect($lista, $listb)

returns all elements from lista which are not in listb

=cut

sub list_not_intersect {
    my($lista, $listb) = @_;
    my @list;

    my $lookup = Thruk::Base::array2hash(Thruk::Base::list($listb));
    for my $el (@{Thruk::Base::list($lista)}) {
        push @list, $el unless $lookup->{$el};
    }

    return(\@list);
}

########################################

=head2 is_empty_filter

  is_empty_filter($filter)

returns true if filter contains no actual filter

=cut

sub is_empty_filter {
    my($filter) = @_;

    return 0 if(defined $filter->{'hostprops'}          && $filter->{'hostprops'} != 0);
    return 0 if(defined $filter->{'hoststatustypes'}    && $filter->{'hoststatustypes'} != 15);
    return 0 if(defined $filter->{'serviceprops'}       && $filter->{'serviceprops'} != 0);
    return 0 if(defined $filter->{'servicestatustypes'} && $filter->{'servicestatustypes'} != 31);

    return(1);
}

########################################

1;
