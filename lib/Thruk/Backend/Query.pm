package Thruk::Backend::Query;

use strict;
use warnings;
use Carp;

our $AUTOLOAD;

=head1 NAME

Thruk::Backend::Query - send queries to our backends

=head1 DESCRIPTION

send queries to our backends

=head1 METHODS

=cut

##########################################################

=head2 new

create new manager

=cut
##########################################################
sub new {
    my( $class, %options ) = @_;
    my $self = {
            'stats'    => undef,
            'log'      => undef,
            'backends' => [],
    };
    bless $self, $class;

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    return $self;
}

##########################################################

=head2 query

create new manager

=cut
sub query {
    my $self   = shift;
    my $query  = shift;

    confess "no query" unless defined $query;

    return;
}

##########################################################

=head2 AUTOLOAD

  AUTOLOAD()

redirects sub calls to out backends

=cut
sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
        or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://mx;   # strip fully-qualified portion

    #my $arg;
    #if($name =~ /^select/mx) {
    #    $arg = substr($_[0], 0, 50);
    #    $arg =~ s/\n+/\\n/gmx;
    #    $self->{'log'}->debug("livestatus->".$name."(".$arg."...)");
    #    $arg = substr($arg, 0, 20);
    #    $self->{'stats'}->profile(begin => "l->".$name."(".$arg."...)");
    #}

    my $result;
    #my @arg = @_ || [];
    #$result = $self->{'backends'}->[0]->$name(@_);
    if (@_) {
        $result = $self->{'backends'}->{'backends'}->[0]->{'class'}->$name(@_);
    } else {
        $result = $self->{'backends'}->{'backends'}->[0]->{'class'}->$name();
    }

    #if($name =~ /^select/mx) {
    #    $self->{'stats'}->profile(end => "l->".$name."(".$arg."...)");
    #}

    return $result;
}

##########################################################

=head2 DESTROY

  DESTROY()

destroy this

=cut
sub DESTROY {
};

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
