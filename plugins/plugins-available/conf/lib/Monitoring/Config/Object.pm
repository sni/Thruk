package Monitoring::Config::Object;

use strict;
use warnings;
use Storable qw(dclone);
use Monitoring::Config::Object::Host;
use Monitoring::Config::Object::Hostgroup;
use Monitoring::Config::Object::Hostextinfo;
use Monitoring::Config::Object::Hostdependency;
use Monitoring::Config::Object::Hostescalation;
use Monitoring::Config::Object::Service;
use Monitoring::Config::Object::Servicegroup;
use Monitoring::Config::Object::Serviceextinfo;
use Monitoring::Config::Object::Servicedependency;
use Monitoring::Config::Object::Serviceescalation;
use Monitoring::Config::Object::Command;
use Monitoring::Config::Object::Timeperiod;
use Monitoring::Config::Object::Contact;
use Monitoring::Config::Object::Contactgroup;

=head1 NAME

Monitoring::Conf::Object - Object Prototype

=head1 DESCRIPTION

Single object creator

=head1 METHODS

=cut

$Monitoring::Config::Object::Types = [
    'host',
    'hostgroup',
    'hostextinfo',
    'hostdependency',
    'hostescalation',
    'service',
    'servicegroup',
    'serviceextinfo',
    'servicedependency',
    'serviceescalation',
    'command',
    'timeperiod',
    'contact',
    'contactgroup',
];

##########################################################

=head2 new

return a new object of given type

=cut
sub new {
    my $class = shift;
    my $conf  = {@_};

    my $obj = \&{"Monitoring::Config::Object::".ucfirst($conf->{'type'})."::new"};
    return unless defined &$obj;
    my $current_object = &$obj();

    $current_object->{'conf'}     = dclone( $conf->{'conf'} || {} );
    $current_object->{'line'}     = $conf->{'line'} || 0;
    $current_object->{'file'}     = $conf->{'file'} if defined $conf->{'file'};
    $current_object->{'comments'} = [];
    $current_object->{'id'}       = 'new';

    if(defined $conf->{'name'}) {
        if(ref $current_object->{'primary_key'} eq 'ARRAY') {
            $current_object->{'conf'}->{$current_object->{'primary_key'}->[0]} = $conf->{'name'};
        } else {
            $current_object->{'conf'}->{$current_object->{'primary_key'}} = $conf->{'name'};
        }
    }

    return $current_object;
}


##########################################################


=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
