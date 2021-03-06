package Thruk::Utils::Conf::Tools::ObjectReferences;

use warnings;
use strict;

use Thruk::Utils ();
use Thruk::Utils::Conf ();

=head1 NAME

Thruk::Utils::Conf::Tools::ObjectReferences.pm - Tool to verify object references

=head1 DESCRIPTION

Tool to verify object references

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category    => 'References',
        link        => 'Check Object References',
        title       => 'Cross Reference Check',
        description => 'Find all objects with broken cross references',
        fixlink     => 'remove',
    };
    bless($self, $class);
    return($self);
}

##########################################################

=head2 get_list($c, $ignores)

returns list of potential objects to remove

=cut
sub get_list {
    my($self, $c, $ignores) = @_;
    my $result = $c->{'obj_db'}->_check_references(hash => 1);
    return(Thruk::Utils::Conf::clean_from_tool_ignores($result, $ignores));
}

##########################################################

=head2 cleanup

cleanup this object

=cut
sub cleanup {
    my($self, $c, $obj) = @_;
    Thruk::Utils::set_message( $c, 'fail_message', 'automatic cleanup not possible' );
    return;
}

##########################################################

1;
