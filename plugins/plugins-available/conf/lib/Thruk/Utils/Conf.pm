package Thruk::Utils::Conf;

use strict;
use warnings;
use File::Slurp;
use Digest::MD5 qw(md5_hex);

=head1 NAME

Thruk::Utils::Conf.pm - Helper Functios for the Config Tool

=head1 DESCRIPTION

Helper Functios for the Config Tool

=head1 METHODS

=cut

######################################

=head2 update_conf

update inline config

=cut
sub update_conf {
    my $file     = shift;
    my $data     = shift;
    my $md5      = shift;
    my $defaults = shift;
    my $update_c = shift;

    my($old_content, $old_data, $old_md5) = read_conf($file, $defaults);
    if($md5 ne $old_md5) {
        return("cannot update, file has been changed since reading it.");
    }

    # remove unchanged values
    for my $key (keys %{$data}) {
        if(   $old_data->{$key}->[0] eq 'STRING'
           or $old_data->{$key}->[0] eq 'INT'
           or $old_data->{$key}->[0] eq 'BOOL'
           or $old_data->{$key}->[0] eq 'LIST'
           ) {
            if($old_data->{$key}->[1] eq $data->{$key}) {
                delete $data->{$key}
            }
        }
        elsif(   $old_data->{$key}->[0] eq 'ARRAY'
              or $old_data->{$key}->[0] eq 'MULTI_LIST') {
            if(join(',',@{$old_data->{$key}->[1]}) eq join(',',@{$data->{$key}})) {
                delete $data->{$key}
            }
        } else {
            confess("unknown type: ".$old_data->{$key}->[0]);
        }
    }

    # update thruks config directly, so we don't need to restart
    if($update_c) {
        for my $key (keys %{$data}) {
            $update_c->config->{$key} = $data->{$key};
        }
    }

    my $new_content = merge_conf($old_content, $data);

    if($new_content eq $old_content) {
        return("no changes made");
    }

    open(my $fh, ">", $file) or return("cannot update, failed to write to $file: $!");
    print $fh $new_content;
    close($fh);

    return;
}


######################################

=head2 read_conf

read config file

=cut

sub read_conf {
    my $file = shift;
    my $data = shift;

    my $arrays_defined = {};

    my $content  = read_file($file);
    my $md5      = md5_hex($content);
    for my $line (split/\n/mx, $content) {
        next if $line eq '';
        next if substr($line, 0, 1) eq '#';
        if($line =~ m/\s*(\w+)\s*=\s*(.*)\s*(\#.*|)$/mx) {
            my $key   = $1;
            my $value = $2;
            if(defined $data->{$key}) {
                if(   $data->{$key}->[0] eq 'ARRAY'
                   or $data->{$key}->[0] eq 'MULTI_LIST') {
                    $data->{$key}->[1] = [] unless defined $arrays_defined->{$key};
                    $arrays_defined->{$key} = 1;
                    push @{$data->{$key}->[1]}, split(/\s*,\s*/mx,$value);
                } else {
                    $value             =~ s/^"(.*)"$/$1/gmx;
                    $data->{$key}->[1] = $value;
                }
            }
        }
    }

    return($content, $data, $md5);
}


######################################

=head2 merge_conf

merge config file with data

=cut

sub merge_conf {
    my $text = shift;
    my $data = shift;

    my $keys_placed = {};
    my $new = "";
    for my $line (split/(\n)/mx, $text, -1) {
        if(    $line eq ''
            or $line eq "\n"
            or substr($line, 0, 1) eq '#'
           ) {
            $new .= $line;
        }
        elsif($line =~ m/\s*(\w+)\s*=\s*(.*)\s*(\#.*|)$/mx) {
            my $key   = $1;
            my $value = $2;
            $value    =~ s/^"(.*)"$/$1/gmx;
            if(defined $keys_placed->{$key}) {
                chomp($new);
                next;
            }
            if(defined $data->{$key}) {
                if(   ref($data->{$key}) eq 'ARRAY'
                   or ref($data->{$key}) eq 'MULTI_LIST') {
                    $value = join(',', @{$data->{$key}});
                } else {
                    $value = $data->{$key};
                }
                $new .= $key."=".$value;
                delete $data->{$key};
                $keys_placed->{$key} = 1;
            } else {
                $new .= $line;
            }
        }
        else {
            $new .= $line;
        }
    }

    # no append all keys which doesn't have been changed already
    for my $key (keys %{$data}) {
        my $value;
        if(   ref($data->{$key}) eq 'ARRAY'
           or ref($data->{$key}) eq 'MULTI_LIST') {
            $value = join(',', @{$data->{$key}});
        } else {
            $value = $data->{$key};
        }
        $new .= $key."=".$value."\n";
    }

    return($new);
}


##########################################################

=head2 get_data_from_param

get data hash from post parameter

=cut

sub get_data_from_param {
    my $param    = shift;
    my $defaults = shift;
    my $data     = {};

    for my $key (keys %{$param}) {
        next unless $key =~ m/^data\./mx;
        my $value = $param->{$key};
        $key =~ s/^data\.//mx;
        if(   $defaults->{$key}->[0] eq 'ARRAY'
           or $defaults->{$key}->[0] eq 'MULTI_LIST') {
            if(ref $value eq 'ARRAY') {
                $data->{$key} = $value;
            } else {
                $data->{$key} = [ split(/\s*,\s*/mx, $value) ];
            }
        } else {
            $data->{$key} = $value;
        }
    }
use Data::Dumper;
print STDERR Dumper($data);
    return $data;
}


##########################################################

=head2 get_data_from_param

get data hash from post parameter

=cut

sub to_hash {
    my $array = shift;
    my $hash  = {};

    for my $elem (@{$array}) {
        $hash->{$elem} = $elem;
    }

    return $hash;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
