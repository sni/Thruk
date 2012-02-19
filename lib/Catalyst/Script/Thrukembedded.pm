package Catalyst::Script::Thrukembedded;
use Moose;
BEGIN { $ENV{CATALYST_ENGINE} ||= 'Thrukembedded' }
use namespace::autoclean;

with 'Catalyst::ScriptRole';

__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::Script::Thrukembedded - The Thrukembedded Catalyst Script

=head1 SYNOPSIS

  thruk.pl [options]

  Options:
  -?     --help           display this help and exits

=head1 DESCRIPTION

This is a script to run the Catalyst engine specialized for the Thrukembedded environment.

=head1 AUTHORS

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
