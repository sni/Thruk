package Nagios::Web::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config(
                    TEMPLATE_EXTENSION => '.tt',
                    ENCODING           => 'utf8',
                    INCLUDE_PATH       =>  'templates',
                    FILTERS            => {
                                            "duration"  => \&filter_duration,
                                       },
                    );

##############################################
# calculate a duration in the
# format: 0d 0h 29m 43s
sub filter_duration {
    my $date     = shift;
    my $duration = time() - $date;

    my $days    = 0;
    my $hours   = 0;
    my $minutes = 0;
    my $seconds = 0;
    if($duration > 86400) {
        $days     = int($duration/86400);
        $duration = $duration%86400;
    }
    if($duration > 3600) {
        $hours    = int($duration/3600);
        $duration = $duration%3600;
    }
    if($duration > 60) {
        $minutes  = int($duration/60);
        $duration = $duration%60;
    }
    $seconds = $duration;

    return($days."d ".$hours."h ".$minutes."m ".$seconds."s");
}

=head1 NAME

Nagios::Web::View::TT - TT View for Nagios::Web

=head1 DESCRIPTION

TT View for Nagios::Web.

=head1 AUTHOR

=head1 SEE ALSO

L<Nagios::Web>

sven,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
