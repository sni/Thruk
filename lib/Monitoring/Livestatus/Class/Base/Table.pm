package # hide from pause
    Monitoring::Livestatus::Class::Base::Table;

use Moose;
use Carp;

use Monitoring::Livestatus::Class::Abstract::Filter;
use Monitoring::Livestatus::Class::Abstract::Stats;

use Monitoring::Livestatus::Class;
my $TRACE = Monitoring::Livestatus::Class->TRACE() || 0;

has 'ctx' => (
    is => 'rw',
    isa => 'Monitoring::Livestatus::Class',
    handles => [qw/backend_obj/],
);

#
#  Filter Stuff
#
has 'filter_obj' => (
    is => 'ro',
    isa => 'Monitoring::Livestatus::Class::Abstract::Filter',
    builder => '_build_filter',
    handles => { apply_filer => 'apply' },
);

sub _build_filter { return Monitoring::Livestatus::Class::Abstract::Filter->new(); };

sub filter {
    my $self = shift;
    my $cond = shift;

    my @statments = $self->apply_filer($cond);
    my @tmp = @{ $self->statments || [] };
    push @tmp, @statments;
    $self->_statments(\@tmp);
    return $self;
}

sub options {
    my($self, $options) = @_;
    $self->{'_options'} = $options;
    return $self;
}

#
#  Stats Stuff
#
has 'stats_obj' => (
    is => 'ro',
    isa => 'Monitoring::Livestatus::Class::Abstract::Stats',
    builder => '_build_stats',
    handles => { apply_stats => 'apply' },
);

sub _build_stats { return Monitoring::Livestatus::Class::Abstract::Stats->new(); };

sub stats {
    my $self = shift;
    my $cond = shift;

    my @statments = $self->apply_stats($cond);
    my @tmp = @{ $self->statments || [] };
    push @tmp, @statments;
    $self->_statments(\@tmp);
    return $self;
}

has 'table_name' => (
    is => 'ro',
    isa => 'Str',
    builder  => 'build_table_name',
);

sub build_table_name { die "build_table_name must be implemented in " . ref(shift) };

#
# Primary key stuff
#
has 'primary_keys' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    builder  => 'build_primary_keys',
);

sub build_primary_keys { die "build_primary_keys must be implemented in " . ref(shift) };

sub has_single_primary_key {
    my $self = shift;
    if ( scalar @{ $self->primary_keys } == 1 ){
        return 1
    }
    return;
}

sub single_primary_key {
    my $self = shift;
    if ( $self->has_single_primary_key ){
        return $self->primary_keys->[0];
    }
    return;
}

has '_statments' => (
    is => 'rw',
    reader => 'statments',
    isa => 'ArrayRef',
    default => sub { return []; }
);

has '_options' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; }
);

has '_columns' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { return []; }
);

sub columns {
    my $self = shift;
    my @columns = @_ ;
    $self->_columns( \@columns );
    return $self;
}

sub headers{
    my $self = shift;

    my $statment = sprintf("GET %s\nLimit: 1",$self->table_name);
    my ( $hash_ref ) = @{ $self->backend_obj->selectall_arrayref($statment,{ slice => 1}) };
    my @cols = keys %$hash_ref;
    return wantarray ? @cols : \@cols;
}

sub hashref_array {
    my $self = shift;

    my @statments = ();
    if ( scalar @{ $self->_columns } > 0 ){
        push @statments, sprintf('Columns: %s',join(' ',@{  $self->_columns  }));
    }
    push @statments, @{ $self->statments };

    my @data =  $self->_execute( @statments );
    return wantarray ? @data : \@data;
}

sub hashref_pk {
    my $self = shift;
    my $key  = $self->single_primary_key || shift;
    unless ( $key ) {
        croak("There was no single primary key to be found.");
    };
    my %indexed;
    my @data = $self->hashref_array();
    for my $row (@data) {
        if(!defined $row->{$key}) {
            my %possible_keys = keys %{$row};
            croak("key $key not found in result set, possible keys are: ".join(', ', sort keys %possible_keys));
        } else {
            $indexed{$row->{$key}} = $row;
        }
    }
    return wantarray ? %indexed : \%indexed;
}

sub _execute {
    my $self = shift;
    my @data = @_;

    my @statments = ();
    push @statments, sprintf("GET %s",$self->table_name);
    push @statments, @data;

    printf STDERR "EXECUTE: %s\n", join("\nEXECUTE: ",@statments)
        if $TRACE >= 1;

    my $statment = join("\n",@statments);

    my $options = $self->{'_options'};
    $options->{'slice'} = {};

    my $return = $self->backend_obj->selectall_arrayref($statment, $options);

    return wantarray ? @{ $return }  : $return;
}

1;
__END__
=head1 NAME

Monitoring::Livestatus::Class::Base::Table - Base class for all table objects.

=head2 SYNOPSIS

    my $class = Monitoring::Livestatus::Class->new(
        backend => 'INET',
        socket => '10.211.55.140:6557',
    );

    my $table_obj = $class->table('services');

    my $data = $table_obj->search( {} )->hashref_array();

=head1 ATTRIBUTES

=head2 ctx

Reference to context object L<Monitoring::Livestatus::Class>

=head2 filter

Reference to filter object L<Monitoring::Livestatus::Class>

=head2 stats

Reference to filter object L<Monitoring::Livestatus::Class>

=head2 table_name

Containts the table name.

=head2 statments

Containts all the statments.

=head2 options

Containts all the options.

=head1 METHODS

=head2 columns

Arguments: $colA, $colB, ...

Return: $self

Set columns...

=head2 headers

Returns a array or reference to array, depending on the calling context, of all
header columns.

=head2 filter

Example usage:

    $table_obj->search( { name => 'localhost' } );
    $table_obj->search( { name => [ 'localhost', 'gateway' ] } );
    $table_obj->search( [ { name => 'localhost' }, { name => 'gateway' } ] );

Returns: $self

=head2 hashref_array

Returns a array or reference to array, depending on the calling context.

Example usage:

    my $hashref_array = $table_obj->search( { } )->hashref_array;
    print Dumper $hashref_array;


=head2 hashref_pk

Returns a hash of hash references.

Example usage:

    my $hashref_pk = $table_obj->search( { } )->hashref_pk();
    print Dumper $hashref_pk;

=head2 has_single_primary_key

=head2 single_primary_key

=head2 build_table_name

=head2 build_primary_keys

=head1 AUTHOR

See L<Monitoring::Livestatus::Class/AUTHOR> and L<Monitoring::Livestatus::Class/CONTRIBUTORS>.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Bohne.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
