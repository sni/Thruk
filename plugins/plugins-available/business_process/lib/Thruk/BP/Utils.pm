package Thruk::BP::Utils;

use strict;
use warnings;
use Thruk::BP::Components::BP;

use Carp;
use Config::General;

=head1 NAME

Thruk::BP::Utils - Helper for the business process addon

=head1 DESCRIPTION

Helper for the business process addon

=head1 METHODS

=cut

##########################################################

=head2 load_bp_data

    load_bp_data($c, [$num])

load all or specific business process

=cut
sub load_bp_data {
    my($c, $num) = @_;
    my $bps   = [];
    my $pattern = '*.tbp';
    if($num) {
        return($bps) unless $num =~ m/^\d+$/mx;
        $pattern = $num.'.tbp';
    }
    my @files = glob($c->config->{'var_path'}.'/bp/'.$pattern);
    for my $file (@files) {
        my $bp = Thruk::BP::Components::BP->new($file);
        push @{$bps}, $bp if $bp;
    }

    #update_bp_status($c, $bps);
    return($bps);
}

##########################################################

=head2 update_bp_status

    update_bp_status($c, $bps)

update status of all given business processes

=cut
sub update_bp_status {
    my($c, $bps) = @_;
    for my $bp (@{$bps}) {
        $bp->update_status($c);
    }
    return;
}

##########################################################

=head2 clean_function_args

    clean_function_args($args)

return clean args from a string

=cut
sub clean_function_args {
    my($args) = @_;
    return([]) unless defined $args;
    my @newargs = $args =~ m/('.*?'|".*?"|\d+)/gmx;
    for my $arg (@newargs) {
        $arg =~ s/^'(.*)'$/$1/mx;
        $arg =~ s/^"(.*)"$/$1/mx;
        if($arg =~ m/^(\d+|\d+.\d+)$/mx) {
            $arg = $arg + 0; # make it a real number
        }
    }
    return(\@newargs);
}

##########################################################

=head2 join_labels

    join_labels($nodes)

return string with joined labels

=cut
sub join_labels {
    my($nodes) = @_;
    my @labels;
    for my $n (@{$nodes}) {
        push @labels, $n->{'label'};
    }
    my $num = scalar @labels;
    if($num == 1) {
        return($labels[0]);
    }
    if($num == 2) {
        return($labels[0].' and '.$labels[1]);
    }
    my $last = pop @labels;
    return(join(', ', @labels).' and '.$last);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
