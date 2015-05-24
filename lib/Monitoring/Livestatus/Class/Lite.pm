package Monitoring::Livestatus::Class::Lite;

=head1 NAME

Monitoring::Livestatus::Class::Lite - Object-Oriented interface for
Monitoring::Livestatus

=head1 DESCRIPTION

This module is an object-oriented interface for Monitoring::Livestatus.
Just like Monitoring::Livestatus::Class but without Moose.

=head1 SYNOPSIS

    use Monitoring::Livestatus::Class::Lite;

    my $class = Monitoring::Livestatus::Class::Lite->new({
        peer => '/var/lib/nagios3/rw/livestatus.sock'
    });

    my $hosts = $class->table('hosts');
    my @data = $hosts->columns('display_name')->filter(
        { display_name => { '-or' => [qw/test_host_47 test_router_3/] } }
    )->hashref_array();

    use Data::Dumper;
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
use Carp qw/croak confess/;
use Monitoring::Livestatus ();

our $VERSION = '0.05';

our $compining_prefix = '';
our $filter_mode      = '';
our $filter_cache     = {};
my $operators         = {
    'and'       => '_cond_compining',
    'or'        => '_cond_compining',
    'groupby'   => '_cond_op_groupby',
    'sum'       => '_cond_op_simple',
    'min'       => '_cond_op_simple',
    'max'       => '_cond_op_simple',
    'avg'       => '_cond_op_simple',
    'std'       => '_cond_op_simple',
    'isa'       => '_cond_op_isa',
};

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

    return([$self->statement(), $self->{_columns}, $self->{_options}]) if $ENV{'THRUK_SELECT'};

    my %indexed;
    my @data = $self->hashref_array();
    confess('undefined index: '.$key) if(defined $data[0] && !defined $data[0]->{$key});
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
    return([$self->statement(), $self->{_columns}, $self->{_options}]) if $ENV{'THRUK_SELECT'};
    my @data = $self->_execute();
    return wantarray ? @data : \@data;
}

################################################################################

=head2 reset_filter

    reset_filter()

removes all current filter

=cut
sub reset_filter {
    my($self) = @_;
    $self->{'_filter'}      = undef;
    $self->{'_statsfilter'} = undef;
    return($self);
}

################################################################################

=head2 save_filter

    save_filter($name)

save this filter with given name which can be reused later.

=cut
sub save_filter {
    my($self, $name) = @_;
    $filter_cache->{$name} = $self->statement(1);
    return($self);
}

################################################################################

=head2 apply_filter

    apply_filter($name)

returns true if a filter with this name has been applied. returns false if filter
does not exist.

=cut
sub apply_filter {
    my($self, $name) = @_;
    return unless $filter_cache->{$name};
    $self->{'_extra_stm'} = $filter_cache->{$name};
    $self->{'_columns'}   = undef;
    return($self);
}

################################################################################

=head2 statement

    statement($filter_only)

return query as text.

=cut
sub statement {
    my($self, $filter_only) = @_;

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
    if( $self->{'_extra_stm'} ) {
        push @statements, @{$self->{'_extra_stm'}};
    }
    return(\@statements) if $filter_only;

    unshift @statements, sprintf("GET %s", $self->{'_table'});

    printf STDERR "EXEC: %s\n", join("\nEXEC: ",@statements) if $ENV{'MONITORING_LIVESTATUS_CLASS_TRACE'};

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
    #my( $combining_count, @statements)...
    my( undef, @statements) = &_recurse_cond($filter);
    return wantarray ? @statements: \@statements;
}

################################################################################
sub _recurse_cond {
    my($cond, $combining_count) = @_;
    $combining_count = 0 unless defined $combining_count;
    my $method = '_cond_'.&_refkind($cond);
    my($child_combining_count, @statement) = &{\&{$method}}($cond,$combining_count);
    $combining_count = $child_combining_count;
    return ( $combining_count, @statement );
}

################################################################################
sub _cond_UNDEF { return ( () ); }

################################################################################
sub _cond_ARRAYREF {
    my($conds, $combining_count) = @_;
    $combining_count = $combining_count || 0;
    my @statement = ();

    my @cp_conds = @{ $conds }; # work with a copy
    while(my $cond = shift @cp_conds) {
        my($child_combining_count, @child_statement) = &_dispatch_refkind($cond, {
            ARRAYREF  => sub { &_recurse_cond($cond, $combining_count) },
            HASHREF   => sub { &_recurse_cond($cond, $combining_count) },
            UNDEF     => sub { croak "not supported : UNDEF in arrayref" },
            SCALAR    => sub { &_recurse_cond( { $cond => shift(@cp_conds) } , $combining_count ) },
        });
        push @statement, @child_statement;
        $combining_count = $child_combining_count;
    }
    return($combining_count, @statement);
}

################################################################################
sub _cond_HASHREF {
    my($cond, $combining_count) = @_;
    $combining_count          = 0 unless $combining_count;
    my $child_combining_count = 0;
    my @all_statement;
    my @child_statement;

    while(my($key, $value) = each %{$cond}) {
        if(substr($key,0,1) eq '-'){
            # Child key for combining filters ( -and / -or )
            ($child_combining_count, @child_statement) = &_cond_op_in_hash($key, $value, $combining_count);
            $combining_count = $child_combining_count;
        } else {
            my $method = '_cond_hashpair_'.&_refkind($value);
            ($child_combining_count, @child_statement) = &{\&{$method}}($key, $value, undef ,$combining_count);
            $combining_count = $child_combining_count;
        }

        push @all_statement, @child_statement;
    }
    return($combining_count, @all_statement);
}

################################################################################
sub _cond_hashpair_UNDEF {
    #my($key, $value, $operator, $combining_count)...
    my($key, undef, $operator, $combining_count) = @_;
    $combining_count = 0 unless $combining_count;
    $key      = '' unless $key;
    $operator = '=' unless $operator;

    my @statement = (sprintf("%s: %s %s",$filter_mode,$key,$operator));
    $combining_count++;
    return ( $combining_count, @statement );
}

################################################################################
sub _cond_hashpair_SCALAR {
    my($key, $value, $operator, $combining_count) = @_;
    $combining_count = 0 unless $combining_count;
    my @statement = (sprintf("%s: %s %s %s",
                                $filter_mode,
                                ($key || '') ,
                                ($operator || '='),
                                $value),
    );
    $combining_count++;
    return ( $combining_count, @statement );
}

################################################################################
sub _cond_hashpair_ARRAYREF {
    my $key = shift || '';
    my $values = shift || [];
    my $operator = shift || '=';
    my $combining_count = shift || 0;

    my @statement = ();
    foreach my $value ( @{ $values }){
        push @statement, sprintf("%s: %s %s %s",$filter_mode,$key,$operator,$value);
        $combining_count++;
    }
    return ( $combining_count, @statement );
}

################################################################################
sub _cond_hashpair_HASHREF {
    #my($key, $values, $combining, $combining_count)...
    my($key, $values, undef, $combining_count) = @_;
    $key             = '' unless $key;
    $values          = {} unless $values;
    $combining_count = 0 unless $combining_count;

    my @statement = ();

    foreach my $child_key ( keys %{ $values } ){
        my $child_value = $values->{ $child_key };

        if ( $child_key =~ /^-/mxo ){
            my ( $child_combining_count, @child_statement ) = &_cond_op_in_hash($child_key, { $key => $child_value } , 0);
            $combining_count += $child_combining_count;
            push @statement, @child_statement;
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
            my $method = '_cond_hashpair_'.&_refkind($child_value);
            my($child_combining_count, @child_statement) = &{\&{$method}}($key, $child_value,$child_key);
            $combining_count += $child_combining_count;
            push @statement, @child_statement;
        } else {
            my $method = '_cond_hashpair_'.&_refkind($child_value);
            my ( $child_combining_count, @child_statement ) = &{\&{$method}}($key, $child_value);
            $combining_count += $child_combining_count;
            push @statement, @child_statement;
        }
    }
    return ( $combining_count, @statement );
}

################################################################################
sub _cond_op_in_hash {
    my($operator, $value, $combining_count) = @_;

    if ($operator && substr($operator,0,1) eq '-'){
        $operator = substr($operator, 1); # remove -
        $operator =~ s/\s+$//gmxo;        # remove trailing space
    }

    my $operator_handler = $operators->{lc $operator};
    return &{\&{$operator_handler}}($operator,$value,$combining_count);
}

################################################################################
sub _cond_compining {
    my $combining = shift;
    my $value = shift;
    my $combining_count = shift || 0;
    $combining_count++;
    my @statement = ();

    if ($combining && substr($combining,0,1) eq '-'){
        $combining = substr($combining, 1); # remove -
        $combining =~ s/\s+$//gmxo;         # remove trailing space
    }
    my($child_combining_count, @child_statement) = &_recurse_cond($value, 0);
    push @statement, @child_statement;
    if(defined $combining and $child_combining_count > 1) {
        push @statement, sprintf("%s%s: %d",
            $compining_prefix,
            ucfirst( $combining ),
            $child_combining_count,
        );
    }
    return ( $combining_count, @statement );
}

################################################################################
sub _refkind {
  my $ref = ref $_[0];
  return(uc($ref).'REF') if $ref;
  return('UNDEF') if !defined $_[0];
  return('SCALAR');
}

################################################################################
sub _dispatch_refkind {
    my($value, $dispatch_table) = @_;

    my $type    = &_refkind($value);
    my $coderef = $dispatch_table->{$type} ||
        die(sprintf("No coderef for %s ( %s ) found!",$value, $type));

    return $coderef->();
}

################################################################################
sub _cond_op_groupby {
    #my($operator, $value, $combining_count) = @_;
    $_[2] = 0 unless defined $_[2];
    return(++$_[2], (sprintf("%s%s: %s", $compining_prefix, 'GroupBy', $_[1])));
}

################################################################################
sub _cond_op_simple {
    my($operator, $value, $combining_count) = @_;
    $combining_count = 0 unless defined $combining_count;
    return(++$combining_count, (sprintf("%s: %s %s",$compining_prefix,$operator,$value)));
}

################################################################################
sub _cond_op_isa {
    #my($operator, $value, $combining_count) = @_;
    my(undef, $value, $combining_count) = @_;
    $combining_count = 0 unless defined $combining_count;

    my @keys = keys %{$value};
    if(scalar @keys != 1) {
        die "Isa operator doesn't support more then one key.";
    }
    my $as_name = shift @keys;
    my @values  = values(%{$value});
    my($child_combining_count, @statement) = &_recurse_cond(shift( @values ), 0);

    $combining_count += $child_combining_count;

    # append alias to last operator
    $statement[-1] .= " as ".$as_name;

    return($combining_count, @statement);
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
