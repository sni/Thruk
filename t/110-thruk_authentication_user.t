#!/usr/bin/env perl

package FakeContext;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;

    return bless({ user => $args{user}, roles => $args{roles}}, $class);
}

sub config {
    my $this = shift;

    return {
        cgi_cfg  => { map({ $_ => $this->{user} } @{$this->{roles}}) },
        var_path => ".",
    };
}

sub env {
    return {};
}

sub req {
    return $_[0];
}

sub header {
    return '';
}

sub stash {
    return {};
}

package main;

use warnings;
use strict;
use utf8;
use Test::More;
use Thruk::Utils;

BEGIN {
    plan tests => 4;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk');
use_ok('Thruk::Authentication::User');

# Admin user with ro sprinkled in
my $admin = Thruk::Authentication::User->new(
    FakeContext->new(
        user => 'admin',
        roles => [qw/
                    authorized_for_configuration_information
                    authorized_for_system_commands
                    authorized_for_read_only
                /],
    ),
    'admin'
);

is(grep({ $_ eq 'authorized_for_read_only' } @{$admin->{roles}}), 0, 'ro removed from admin');

# Non-admin with ro sprinkled id
my $nonadmin = Thruk::Authentication::User->new(
    FakeContext->new(
        user => 'nonadmin',
        roles => [qw/
                    authorized_for_system_commands
                    authorized_for_read_only
                /],
    ),
    'nonadmin'
);

is(grep({ $_ eq 'authorized_for_read_only' } @{$nonadmin->{roles}}), 1, 'ro in nonadmin');
