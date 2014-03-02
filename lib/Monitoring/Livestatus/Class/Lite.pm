package Monitoring::Livestatus::Class::Lite;

=head1 NAME

Monitoring::Livestatus::Class::Lite - Object-Oriented interface for
Monitoring::Livestatus

=head1 DESCRIPTION

This module is an object-oriented interface for Monitoring::Livestatus.
Just like Monitoring::Livestatus::Class but without Moose.

=head1 SYNOPSIS

    use Monitoring::Livestatus::Class::Lite;

    my $class = Monitoring::Livestatus::Class::Lite->new(
        peer => '/var/lib/nagios3/rw/livestatus.sock'
    );

    my $hosts = $class->table('hosts');
    my @data = $hosts->columns('display_name')->filter(
        { display_name => { '-or' => [qw/test_host_47 test_router_3/] } }
    )->hashref_array();
    print Dumper \@data;

=head1 ATTRIBUTES

=head2 peer

Connection point to the livestatus addon. This can be a unix
domain or tcp socket.

=head3 Socket

    my $class = Monitoring::Livestatus::Class->new(
        peer => '/var/lib/nagios3/rw/livestatus.sock'
    );

=head3 TCP Connection

    my $class = Monitoring::Livestatus::Class->new(
        peer => '192.168.1.1:2134'
    );

=head1 ENVIRONMENT VARIABLES

=head2 MONITORING_LIVESTATUS_CLASS_TRACE

Print tracer output from this object.

=head2 MONITORING_LIVESTATUS_CLASS_TEST_PEER

Set peer for live tests.

=cut

use warnings;
use strict;
use Carp;
use Scalar::Util qw/blessed/;
use List::Util qw/first/;
use Monitoring::Livestatus;

our $VERSION = '0.05';
our $TRACE   = $ENV{'MONITORING_LIVESTATUS_CLASS_TRACE'} || 0;

our $compining_prefix = '';
our $filter_mode      = '';

################################################################################

=head1 METHODS

=head2 new

    new($options)

create new Class module

=cut
sub new {
    my($class, $self) = @_;

    if(ref $self ne 'HASH') {
        $self = { 'peer' => $self };
    }

    $self->{backend_obj} = Monitoring::Livestatus->new(
        name      => $self->{'name'},
        peer      => $self->{'peer'},
        verbose   => $self->{'verbose'},
        keepalive => $self->{'keepalive'},
    );
    bless($self, $class);

    return $self;
}

################################################################################

=head2 table

    table($tablename)

return instance for this table

=cut
sub table {
    my($self, $name) = @_;
    confess('need table name') unless $name;
    my $table = {
            '_class' => $self->{'backend_obj'},
            '_table' => $name,
    };
    bless($table, 'Monitoring::Livestatus::Class::Lite');
    return $table;
}

################################################################################

=head2 columns

    columns($columns)

list of columns to fetch

=cut
sub columns {
    my($self, @columns) = @_;
    $self->{'_columns'} = \@columns;
    return $self;
}

################################################################################

=head2 options

    options($options)

set query options

=cut
sub options {
    my($self, $options) = @_;
    $self->{'_options'} = $options;
    return $self;
}

################################################################################

=head2 filter

    filter($filter)

filter result set

=cut
sub filter {
    my($self, $filter) = @_;
    $self->{'_filter'} = $self->{'_filter'} ? [@{$self->{'_filter'}}, $filter] : [$filter];
    return $self;
}

################################################################################

=head2 stats

    stats($statsfilter)

set stats filter

=cut
sub stats {
    my($self, $filter) = @_;
    $self->{'_statsfilter'} = $self->{'_statsfilter'} ? [@{$self->{'_statsfilter'}}, $filter] : [$filter];
    return $self;
}

################################################################################

=head2 hashref_pk

    hashref_pk($key)

return result as hash ref by key

=cut
sub hashref_pk {
    my($self, $key) = @_;

    confess("no key!") unless $key;

    my %indexed;
    my @data = $self->hashref_array();
    confess('undefined index: '.$key) if(defined $data[0] and !defined $data[0]->{$key});
    for my $row (@data) {
        $indexed{$row->{$key}} = $row;
    }
    return wantarray ? %indexed : \%indexed;
}

################################################################################

=head2 hashref_array

    hashref_array()

return result as array

=cut
sub hashref_array {
    my($self) = @_;
    my @data = $self->_execute();
    return wantarray ? @data : \@data;
}

################################################################################

=head2 statement

    statement()

return query as text

=cut
sub statement {
    my($self) = @_;

    confess("no table??") unless $self->{'_table'};

    my @statements = ();
    if( $self->{'_columns'} ) {
        push @statements, sprintf('Columns: %s',join(' ',@{ $self->{'_columns'} }));
    }

    # filtering
    if( $self->{'_filter'} ) {
        push @statements, @{$self->_apply_filter($self->{'_filter'})};
    }
    if( $self->{'_statsfilter'} ) {
        push @statements, @{$self->_apply_filter($self->{'_statsfilter'}, 'Stats')};
    }

    unshift @statements, sprintf("GET %s", $self->{'_table'});

    printf STDERR "EXEC: %s\n", join("\nEXEC: ",@statements) if $TRACE >= 1;

    my $statement = join("\n",@statements);

    return $statement;
}

################################################################################
# INTERNAL SUBs
################################################################################
sub _execute {
    my($self) = @_;
    my $statement = $self->statement();
    my $options   = $self->{'_options'};
    $options->{'slice'} = {};

    my $return = $self->{'_class'}->selectall_arrayref($statement, $options);

    return wantarray ? @{ $return } : $return;
}

################################################################################
sub _apply_filter {
    my($self, $filter, $mode) = @_;

    $compining_prefix = $mode || '';
    $filter_mode      = $mode || 'Filter';
    my( $combining_count, @statements) = &_recurse_cond($filter);
    return wantarray ? @statements: \@statements;
}

################################################################################
sub _recurse_cond {
    my($cond, $combining_count) = @_;
    $combining_count = $combining_count || 0;
    print STDERR "#IN _recurse_cond $cond $combining_count\n" if $TRACE > 9;
    my $method = &_METHOD_FOR_refkind("_cond", $cond);
    my ( $child_combining_count, @statment ) = &{\&$method}($cond,$combining_count);
    $combining_count = $child_combining_count;
    print STDERR "#OUT _recurse_cond $cond $combining_count ( $method )\n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

################################################################################
sub _cond_UNDEF { return ( () ); }

################################################################################
sub _cond_ARRAYREF {
    my($conds, $combining_count) = @_;
    $combining_count = $combining_count || 0;
    print STDERR "#IN _cond_ARRAYREF $conds $combining_count\n" if $TRACE > 9;
    my @statment = ();

    my $child_combining_count = 0;
    my @child_statment = ();
    my @cp_conds = @{ $conds }; # work with a copy
    while ( my $cond = shift @cp_conds ){
        my ( $child_combining_count, @child_statment ) = &_dispatch_refkind($cond, {
            ARRAYREF  => sub { &_recurse_cond($cond, $combining_count) },
            HASHREF   => sub { &_recurse_cond($cond, $combining_count) },
            UNDEF     => sub { croak "not supported : UNDEF in arrayref" },
            SCALAR    => sub { &_recurse_cond( { $cond => shift(@cp_conds) } , $combining_count ) },
        });
        push @statment, @child_statment;
        $combining_count = $child_combining_count;
    }
    print STDERR "#OUT _cond_ARRAYREF $conds $combining_count\n" if $TRACE > 9 ;
    return ( $combining_count, @statment );
}

################################################################################
sub _cond_HASHREF {
    my($cond, $combining_count) = @_;
    $combining_count = $combining_count || 0;
    print STDERR "#IN _cond_HASHREF $cond $combining_count\n" if $TRACE > 9 ;
    my @all_statment = ();
    my $child_combining_count = 0;
    my @child_statment = ();

    foreach my $key ( keys %{ $cond } ){
        my $value = $cond->{$key};
        my $method ;

        if ( $key =~ /^-/mxo ){
            # Child key for combining filters ( -and / -or )
            ( $child_combining_count, @child_statment ) = &_cond_op_in_hash($key, $value, $combining_count);
            $combining_count = $child_combining_count;
        } else{
            $method = &_METHOD_FOR_refkind("_cond_hashpair",$value);
            ( $child_combining_count, @child_statment ) = &{\&$method}($key, $value, undef ,$combining_count);
            $combining_count = $child_combining_count;
        }

        push @all_statment, @child_statment;
    }
    print STDERR "#OUT _cond_HASHREF $cond $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @all_statment );
}

################################################################################
sub _cond_hashpair_UNDEF {
    my $key = shift || '';
    my $value = shift;
    my $operator = shift || '=';
    print STDERR "# _cond_hashpair_UNDEF\n" if $TRACE > 9 ;

    my $combining_count = shift || 0;
    my @statment = (
        sprintf("%s: %s %s",$filter_mode,$key,$operator)
    );
    $combining_count++;
    return ( $combining_count, @statment );
};

################################################################################
sub _cond_hashpair_SCALAR {
    my $key = shift || '';
    my $value = shift;
    my $operator = shift || '=';
    print STDERR "# _cond_hashpair_SCALAR\n" if $TRACE > 9 ;

    my $combining_count = shift || 0;
    my @statment = (
        sprintf("%s: %s %s %s",$filter_mode,$key,$operator,$value)
    );
    $combining_count++;
    return ( $combining_count, @statment );
};

################################################################################
sub _cond_hashpair_ARRAYREF {
    my $key = shift || '';
    my $values = shift || [];
    my $operator = shift || '=';
    my $combining_count = shift || 0;
    print STDERR "#IN _cond_hashpair_ARRAYREF $combining_count\n" if $TRACE > 9;

    my @statment = ();
    foreach my $value ( @{ $values }){
        push @statment, sprintf("%s: %s %s %s",$filter_mode,$key,$operator,$value);
        $combining_count++;
    }
    print STDERR "#OUT _cond_hashpair_ARRAYREF $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

################################################################################
sub _cond_hashpair_HASHREF {
    my $key             = shift || '';
    my $values          = shift || {};
    my $combining       = shift || undef;
    my $combining_count = shift || 0;

    print STDERR "#IN Abstract::_cond_hashpair_HASHREF $combining_count\n" if $TRACE > 9;
    my @statment = ();

    foreach my $child_key ( keys %{ $values } ){
        my $child_value = $values->{ $child_key };

        if ( $child_key =~ /^-/mxo ){
            my ( $child_combining_count, @child_statment ) = &_cond_op_in_hash($child_key, { $key => $child_value } , 0);
            $combining_count += $child_combining_count;
            push @statment, @child_statment;
        } elsif ( $child_key =~ /^[!<>=~]/mxo ){
            # Child key is a operator like:
            # =     equality
            # ~     match regular expression (substring match)
            # =~    equality ignoring case
            # ~~    regular expression ignoring case
            # <     less than
            # >     greater than
            # <=    less or equal
            # >=    greater or equal
            my $method = &_METHOD_FOR_refkind("_cond_hashpair",$child_value);
            my ( $child_combining_count, @child_statment ) = &{\&$method}($key, $child_value,$child_key);
            $combining_count += $child_combining_count;
            push @statment, @child_statment;
        } else {
            my $method = &_METHOD_FOR_refkind("_cond_hashpair",$child_value);
            my ( $child_combining_count, @child_statment ) = &{\&$method}($key, $child_value);
            $combining_count += $child_combining_count;
            push @statment, @child_statment;
        }
    }
    print STDERR "#OUT Abstract::_cond_hashpair_HASHREF $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

################################################################################
sub _cond_op_in_hash {
    my $operator        = shift;
    my $value           = shift;
    my $combining_count = shift;
    print STDERR "#IN  _cond_op_in_hash $operator $value $combining_count\n" if $TRACE > 9;

    if ( defined $operator and $operator =~ /^-/mxo ){
        $operator =~ s/^-//mxo; # remove -
        $operator =~ s/^\s+|\s+$//gmxo; # remove leading/trailing space
        $operator = 'GroupBy' if ( $operator eq 'Groupby' );
    }

    my $operators = [{
        regexp   => qr/(and|or)/mix,
        handler => '_cond_compining',
    }, {
        regexp  => qr/(groupby)/mix,
        handler => '_cond_op_groupby',
    }, {
        regexp  => qr/(sum|min|max|avg|std)/mix,
        handler => '_cond_op_simple'
    }, {
        regexp  => qr/(isa)/mix,
        handler => '_cond_op_isa'
    }];
    my $operator_config = first { $operator =~ $_->{'regexp'} } @{ $operators };
    my $operator_handler = $operator_config->{handler};
    if ( not ref $operator_handler ){
        return &{\&$operator_handler}($operator,$value,$combining_count);
    }elsif ( ref $operator_handler eq 'CODE' ) {
        return $operator_handler->($operator,$value,$combining_count);
    }

    print STDERR "#OUT _cond_op_in_hash $operator $value $combining_count\n" if $TRACE > 9;
    return ( 0, () );
}

################################################################################
sub _cond_compining {
    my $combining = shift;
    my $value = shift;
    my $combining_count = shift || 0;
    print STDERR "#IN _cond_compining $combining $combining_count\n" if $TRACE > 9;
    $combining_count++;
    my @statment = ();

    if ( defined $combining and $combining =~ /^-/mxo ){
        $combining =~ s/^-//mxo; # remove -
        $combining =~ s/^\s+|\s+$//gmxo; # remove leading/trailing space
        $combining = ucfirst( $combining );
    }
    my ( $child_combining_count, @child_statment )= &_recurse_cond($value, 0 );
    push @statment, @child_statment;
    if ( defined $combining ) {
        push @statment, sprintf("%s%s: %d",
            $compining_prefix,
            ucfirst( $combining ),
            $child_combining_count,
        );
    }
    print STDERR "#OUT _cond_compining $combining $combining_count \n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

################################################################################
sub _refkind {
  my ($data) = @_;
  my $suffix = '';
  my $ref;
  my $n_steps = 0;

  while (1) {
    # blessed objects are treated like scalars
    $ref = (blessed $data) ? '' : ref $data;
    $n_steps += 1 if $ref;
    last          if $ref ne 'REF';
    $data = $$data;
  }

  my $base = $ref || (defined $data ? 'SCALAR' : 'UNDEF');

  return $base . ('REF' x $n_steps);
}

################################################################################
sub _dispatch_refkind {
    my $value = shift;
    my $dispatch_table = shift;

    my $type = &_refkind($value);
    my $coderef = $dispatch_table->{$type};

    die sprintf("No coderef for %s ( %s ) found!",$value, $type)
        unless ( ref $coderef eq 'CODE' );

    return $coderef->();
}

################################################################################
sub _METHOD_FOR_refkind {
    my $prefix = shift || '';
    my $value = shift;
    my $type = &_refkind($value);
    my $method = sprintf("%s_%s",$prefix,$type);
    return $method;
}

################################################################################
sub _cond_op_groupby {
    my $operator = shift;
    my $value = shift;
    my $combining_count = shift || 0;

    print STDERR "#IN  _cond_op_groupby $operator $value $combining_count\n" if $TRACE > 9;

    my ( @child_statment ) = &_dispatch_refkind($value, {
        SCALAR  => sub {
            return ( sprintf("%s%s: %s", $compining_prefix, 'GroupBy', $value) );
        },
    });
    print STDERR "#OUT _cond_op_groupby $operator $value $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @child_statment );
}

################################################################################
sub _cond_op_simple {
    my $operator = shift;
    my $value = shift;
    my $combining_count = shift || 0;
    my @child_statment = ();

    print STDERR "#IN  _cond_op_simple $operator $value $combining_count\n" if $TRACE > 9;

    ( $combining_count,@child_statment ) = &_dispatch_refkind($value, {
        SCALAR  => sub {
            return (++$combining_count, sprintf("%s: %s %s",$compining_prefix,$operator,$value) );
        },
    });

    print STDERR "#OUT _cond_op_simple $operator $value $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @child_statment );
}

################################################################################
sub _cond_op_isa {
    my $operator = shift;
    my $value    = shift;
    my $combining_count = shift || 0;
    my $as_name;
    print STDERR "#IN  _cond_op_isa $operator $value $combining_count\n" if $TRACE > 9;

    my ( $child_combining_count, @statment ) = &_dispatch_refkind($value, {
        HASHREF  => sub {
            my @keys = keys %$value;
            if ( scalar @keys != 1 ){
                die "Isa operator doesn't support more then one key.";
            }
            $as_name = shift @keys;
            my @values = values(%$value);
            return &_recurse_cond(shift( @values ), 0 );
        },
    });
    $combining_count += $child_combining_count;

    $statment[ $#statment ] = $statment[$#statment] . " as " . $as_name;

    #print STDERR "#OUT _cond_op_isa $operator $value $combining_count isa key: " . $self->{_isa_key} . "\n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

################################################################################

1;
__END__

=head1 REPOSITORY

    Git: http://github.com/sni/Monitoring-Livestatus-Class-Lite

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

Robert Bohne, C<< <rbo at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Sven Nierlein, 2009-2014, <sven@nierlein.org>

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
