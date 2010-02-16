#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    use FindBin;
    if(-e "$FindBin::Bin/../local-lib") {
        use lib "$FindBin::Bin/../local-lib/lib/perl5";
        require local::lib; local::lib->import("$FindBin::Bin/local-lib");
    }
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Thruk', 'Test');

1;

=head1 NAME

thruk_test.pl - Catalyst Test

=head1 SYNOPSIS

thruk_test.pl [options] uri

 Options:
   --help    display this help and exits

 Examples:
   thruk_test.pl http://localhost/some_action
   thruk_test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the command line.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
