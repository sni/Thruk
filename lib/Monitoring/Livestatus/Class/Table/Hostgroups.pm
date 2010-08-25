package # hide from pause
    Monitoring::Livestatus::Class::Table::Hostgroups;

use Moose;
extends 'Monitoring::Livestatus::Class::Base::Table';

sub build_table_name { return 'hostgroups' };

sub build_primary_keys { return [qw/name/] };

1;
__END__
=head1 NAME

Monitoring::Livestatus::Class::Table::Hostgroups - Class for hostgroups table

=head1 METHODS

=head2 build_table_name

=head2 build_primary_keys

Returns the table name from these class.

=head1 AUTHOR

See L<Monitoring::Livestatus::Class/AUTHOR> and L<Monitoring::Livestatus::Class/CONTRIBUTORS>.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Bohne.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut