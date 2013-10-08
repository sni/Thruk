package Thruk::Utils::Cache;

=head1 NAME

Thruk::Utils::Cache - Cache Utilities Collection for Thruk

=head1 DESCRIPTION

Cache Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use Storable qw/lock_nstore lock_retrieve/;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(cache);

##########################################################

=head1 METHODS

=head2 new

create new cache instance

=cut
sub new {
    my($class,$cachefile) = @_;
    my $self = {
        '_cachefile' => $cachefile,
        '_data'      => {},
        '_stat'      => [],
        '_checked'   => 0,
    };
    bless $self, $class;
    $self->_update();
    return $self;
}


##############################################

=head2 cache

  cache()

return cache

=cut
sub cache {
    my($class, $file) = @_;
    our $instance;
    if($file) { $instance = __PACKAGE__->new($file); }
    if(!$instance) { confess('uninitialized'); }
    return $instance;
}

##############################################

=head2 get

  get($key)

return cache entry

=cut
sub get {
    my($self,$key) = @_;
    $self->_update();
    if($key) {
        return($self->{'_data'}->{$key});
    }
    return($self->{'_data'});
}

##############################################

=head2 set

  set($key, $value)

set value

=cut
sub set {
    my($self,$key,$value, $value2) = @_;
    $self->_update('force' => 1);
    if(defined $value2) {
        $self->{'_data'}->{$key}->{$value} = $value2;
    } else {
        $self->{'_data'}->{$key} = $value;
    }
    $self->_store();
    return;
}

##############################################

=head2 dump

  dump()

dump complete cache

=cut
sub dump {
    my($self) = @_;
    return($self->{'_data'});
}

##############################################

=head2 clear

  clear()

clear complete cache

=cut
sub clear {
    my($self) = @_;
    $self->{'_data'} = {};
    $self->_store();
    return;
}

##############################################

=head2 _update

  _update()

update cache from file

=cut
sub _update {
    my($self, %args) = @_;
    my $update = 0;
    if($args{'force'}) {
        $update = 1;
    }
    if(-f $self->{'_cachefile'}) {
        my $now = time();
        # only check every x seconds
        if($now > $self->{'_checked'} + 5) {
            $self->{'_checked'} = $now;
            my @stat = stat($self->{'_cachefile'});
            if(!$self->{'_stat'}->[9] || $stat[9] != $self->{'_stat'}->[9]) {
                $self->{'_data'} = lock_retrieve($self->{'_cachefile'});
                $self->{'_stat'} = \@stat;
                return;
            }
        }
        if($update) {
            $self->{'_data'} = lock_retrieve($self->{'_cachefile'});
            $self->{'_stat'} = [stat($self->{'_cachefile'})];
        }
    } else {
        # did not exist before, so create an empty cache
        $self->_store();
    }
    return;
}

##############################################

=head2 _store

  _store()

store cache to disk

=cut
sub _store {
    my($self) = @_;
    lock_nstore($self->{'_data'}, $self->{'_cachefile'});
    $self->{'_stat'}    = [stat($self->{'_cachefile'})];
    my $now = time();
    $self->{'_checked'} = $now;
    return;
}

##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2013, <sven@consol.de>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
