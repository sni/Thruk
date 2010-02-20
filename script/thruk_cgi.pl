#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    use FindBin;
    if(-e "$FindBin::Bin/../local-lib") {
        use lib "$FindBin::Bin/../local-lib/lib/perl5";
        require local::lib; local::lib->import("$FindBin::Bin/../local-lib/perl5/");
    }
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Thruk', 'CGI');

1;

=head1 NAME

thruk_cgi.pl - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as a cgi script.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
