package # Hide from pause
    Monitoring::Livestatus::Class::Base::Abstract;

use Moose;
use Carp;
use List::Util   qw/first/;

our $TRACE = $ENV{'MONITORING_LIVESTATUS_CLASS_TRACE'} || 0;

has 'ctx' => (
    is => 'rw',
    handles => [qw/table_name backend_obj/],
);

has 'mode' => (
    is => 'ro',
    isa => 'Str',
    builder => 'build_mode',
);

sub build_mode { die "build_mode must be implemented in " . ref(shift) };

has 'operators' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    builder => 'build_operators',
);

sub build_operators {
    return [
        {
            regexp   => qr/(and|or)/mix,
            handler => '_cond_compining',
        }
    ]
};

has 'compining_prefix' => (
    is => 'ro',
    isa => 'Str',
    builder => 'build_compining_prefix',
);

sub build_compining_prefix { return ''; };



sub apply {
    my $self = shift;
    my $cond = shift;

    my ( $combining_count, @statments ) = $self->_recurse_cond($cond);

    return wantarray ? @statments : \@statments;
}

sub _recurse_cond {
    my $self = shift;
    my $cond = shift;
    my $combining_count = shift || 0;
    print STDERR "#IN _recurse_cond $cond $combining_count\n" if $TRACE > 9;
    my $method = $self->_METHOD_FOR_refkind("_cond",$cond);
    my ( $child_combining_count, @statment ) = $self->$method($cond,$combining_count);
    $combining_count = $child_combining_count;
    print STDERR "#OUT _recurse_cond $cond $combining_count ( $method )\n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

sub _cond_UNDEF { return ( () ); }

sub _cond_ARRAYREF {
    my $self = shift;
    my $conds = shift;
    my $combining_count = shift || 0;
    print STDERR "#IN _cond_ARRAYREF $conds $combining_count\n" if $TRACE > 9;
    my @statment = ();

    my $child_combining_count = 0;
    my @child_statment = ();
    my @cp_conds = @{ $conds }; # work with a copy
    while ( my $cond = shift @cp_conds ){
        my ( $child_combining_count, @child_statment ) = $self->_dispatch_refkind($cond, {
            ARRAYREF  => sub { $self->_recurse_cond($cond, $combining_count) },
            HASHREF   => sub { $self->_recurse_cond($cond, $combining_count) },
            UNDEF     => sub { croak "not supported : UNDEF in arrayref" },
            SCALAR    => sub { $self->_recurse_cond( { $cond => shift(@cp_conds) } , $combining_count ) },
        });
        push @statment, @child_statment;
        $combining_count = $child_combining_count;
    }
    print STDERR "#OUT _cond_ARRAYREF $conds $combining_count\n" if $TRACE > 9 ;
    return ( $combining_count, @statment );
}

sub _cond_HASHREF {
    my $self = shift;
    my $cond = shift;
    my $combining_count = shift || 0;
    print STDERR "#IN _cond_HASHREF $cond $combining_count\n" if $TRACE > 9 ;

    my @all_statment = ();
    my $child_combining_count = 0;
    my @child_statment = ();

    foreach my $key ( keys %{ $cond } ){
        my $value = $cond->{$key};
        my $method ;

        if ( $key =~ /^-/mx ){
            # Child key for combining filters ( -and / -or )
            ( $child_combining_count, @child_statment ) = $self->_cond_op_in_hash($key, $value, $combining_count);
            $combining_count = $child_combining_count;
        } else{
            $method = $self->_METHOD_FOR_refkind("_cond_hashpair",$value);
            ( $child_combining_count, @child_statment ) = $self->$method($key, $value, undef ,$combining_count);
            $combining_count = $child_combining_count;
        }

        push @all_statment, @child_statment;
    }
    print STDERR "#OUT _cond_HASHREF $cond $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @all_statment );
}

sub _cond_hashpair_UNDEF {
    my $self     = shift;
    my $key      = shift || '';
    my $value    = shift;
    my $operator = shift || '=';
    print STDERR "# _cond_hashpair_SCALAR\n" if $TRACE > 9 ;

    my $combining_count = shift || 0;
    my @statment = (
        sprintf("%s: %s %s",$self->mode,$key,$operator)
    );
    $combining_count++;
    return ( $combining_count, @statment );
};

sub _cond_hashpair_SCALAR {
    my $self     = shift;
    my $key      = shift || '';
    my $value    = shift;
    my $operator = shift || '=';
    print STDERR "# _cond_hashpair_SCALAR\n" if $TRACE > 9 ;

    my $combining_count = shift || 0;
    my @statment = (
        sprintf("%s: %s %s %s",$self->mode,$key,$operator,$value)
    );
    $combining_count++;
    return ( $combining_count, @statment );
};

sub _cond_hashpair_ARRAYREF {
    my $self            = shift;
    my $key             = shift || '';
    my $values          = shift || [];
    my $operator        = shift || '=';
    my $combining_count = shift || 0;
    print STDERR "#IN _cond_hashpair_ARRAYREF $combining_count\n" if $TRACE > 9;

    my @statment = ();
    foreach my $value ( @{ $values }){
        push @statment, sprintf("%s: %s %s %s",$self->mode,$key,$operator,$value);
        $combining_count++;
    }
    print STDERR "#OUT _cond_hashpair_ARRAYREF $combining_count\n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

sub _cond_hashpair_HASHREF {
    my $self            = shift;
    my $key             = shift || '';
    my $values          = shift || {};
    my $combining       = shift || undef;
    my $combining_count = shift || 0;

    print STDERR "# _cond_hashpair_HASHREF $combining_count\n" if $TRACE > 9;

    my @statment = ();

    foreach my $child_key ( keys %{ $values } ){
        my $child_value = $values->{ $child_key };

        if ( $child_key =~ /^-/mx ){
            # Child key for combining filters ( -and / -or )
            my ( $child_combining_count, @child_statment ) = $self->_dispatch_refkind($child_value, {
                ARRAYREF  => sub { $self->_cond_op_in_hash($child_key, { $key => $child_value } , 0) },
                UNDEF     => sub { croak "not supported : UNDEF in arrayref" },
            });
            $combining_count += $child_combining_count;
            push @statment, @child_statment;
        } elsif ( $child_key =~ /^[!<>=~]/mx ){
            # Child key is a operator like:
            # =     equality
            # ~     match regular expression (substring match)
            # =~    equality ignoring case
            # ~~    regular expression ignoring case
            # <     less than
            # >     greater than
            # <=    less or equal
            # >=    greater or equal
            my $method = $self->_METHOD_FOR_refkind("_cond_hashpair",$child_value);
            my ( $child_combining_count, @child_statment ) = $self->$method($key, $child_value,$child_key);
            $combining_count += $child_combining_count;
            push @statment, @child_statment;
        } else {
            my $method = $self->_METHOD_FOR_refkind("_cond_hashpair",$child_value);
            my ( $child_combining_count, @child_statment ) = $self->$method($key, $child_value);
            $combining_count += $child_combining_count;
            push @statment, @child_statment;
        }
    }

    return ( $combining_count, @statment );
}

sub _cond_op_in_hash {
    my $self            = shift;
    my $operator        = shift;
    my $value           = shift;
    my $combining_count = shift;
    print STDERR "#IN  _cond_op_in_hash $operator $value $combining_count\n" if $TRACE > 9;

    if ( defined $operator and $operator =~ /^-/mx ){
        $operator =~ s/^-//mx;         # remove -
        $operator =~ s/^\s+|\s+$//mxg; # remove leading/trailing space
        $operator = ucfirst( $operator );
        $operator = 'GroupBy' if ( $operator eq 'Groupby' );
        $operator = $self->compining_prefix.$operator;
    }

    my $operator_config = first { $operator =~ $_->{regexp} } @{ $self->operators };
    my $operator_handler = $operator_config->{handler};
    if ( not ref $operator_handler ){
        return $self->$operator_handler($operator,$value,$combining_count);
    }elsif ( ref $operator_handler eq 'CODE' ) {
        return $operator_handler->($self,$operator,$value,$combining_count);
    }

    print STDERR "#OUT _cond_op_in_hash $operator $value $combining_count\n" if $TRACE > 9;
    return ( 0, () );
}
sub _cond_compining {
    my $self = shift;
    my $combining = shift;
    my $value = shift;
    my $combining_count = shift || 0;
    print STDERR "#IN _cond_compining $combining $combining_count\n" if $TRACE > 9;
    $combining_count++;
    my @statment = ();

    if ( defined $combining and $combining =~ /^-/mx ){
        $combining =~ s/^-//mx;         # remove -
        $combining =~ s/^\s+|\s+$//mxg; # remove leading/trailing space
        $combining = ucfirst( $combining );
    }
    my ( $child_combining_count, @child_statment )= $self->_recurse_cond($value, 0 );
    push @statment, @child_statment;
    push @statment, sprintf("%s: %d",$combining,$child_combining_count) if ( defined $combining );
    print STDERR "#OUT _cond_compining $combining $combining_count \n" if $TRACE > 9;
    return ( $combining_count, @statment );
}

sub _refkind {
  my ($self, $data) = @_;
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

sub _dispatch_refkind {
    my $self = shift;
    my $value = shift;
    my $dispatch_table = shift;

    my $type = $self->_refkind($value);
    my $coderef = $dispatch_table->{$type};
    die sprintf("No coderef for %s ( %s ) found!",$value, $type)
        unless ( ref $coderef eq 'CODE' );
    return $coderef->();
}

sub _METHOD_FOR_refkind {
    my $self = shift;
    my $prefix = shift || '';
    my $value = shift;
    my $type = $self->_refkind( $value );
    my $method = sprintf("%s_%s",$prefix,$type);
    return $method;
}



1;
__END__
=head1 NAME

Monitoring::Livestatus::Class::Base::Abstract - Base class to generate
livestatus statments

=head2 SYNOPSIS

=head1 ATTRIBUTES

=head2 ctx

Reference to context object L<Monitoring::Livestatus::Class>

=head2 mode

=head2 compining_prefix

=head1 METHODS

=head2 apply

Example usage:

    my $filter_obj         = Monitoring::Livestatus::Class::Abstract::...->new();
    $filter_obj->apply( { name => 'localhost' } );
    $filter_obj->apply( { name => [ 'localhost', 'gateway' ] } );
    $filter_obj->apply( [ { name => 'localhost' }, { name => 'gateway' } ] );

Returns: @statments|\@statments

=head1 INTERNAL METHODS

=over 4

=item build_mode

=item build_compining_prefix

=item build_operators

=item _execute

=item _recurse_cond

=item _cond_UNDEF

=item _cond_ARRAYREF

=item _cond_HASHREF

=item _cond_hashpair_SCALAR

=item _cond_hashpair_ARRAYREF

=item _cond_hashpair_HASHREF

=item _refkind

=item _dispatch_refkind

=item _METHOD_FOR_refkind

=back

=head1 AUTHOR

See L<Monitoring::Livestatus::Class/AUTHOR> and L<Monitoring::Livestatus::Class/CONTRIBUTORS>.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Bohne.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
