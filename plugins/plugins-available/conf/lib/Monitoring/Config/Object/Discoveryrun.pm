package Monitoring::Config::Object::Discoveryrun;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Discoveryrun - Shinken discoveryrun Object Configuration

=head1 DESCRIPTION

Defaults for discoveryrun objects

=cut

##########################################################

$Monitoring::Config::Object::Discoveryrun::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'discoveryrun', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    'discoveryrun_name'               => { type => 'STRING', cat => 'Basic' },
    'discoveryrun_command'            => { type => 'COMMAND', 'link' => 'command', cat => 'Basic' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class    = shift || __PACKAGE__;
    my $coretype = shift;

    return unless($coretype eq 'any' or $coretype eq 'shinken');

    my $self = {
        'type'        => 'discoveryrun',
        'primary_key' => 'discoveryrun_name',
        'default'     => $Monitoring::Config::Object::Discoveryrun::Defaults,
        'standard'    => [ 'discoveryrun_name', 'discoveryrun_command' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Mathieu Parent, 2013, <math.parent@gmail.com>
Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
