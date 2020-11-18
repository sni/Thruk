package Thruk::Base;

=head1 NAME

Thruk::Base - basic helpers without dependencies

=head1 DESCRIPTION

basic helpers without dependencies

=cut

use strict;
use warnings;
use Carp qw/confess/;

use Exporter 'import';
our @EXPORT_OK = qw(mode verbose quiet debug trace config);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

###################################################

=head1 METHODS

=head2 config

    config()

returns current configuration

=cut
sub config {
    my $config = $Thruk::Config::config;
    confess("uninitialized, no global config") unless $config;
    return($config);
}

###################################################

=head2 mode

    mode()

returns thruk runtime mode

=cut
sub mode {
    return($ENV{'THRUK_MODE'} // "CLI");
}

###################################################

=head2 verbose

    verbose()

returns verbosity level

=cut
sub verbose {
    return($ENV{'THRUK_VERBOSE'} // 0);
}

###################################################

=head2 debug

    debug()

returns true if debug mode is enabled

=cut
sub debug {
    return(&verbose > 1);
}

###################################################

=head2 trace

    trace()

returns true if trace mode is enabled

=cut
sub trace {
    return(&verbose >= 4);
}

###################################################

=head2 quiet

    quiet()

returns true if quiet mode is enabled

=cut
sub quiet {
    return($ENV{'THRUK_QUIET'} // 0);
}

###################################################

=head1 SEE ALSO

L<Thruk>, L<Thruk::Config>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

Thruk is Copyright (c) 2009-2019 by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself.

=cut

1;
