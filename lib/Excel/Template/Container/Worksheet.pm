package Excel::Template::Container::Worksheet;

use strict;

BEGIN {
    use vars qw(@ISA);
    @ISA = qw(Excel::Template::Container);

    use Excel::Template::Container;
}

=head2 exit_scope

exit current scope

=cut
sub exit_scope { return $_[1]->active_worksheet(undef); }

=head2 render

render worksheet

=cut
sub render {
    my $self = shift;
    my ($context) = @_;

    my $worksheet = $context->new_worksheet($self);

    my $password = $context->get( $self, 'PROTECT' );
    if ( defined $password ) {
        $worksheet->protect($password);
    }

    $worksheet->keep_leading_zeros(1)
      if $context->mark('keep_leading_zeros');

    if ( $context->get( $self, 'LANDSCAPE' ) && !$self->{PORTRAIT} ) {
        $worksheet->set_landscape;
    } elsif ( $context->get( $self, 'PORTRAIT' ) ) {
        $worksheet->set_portrait;
    }

   
    my $hide_gridlines = $context->get( $self, 'HIDE_GRIDLINES');
    
    if ( defined $hide_gridlines ) {
        $worksheet->hide_gridlines( $hide_gridlines );
    }

    my $autofilter = $context->get( $self, "AUTOFILTER");
    if ( defined $autofilter ) {
        if ($autofilter =~ /^\D/mx) {
            $worksheet->autofilter($autofilter);
        }else{
            $autofilter =~ s/\ //gmx;
            my ($row1, $col1, $row2, $col2) = split(',',$autofilter);
            $worksheet->autofilter($row1, $col1, $row2, $col2);
        }
    }

    return $self->SUPER::render($context);
}

1;
__END__

=head1 NAME

Excel::Template::Container::Worksheet - Excel::Template::Container::Worksheet

=head1 PURPOSE

To provide a new worksheet.

=head1 NODE NAME

WORKSHEET

=head1 INHERITANCE

Excel::Template::Container

=head1 ATTRIBUTES

=over 4

=item * NAME

This is the name of the worksheet to be added.

=item * PROTECT

If the attribute exists, it will mark the worksheet as being protected. Whatever
value is set will be used as the password.

This activates the HIDDEN and LOCKED nodes.

=item * KEEP_LEADING_ZEROS

This will change the behavior of the worksheet to preserve leading zeros.


=item * HIDE_GRIDLINE

his method is used to hide the gridlines on the screen and printed page. 
Gridlines are the lines that divide the cells on a worksheet. Screen and printed gridlines are 
turned on by default in an Excel worksheet. If you have defined your own cell 
borders you may wish to hide the default gridlines.

$worksheet->hide_gridlines();

The following values of $option are valid:

    0 : Don't hide gridlines
    1 : Hide printed gridlines only
    2 : Hide screen and printed gridlines

If you don't supply an argument or use undef the default option is 1, i.e. only the printed gridlines are hidden.

=item * LANDSCAPE

This will set the worksheet's orientation to landscape.

=item * PORTRAIT

This will set the worksheet's orientation to portrait.

While this is the default, it's useful to override the default at times. For
example, in the following situation:

  <workbook landscape="1">
    <worksheet>
      ...
    </worksheet
    <worksheet portrait="1">
      ...
    </worksheet
    <worksheet>
      ...
    </worksheet
  </workbook>

In that example, the first and third worksheets will be landscape (inheriting
it from the workbook node), but the second worksheet will be portrait.

=back

=head1 CHILDREN

None

=head1 EFFECTS

None

=head1 DEPENDENCIES

None

=head1 USAGE

  <worksheet name="My Taxes">
    ... Children here
  </worksheet>

In the above example, the children will be executed in the context of the
"My Taxes" worksheet.

=head1 AUTHOR

Rob Kinyon (rob.kinyon@gmail.com)

=head1 SEE ALSO

ROW, CELL, FORMULA

=cut

