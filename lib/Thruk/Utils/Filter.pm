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
use Date::Calc qw/Localtime Mktime Monday_of_Week Week_of_Year Today/;
use Date::Manip;


##############################################
=head1 METHODS

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


1;

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
