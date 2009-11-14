package Nagios::Web::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config(
                    TEMPLATE_EXTENSION => '.tt',
                    ENCODING           => 'utf8',
                    INCLUDE_PATH       =>  'templates',
                    );

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
