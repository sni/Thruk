package Thruk::Utils::Cache;

=head1 NAME

Thruk::Utils::Cache - Cache Utilities Collection for Thruk

=head1 DESCRIPTION

Cache Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Storable qw(retrieve);

use Thruk::Utils::IO ();

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
    return $self;
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

=head2 age

  age()

returns the cache age in seconds

=cut
sub age {
    my($self) = @_;
    return unless $self->{'_stat'};
    return(time() - $self->{'_stat'}->[9]);
}

##############################################

=head2 touch

  touch()

update file stat to current date

=cut
sub touch {
    my($self) = @_;
    my $mtime = time();
    utime($mtime, $mtime, $self->{'_cachefile'});
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
    Thruk::Utils::IO::json_lock_store($self->{'_cachefile'}, $self->{'_data'});
    my @stat = stat($self->{'_cachefile'}) or die("cannot stat ".$self->{'_cachefile'}.": ".$!);
    $self->{'_stat'} = \@stat;
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
        $data = Thruk::Utils::IO::json_lock_retrieve($self->{'_cachefile'});
    };
    my $err = $@;
    if($err) {
        # try old storable format
        eval {
            $data = retrieve($self->{'_cachefile'});
        };
        # clear error if read succeeded
        $err = undef unless $@;
    }
    if($err) {
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
