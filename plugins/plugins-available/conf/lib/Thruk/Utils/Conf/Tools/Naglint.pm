package Thruk::Utils::Conf::Tools::Naglint;

use strict;
use warnings;
use Thruk::Utils::Conf;

=head1 NAME

Thruk::Utils::Conf::Tools::Naglint.pm - Tool to standarize object configs attribute order and whitespace

=head1 DESCRIPTION

Tool to standarize object configs attribute order and whitespace

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category    => 'Cleanup',
        link        => 'Naglint',
        title       => 'Beautify Object Configs',
        description => 'Corrects whitspace and indention level, attribute order, etc',
        fixlink     => 'beautify',
    };
    bless($self, $class);
    return($self);
}

##########################################################

=head2 get_list($c, $ignores)

returns list of potential objects to cleanup

=cut
sub get_list {
    my($self, $c, $ignores) = @_;

    my $result     = [];
    my $files_root = $c->{'obj_db'}->get_files_root();
    for my $file (@{$c->{'obj_db'}->get_files()}) {
        next if $file->{'readonly'}; # keep them untouched
        next if $file->{'changed'};  # will be linted anyway
        next if !-e $file->{'path'};
        my $name     = $file->{'display'};
        $name        =~ s|^\Q$files_root\E||gmx;
        $file->{'changed'} = 1;
        my $diff     = $file->diff();
        $file->{'changed'} = 0;
        if($diff ne '') {
            push @{$result}, {
                ident      => $file->{'path'},
                id         => '',
                name       => $name,
                type       => 'file',
                obj        => '',
                message    => 'file could be beautified.',
                cleanable  => 1,
                file       => $file,
            };
        }
    }
    return(Thruk::Utils::Conf::clean_from_tool_ignores($result, $ignores));
}

##########################################################

=head2 cleanup

cleanup this object

=cut
sub cleanup {
    my($self, $c, $ident, $ignores) = @_;
    my $list = $self->get_list($c, $ignores);
    for my $data (@{$list}) {
        if($ident eq 'all' || $data->{'ident'} eq $ident) {
            $data->{'file'}->{'changed'} = 1;
        }
    }
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
