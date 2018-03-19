package Thruk::Template::Exception;
use base qw(Template::Exception);

use strict;
use warnings;
## no critic
no warnings 'redefine';
## use critic
use Carp;

sub Template::Exception::new {
    my ($class, $type, $info, $textref) = @_;
    $info .= Carp::longmess();
    return(bless([ $type, $info, $textref ], $class));
}

=head1 NAME

Thruk::Template::Exception - Exception handling including stacktrace

=head1 DESCRIPTION

Appends stacktrace to Template Toolkit exceptions

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 METHODS

=cut

1;
