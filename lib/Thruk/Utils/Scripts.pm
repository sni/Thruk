package Thruk::Utils::Scripts;

=head1 NAME

Thruk::Utils::Scripts - Utilities Collection for Scripts

=head1 DESCRIPTION

Utilities Collection for scripting with Thruk.

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 Methods

=head2 print_errors

    print_errors()

print errors for given file and replace html links to human readable cli output

=cut
sub print_errors {
    my($file) = @_;
    if(scalar @{$file->{'parse_errors'}} > 0) {
        for my $err (@{$file->{'parse_errors'}}) { print_error($err); }
        return 1;
    }
    if(scalar @{$file->{'errors'}} > 0) {
        for my $err (@{$file->{'errors'}}) { print_error($err); }
        return 1;
    }
    return 0;
}

##############################################

=head2 print_error

    print_error()

print single error and replace html links to human readable cli output

=cut
sub print_error {
    my($err) = @_;
    $err =~ s/\ in\ <a\ href.*?>([^<]*)<\/a>/ in $1/gmx;
    print STDERR "ERROR: ", $err, "\n";
    return;
}

##############################################

1;
