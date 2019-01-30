package Monitoring::Config::Object;

use strict;
use warnings;
use Carp;
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
use Monitoring::Config::Object::Escalation;

# Icinga and Shinken:
use Monitoring::Config::Object::Module;

# Shinken:
use Monitoring::Config::Object::Arbiter;
use Monitoring::Config::Object::Broker;
use Monitoring::Config::Object::Poller;
use Monitoring::Config::Object::Reactionner;
use Monitoring::Config::Object::Receiver;
use Monitoring::Config::Object::Scheduler;

use Monitoring::Config::Object::Discoveryrule;
use Monitoring::Config::Object::Discoveryrun;
use Monitoring::Config::Object::Notificationway;
use Monitoring::Config::Object::Realm;
use Monitoring::Config::Object::Businessimpactmodulation;
use Monitoring::Config::Object::Resultmodulation;
use Monitoring::Config::Object::Checkmodulation;

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
    'module',
    'escalation',
    # Shinken:
    'discoveryrule',
    'discoveryrun',
    'notificationway',
    'realm',
];

##########################################################

=head2 new

    new({
        coretype => coretype,  # can be nagios, icinga, shinken or any
        type     => type,
        line     => nr,
        file     => file object,
        name     => name
    })

return a new L<object|Monitoring::Config::Object::Parent> of given type. Type can be any of the following:
    L<host|Monitoring::Config::Object::Host>
    L<hostgroup|Monitoring::Config::Object::Hostgroup>
    L<hostextinfo|Monitoring::Config::Object::Hostextinfo>
    L<hostdependency|Monitoring::Config::Object::Hostdependency>
    L<hostescalation|Monitoring::Config::Object::Hostescalation>
    L<service|Monitoring::Config::Object::Service>
    L<servicegroup|Monitoring::Config::Object::Servicegroup>
    L<serviceextinfo|Monitoring::Config::Object::Serviceextinfo>
    L<servicedependency|Monitoring::Config::Object::Servicedependency>
    L<serviceescalation|Monitoring::Config::Object::Serviceescalation>
    L<command|Monitoring::Config::Object::Command>
    L<timeperiod|Monitoring::Config::Object::Timeperiod>
    L<contact|Monitoring::Config::Object::Contact>
    L<contactgroup|Monitoring::Config::Object::Contactgroup>
    L<module|Monitoring::Config::Object::Module>
    L<escalation|Monitoring::Config::Object::Escalation>

=cut
sub new {
    my($class, %conf) = @_;
    confess('no core type!') unless defined $conf{'coretype'};
    confess('no type!')      unless defined $conf{'type'};

    my $objclass = 'Monitoring::Config::Object::'.ucfirst($conf{'type'});
    my $obj = \&{$objclass."::BUILD"};
    return unless defined &{$obj};
    my $current_object = &{$obj}($objclass, $conf{'coretype'});

    return unless defined $current_object;

    $current_object->{'conf'}     = $conf{'conf'} || {};
    $current_object->{'line'}     = $conf{'line'} || 0;
    $current_object->set_file($conf{'file'}) if defined $conf{'file'};
    $current_object->{'comments'} = $conf{'comments'} || [];
    $current_object->{'id'}       = $conf{'id'} || 'new';
    $current_object->{'disabled'} = defined $conf{'disabled'} ? $conf{'disabled'} : 0;

    if(defined $conf{'name'}) {
        if(ref $current_object->{'primary_key'} eq 'ARRAY') {
            if($current_object->{'default'}->{$current_object->{'primary_key'}->[0]}->{'type'} eq 'LIST') {
                $current_object->{'conf'}->{$current_object->{'primary_key'}->[0]} = [ $conf{'name'} ];
            } else {
                $current_object->{'conf'}->{$current_object->{'primary_key'}->[0]} = $conf{'name'};
            }
        } else {
            if($current_object->{'default'}->{$current_object->{'primary_key'}}->{'type'} eq 'LIST') {
                $current_object->{'conf'}->{$current_object->{'primary_key'}} = [ $conf{'name'} ];
            } else {
                $current_object->{'conf'}->{$current_object->{'primary_key'}} = $conf{'name'};
            }
        }
        if(defined $current_object->{'standard'}) {
            for my $key (@{$current_object->{'standard'}}) {
                next if defined $current_object->{'conf'}->{$key};
                if($current_object->{'default'}->{$key}->{'type'} eq 'LIST') {
                    $current_object->{'conf'}->{$key} = [];
                } else {
                    $current_object->{'conf'}->{$key} = '';
                }
            }
        }
    }

    return $current_object;
}

##########################################################

=head2 format_comments

    format_comments($comments)

returns formated comments from config files

=cut

sub format_comments {
    my($comments) = @_;
    my $text = '';
    my $num  = scalar @{$comments};
    for my $l (@{$comments}) {
        my $line = ''.$l;
        $line =~ s/^;/\#/gmxo;
        $line =~ s/^\#([^\#])/#\ $1/gmxo;
        $line =~ s/^\#\s+//gmxo;
        $line =~ s/\s+$//gmxo;
        last if $num == 1 and ($line eq '' or $line eq '#');
        if(substr($line,0,1) eq '#') {
            $text .= $line."\n";
        }
        elsif($line eq '') {
            $text .= "#\n";
        }
        else {
            $text .= '# '.$line."\n";
        }
    }
    return $text;
}


##########################################################

1;
