package Monitoring::Config::Object::Command;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Command - Command Object Configuration

=head1 DESCRIPTION

Defaults for command objects

=head1 METHODS

=cut

##########################################################

$Monitoring::Config::Object::Command::Defaults = {
    'name'         => { type => 'STRING', cat => 'Extended' },
    'use'          => { type => 'LIST', link => 'command', cat => 'Basic' },
    'register'     => { type => 'BOOL', cat => 'Extended' },

    'command_name' => { type => 'STRING', cat => 'Basic' },
    'command_line' => { type => 'STRING', cat => 'Basic' },
};

$Monitoring::Config::Object::Command::ShinkenSpecific = {
    'module_type'      => { type => 'STRING', cat => 'Extended' },
    'reactionner_tag'  => { type => 'STRING', cat => 'Extended' },
};
##########################################################

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $coretype = shift;

    if($coretype eq 'any' or $coretype eq 'shinken') {
        for my $key (keys %{$Monitoring::Config::Object::Command::ShinkenSpecific}) {
            $Monitoring::Config::Object::Command::Defaults->{$key} = $Monitoring::Config::Object::Command::ShinkenSpecific->{$key};
        }
    } else {
        for my $key (keys %{$Monitoring::Config::Object::Command::ShinkenSpecific}) {
            delete $Monitoring::Config::Object::Command::Defaults->{$key};
        }
    }

    my $self = {
        'type'        => 'command',
        'primary_key' => 'command_name',
        'default'     => $Monitoring::Config::Object::Command::Defaults,
        'standard'    => [ 'command_name', 'command_line' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
