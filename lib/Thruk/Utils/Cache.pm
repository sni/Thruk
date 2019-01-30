package Thruk::Utils::Cache;

=head1 NAME

Thruk::Utils::Cache - Cache Utilities Collection for Thruk

=head1 DESCRIPTION

Cache Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess/;
use Thruk::Utils::IO ();
use Storable qw(nstore retrieve);
use File::Copy qw(move);

use base 'Exporter';
our @EXPORT_OK = qw(cache);

##########################################################

=head1 METHODS

=head2 new

create new cache instance

=cut
sub new {
    my($class,$cachefile) = @_;
    my $self = {
        '_cachefile'    => $cachefile,
        '_data'         => {},
        '_stat'         => [],
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
    #my($class, $file)...
    my(undef, $file) = @_;
    our $instance;
    if($file) { $instance = __PACKAGE__->new($file); }
    if(!$instance) { confess('uninitialized'); }
    return $instance;
}

##############################################

=head2 get

  get()
  get($key)
  get($key, $key2)
  get($key, $key2, $key3)
  ...

return cache entry

=cut
sub get {
    my($self,@keys) = @_;
    $self->_update();
    my $last_key = pop(@keys);
    return($self->{'_data'}) unless $last_key;
    my $data = $self->{'_data'};
    return unless defined $data;
    while(my $key = shift @keys) {
        return unless defined $data->{$key};
        $data = $data->{$key};
    }
    return($data->{$last_key});
}

##############################################

=head2 set

  set($data)
  set($key, $value)
  set($key, $key2, $value)
  set($key, $key2, $key3, $value)
  ...

set value

=cut
sub set {
    my($self,@keys) = @_;
    if(scalar @keys == 1) {
        $self->{'_data'} = $keys[0];
        $self->_store();
        return;
    }
    my $value    = pop(@keys);
    my $last_key = pop(@keys);
    $self->_update();
    my $data = $self->{'_data'};
    while(my $key = shift @keys) {
        $data->{$key} = {} unless defined $data->{$key};
        $data = $data->{$key};
    }
    $data->{$last_key} = $value;
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
    unlink($self->{'_cachefile'});
    $_[0] = Thruk::Utils::Cache->new($self->{'_cachefile'});
    return;
}

##############################################

=head2 _update

  _update()

update cache from file

=cut
sub _update {
    my($self) = @_;
    if(-f $self->{'_cachefile'}) {
        my @stat = stat(_);
        if(!$self->{'_stat'}->[9] || $stat[9] != $self->{'_stat'}->[9]) {
            $self->{'_data'} = $self->_retrieve();
            $self->{'_stat'} = \@stat;
            return;
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
    nstore($self->{'_data'}, $self->{'_cachefile'}.'.'.$$) or die("saving tmp cache file ".$self->{'_cachefile'}.'.'.$$." failed: $!");
    my @stat = stat($self->{'_cachefile'}.'.'.$$) or die("cannot stat ".$self->{'_cachefile'}.'.'.$$.": ".$!);
    $self->{'_stat'} = \@stat;
    move($self->{'_cachefile'}.'.'.$$, $self->{'_cachefile'});
    Thruk::Utils::IO::ensure_permissions('file', $self->{'_cachefile'});
    return;
}

##############################################

=head2 _retrieve

  _retrieve()

retrieve data from disk

=cut
sub _retrieve {
    my($self) = @_;
    my $data;
    eval {
        $data = retrieve($self->{'_cachefile'});
    };
    if($@) {
        my $err = $@;
        $self->clear();
        $self->{'_data'} = {};
        $self->_store();
        $data = {};
        warn('failed to read '.$self->{'_cachefile'}.': '.$err);
    }
    return $data;
}

##############################################

1;
