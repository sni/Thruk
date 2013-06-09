package Catalyst::Plugin::Thruk::RemoveNastyCharsFromHttpParam;
use parent 'Class::Data::Inheritable';

use strict;

use Carp;

our $VERSION = 1.0;

# Note we have to hook here as uploads also add to the request parameters
sub prepare_uploads {
    my $c = shift;

    $c->next::method(@_);

    my $enc = $c->encoding;

    for my $key ( keys %{ $c->request->{'parameters'} } ) {
        next if $key eq 'data';
        next if $key eq 'referer';
        next if $key eq 'selected_hosts';
        next if $key eq 'selected_services';
        next if $key eq 'service';
        next if $key eq 'pattern';
        next if $key eq 'exclude_pattern';
        next if $key eq 'conf_comment';
        next if $key eq 'content';
        next if $key eq 'filter';
        next if $key eq 'performance_data';
        next if $key eq 'password';
        next if $key =~ /^s\d+_op/mx;
        next if $key =~ /^s\d+_value/mx;
        next if $key =~ /^\w{3}_s\d+_value/mx;
        next if $key =~ /^\w{3}_s\d+_op/mx;
        next if $key =~ /^data\./mx;
        next if $key =~ /^obj\./mx;
        my $value = $c->request->{'parameters'}->{$key};
        if ( ref $value && ref $value ne 'ARRAY' ) {
            next;
        }
        for ( ref($value) ? @{$c->request->{'parameters'}->{$key}} : $c->request->{'parameters'}->{$key} ) {
            $_ =~ s/[;\|<>]+//gmx if defined $_;
        }
    }
    return;
}

1;

__END__

=head1 NAME

Catalyst::Plugin::Thruk::RemoveNastyCharsFromHttpParam - Remove some chars from variables

=head1 SYNOPSIS

    use Catalyst qw[Thruk::RemoveNastyCharsFromHttpParam];


=head1 DESCRIPTION

On request, remove some chars from all params.

=head1 OVERLOADED METHODS

=over

=item prepare_uploads

Remove some nasty characters from all input parameters

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHORS

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut
