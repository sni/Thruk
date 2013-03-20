package Thruk::Utils::CleanINC;

=head1 NAME

Thruk::Utils::CleanINC - clean @INC from multiple paths and nonexistand folders

=head1 DESCRIPTION

clean @INC from multiple paths and nonexistand folders

=cut

use strict;
use warnings;
use Cwd 'abs_path';

BEGIN {
    my %seen = ();
    my @new  = ();
    foreach my $p (@INC) {
        $p = abs_path($p);
        unless ($seen{$p}) {
            $seen{$p} = 1;
            next if !-d $p.'/.';
            push @new, $p;
        }
    }
    @INC = @new;
}

1;

=head1 AUTHOR

Sven Nierlein, 2013, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
