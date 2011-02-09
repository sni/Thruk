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
use Date::Manip;


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
    my $duration = shift;
    my $withdays = shift;

    croak("undef duration in duration(): ".$duration) unless defined $duration;
    $duration = $duration * -1 if $duration < 0;

    $withdays = 1 unless defined $withdays;

    croak("unknown withdays in duration(): ".$withdays) if($withdays != 0 and $withdays != 1 and $withdays != 2);

    if($duration < 0) { $duration = time() + $duration; }

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
        return($days."d ".$hours."h ".$minutes."m ".$seconds."s");
    }
    if($withdays == 2) {
        return($minutes."min ".$seconds."sec");
    }
    return($hours."h ".$minutes."m ".$seconds."s");
}


##############################################

=head2 nl2br

  my $string = nl2br($string);

replace newlines with linebreaks

=cut
sub nl2br {
    my $string = shift;
    $string =~ s/\n/<br\ \/>/gmx;
    $string =~ s/\r//gmx;
    $string =~ s/\\n/<br\ \/>/gmx;
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
    return sprintf $format, @_;
}


##############################################

=head2 date_format

  my $string = date_format($seconds);

formats a time definition into date format

=cut
sub date_format {
    my $c         = shift;
    my $timestamp = shift;

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

    my($year,$month,$day, $hour,$min,$sec,$doy,$dow,$dst) = Localtime($timestamp);

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
    $uri =~ s/&/&amp;/gmx;
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

    for my $key (keys %{$data}) {
        $data->{$key} = undef if $data->{$key} eq 'undef';
    }

    my $uri;
    eval {
        $uri = $c->request->uri_with($data);
        $uri =~ s/&/&amp;/gmx;
    };
    if($@) {
        confess("ERROR in uri_with(): ".$@);
    }
    return $uri;
}

########################################

=head2 html_escape

  html_escape($text)

returns an escaped string

=cut
sub html_escape {
    my $text = shift;

    return HTML::Entities::encode($text);
}


########################################

=head2 escape_quotes

  escape_quotes($text)

used to escape html tags so it can be used as javascript string

=cut
sub escape_quotes {
    my $text = shift;
    $text = HTML::Entities::encode($text);
    $text =~ s/&amp;quot;/&quot;/gmx;
    $text =~ s/&amp;gt;/>/gmx;
    $text =~ s/&amp;lt;/</gmx;
    return $text;
}


########################################

=head2 xml_escape

  xml_escape($text)

returns an escaped string for xml output

=cut
sub xml_escape {
    my $text = shift;

    return HTML::Entities::encode($text, '<>');
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

=head2 get_message

  get_message($c)

get a message from an cookie, display and delete it

=cut
sub get_message {
    my $c       = shift;

    # message from cookie?
    if(defined $c->request->cookie('thruk_message')) {
        my $cookie = $c->request->cookie('thruk_message');
        my($style,$message) = split/~~/mx, $cookie->value;

        $c->res->cookies->{'thruk_message'} = {
            value   => '',
            expires => '-1M',
        };

        return($style, $message);
    }
    # message from stash
    elsif(defined $c->stash->{'thruk_message'}) {
        my($style,$message) = split/~~/mx, $c->stash->{'thruk_message'};
        delete $c->res->cookies->{'thruk_message'};
        return($style, $message);
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


1;

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
