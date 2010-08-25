package Monitoring::Livestatus::Class;

use Moose;
use Module::Find;

our $VERSION = '0.03';

sub TRACE { return $ENV{'MONITORING_LIVESTATUS_CLASS_TRACE'} || 0 };
our $TRACE = TRACE();

has 'peer' => (
    is       => 'rw',
    required => 1,
);

has 'verbose' => (
    is       => 'rw',
    isa      => 'Bool',
    required => 0,
);

has 'logger' => (
    is       => 'rw',
#    isa      => 'Object',
    required => 0,
);

has 'keepalive' => (
    is       => 'rw',
    isa      => 'Bool',
    required => 0,
);

has 'name' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);


has 'backend_obj' => (
    is       => 'ro',
);

has 'table_sources' => (
    is      => 'ro',
    # isa     => 'ArrayRef',
    builder  => '_build_table_sources',
);

sub _build_table_sources {
    my $self = shift;
    my @found = useall Monitoring::Livestatus::Class::Table;
    return \@found;
}

sub BUILD {
    my $self = shift;

    my $backend = sprintf 'Monitoring::Livestatus';
    Class::MOP::load_class($backend);
    $self->{backend_obj} = $backend->new(
        name      => $self->{name},
        peer      => $self->{peer},
        keepalive => $self->{keepalive},
        verbose   => $self->{verbose},
        logger    => $self->{logger},
    );
    return $self;
}



sub table {
    my $self = shift;
    my $table = ucfirst(lc(shift));
    my $class = sprintf("Monitoring::Livestatus::Class::Table::%s",$table);
    return $class->new( ctx => $self );
}

1;
__END__

=head1 NAME

Monitoring::Livestatus::Class - Object-Oriented interface for
Monitoring::Livestatus

=head1 DESCRIPTION

This module is an object-oriented interface for Monitoring::Livestatus

B<The module is still in an early stage of development, there can be some
api changes between releases.>

=head1 REPOSITORY

    Git: http://github.com/rbo/Monitoring-Livestatus-Class

=head1 SYNOPSIS

    use Monitoring::Livestatus::Class;

    my $class = Monitoring::Livestatus::Class->new(
        peer => '/var/lib/nagios3/rw/livestatus.sock'
    );

    my $hosts = $class->table('hosts');
    my @data = $hosts->columns('display_name')->filter(
        { display_name => { '-or' => [qw/test_host_47 test_router_3/] } }
    )->hashref_array();
    print Dumper \@data;

=head1 ATTRIBUTES

=head2 peer

Connection point to the status check_mk livestatus addon. This can be a unix
domain or tcp socket.

=head3 Socket

    my $class = Monitoring::Livestatus::Class->new(
	peer => '/var/lib/nagios3/rw/livestatus.sock'
    );

=head3 TCP Connection

    my $class = Monitoring::Livestatus::Class->new(
	peer => '192.168.1.1:2134'
    );

=head1 METHODS

=head2 table_sources

Arguments: none

Returns: @list

Get a list of all table class names.

=head2 table

Arguments: $table_name

Returns: $table_object

Returns a table object based on L<Monitoring::Livestatus::Class::Base::Table>

=head1 INTERNAL METHODS

=over 4

=item BUILD

Initializes the internal L<Monitoring::Livestatus> object.

=item TRACE

Get the trace level

=back

=head1 ENVIRONMENT VARIABLES

=head2 MONITORING_LIVESTATUS_CLASS_TRACE

Print tracer output from this object.

=head2 MONITORING_LIVESTATUS_CLASS_TEST_PEER

Set peer for live tests.

=head1 AUTHOR

Robert Bohne, C<< <rbo at cpan.org> >>

=head1 CONTRIBUTORS

nierlein: Sven Nierlein <nierlein@cpan.org>

=head1 TODO:

=over 4

=item * Bettering the documentation

=back

=head1 BUGS

Please report any bugs or feature requests to
C<bug-Monitoring-Livestatus-Class at rt.cpan.org>,
or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Monitoring-Livestatus-Class>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Monitoring::Livestatus::Class


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Monitoring-Livestatus-Class>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Monitoring-Livestatus-Class>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Monitoring-Livestatus-Class>

=item * Search CPAN

L<http://search.cpan.org/dist/Monitoring-Livestatus-Class/>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Bohne.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
