package Thruk::Base;

=head1 NAME

Thruk::Base - basic helpers without dependencies

=head1 DESCRIPTION

basic helpers without dependencies

=cut

use warnings;
use strict;
use Carp qw/confess/;
use Exporter 'import';

use Thruk::Utils::Log qw/:all/;

our @EXPORT_OK = qw(mode verbose quiet debug trace config);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

# functions imported by Utils.pm for backwards compatibility
my @compat_functions = qw/list array_uniq array2hash looks_like_regex/;
push @EXPORT_OK, @compat_functions;
$EXPORT_TAGS{compat} = \@compat_functions;

###################################################

=head1 METHODS

=head2 config

    config()

returns current configuration

=cut
sub config {
    ## no lint
    my $config = $Thruk::Config::config;
    ## use lint
    confess("uninitialized, no global config") unless $config;
    return($config);
}

###################################################

=head2 mode

    mode()

returns thruk runtime mode

=cut
sub mode {
    return($ENV{'THRUK_MODE'} // "CLI");
}

###################################################

=head2 mode_cli

    mode_cli()

returns true if thruk is cli runtime mode

=cut
sub mode_cli {
    return(&mode() =~ m/^CLI/mx ? 1 : 0);
}

###################################################

=head2 verbose

    verbose()

returns verbosity level

=cut
sub verbose {
    return($ENV{'THRUK_VERBOSE'} // 0);
}

###################################################

=head2 debug

    debug()

returns true if debug mode is enabled

=cut
sub debug {
    return(&verbose > 1);
}

###################################################

=head2 trace

    trace()

returns true if trace mode is enabled

=cut
sub trace {
    return(&verbose >= 4);
}

###################################################

=head2 quiet

    quiet()

returns true if quiet mode is enabled

=cut
sub quiet {
    return($ENV{'THRUK_QUIET'} // 0);
}

########################################

=head2 list

  list($ref)

return list of ref unless it is already a list

=cut

sub list {
    my($d) = @_;
    return [] unless defined $d;
    return $d if ref $d eq 'ARRAY';
    return([$d]);
}

########################################

=head2 array_uniq

  array_uniq($array)

return uniq elements of array

=cut

sub array_uniq {
    my($array) = @_;

    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @{$array};

    return \@unique;
}


########################################

=head2 array_uniq_obj

  array_uniq_obj($array_of_hashes)

return uniq elements of array, examining all hash keys except peer_key

=cut

sub array_uniq_obj {
    my($array) = @_;

    my @unique;
    my %seen;
    my $x = 0;
    for my $el (@{$array}) {
        my $values = [];
        for my $key (sort keys %{$el}) {
            if($key =~ /^peer_(key|addr|name)$/mx) {
                $el->{$key} = list($el->{$key});
                next;
            }
            push @{$values}, ($el->{$key} // "");
        }
        my $ident = join(";", @{$values});
        if(defined $seen{$ident}) {
            # join peer_* information
            for my $key (qw/peer_key peer_addr peer_name/) {
                next unless $el->{$key};
                push @{$unique[$seen{$ident}]->{$key}}, @{$el->{$key}};
            }
            next;
        }
        $seen{$ident} = $x;
        push @unique, $el;
        $x++;
    }

    return \@unique;
}

########################################

=head2 array_uniq_list

  array_uniq_list($array_of_lists)

return uniq elements of array, examining all list members

=cut

sub array_uniq_list {
    my($array) = @_;

    my @unique;
    my %seen;
    for my $el (@{$array}) {
        my $ident = join(";", @{$el});
        next if $seen{$ident};
        $seen{$ident} = 1;
        push @unique, $el;
    }

    return \@unique;
}

########################################

=head2 array_remove

  array_remove($array, $element)

removes element from array

=cut

sub array_remove {
    my($array, $remove) = @_;
    my @list;
    for my $e (@{$array}) {
        next if $e eq $remove;
        push @list, $e;
    }
    return \@list;
}

########################################

=head2 array_contains

  array_contains($el, $list)

returns true if element is found in list.

=cut

sub array_contains {
    my($el, $array) = @_;

    for my $l (@{$array}) {
        return 1 if $l eq $el;
    }
    return;
}

########################################

=head2 array_group_by

  array_group_by($data, $key)

create a hash of lists grouped by the key

=cut
sub array_group_by {
    my($data, $key) = @_;
    return {} unless defined $data;

    my $grouped = {};
    for my $d (@{$data}) {
        my $k = $d->{$key} // '';
        $grouped->{$k} = [] unless defined $grouped->{$k};
        push @{$grouped->{$k}}, $d;
    }

    return($grouped);
}

########################################

=head2 array2hash

  array2hash($data, [ $key, [ $key2 ]])

create a hash by key

=cut
sub array2hash {
    my($data, $key, $key2) = @_;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key2) {
        for my $d (@{$data}) {
            $hash{$d->{$key}}->{$d->{$key2}} = $d;
        }
    } elsif(defined $key) {
        %hash = map { $_->{$key} => $_ } @{$data};
    } else {
        %hash = map { $_ => $_ } @{$data};
    }

    return \%hash;
}

########################################

=head2 hash_invert

  hash_invert($hash)

return hash with keys and values inverted

=cut
sub hash_invert {
    my($hash) = @_;

    my %invert;
    for my $k (sort keys %{$hash}) {
        my $v = $hash->{$k};
        $invert{$v} = $k;
    }

    return \%invert;
}

########################################

=head2 comma_separated_list

  comma_separated_list($string)

splits lists of comma separated values into list

=cut
sub comma_separated_list {
    my($val) = @_;
    $val = [split(/\s*,\s*/mx, join(",", @{&list($val)}))];
    return(&array_uniq($val));
}

########################################

=head2 expand_numeric_list

  expand_numeric_list($txt, $c)

return expanded list.
ex.: converts '3,7-9,15' -> [3,7,8,9,15]

=cut

sub expand_numeric_list {
    my($txt, $c) = @_;
    my $list = {};
    return [] unless defined $txt;

    for my $item (@{list($txt)}) {
        for my $block (split/\s*,\s*/mx, $item) {
            if($block =~ m/(\d+)\s*\-\s*(\d+)/gmx) {
                for my $nr ($1..$2) {
                    $list->{$nr} = 1;
                }
            } elsif($block =~ m/^(\d+)$/gmx) {
                    $list->{$1} = 1;
            } else {
                _error("'$block' is not a valid number or range") if defined $c;
            }
        }
    }

    my @arr = sort keys %{$list};
    return \@arr;
}

##############################################

=head2 check_for_nasty_filename

    check_for_nasty_filename($filename)

returns true if nasty characters have been found and the filename is NOT safe for use

=cut
sub check_for_nasty_filename {
    my($name) = @_;
    confess("no name") unless defined $name;
    if($name =~ m/(\.\.|\/|\n)/mx) {
        return(1);
    }
    return;
}

###################################################

=head2 restore_signal_handler

    reset all changed signals

=cut
sub restore_signal_handler {
    ## no critic
    $SIG{INT}  = 'DEFAULT';
    $SIG{TERM} = 'DEFAULT';
    $SIG{PIPE} = 'DEFAULT';
    $SIG{ALRM} = 'DEFAULT';
    ## use critic
    return;
}

##############################################

=head2 clean_credentials_from_string

    clean_credentials_from_string($string)

returns strings with potential credentials removed

=cut
sub clean_credentials_from_string {
    my($str) = @_;

    for my $key (qw/password credential credentials CSRFtoken/) {
        $str    =~ s%("|')($key)("|'):"[^"]+"(,?)%$1$2$3:"..."$4%gmx; # remove from json encoded data
        $str    =~ s%\\("|')($key)\\("|'):\\"[^"]+"(,?)%\\$1$2\\$3:\\"..."$4%gmx; # remove from json encoded data printed by data::dumper
        $str    =~ s%("|')($key)("|'):'[^"]+'(,?)%$1$2$3:'...'$4%gmx; # same, but with single quotes
        $str    =~ s|(%22)($key)(%22%3A%22).*?(%22)|$1$2$3...$4|gmx;  # remove from url encoded data

        $str    =~ s%("|')($key)("|')(\s*=>\s*')[^']+(',?)%$1$2$3$4...$5%gmx; # remove from perl structures
        $str    =~ s%("|')($key)("|')(\s*=>\s*")[^']+(",?)%$1$2$3$4...$5%gmx; # same, but with single quotes
    }

    return($str);
}

##############################################

=head2 basename

    basename($path)

returns basename for given path

=cut
sub basename {
    my($path) = @_;
    my $basename = $path;
    $basename    =~ s%^.*/%%gmx;
    return($basename);
}

##############################################

=head2 dirname

    dirname($path)

returns dirname for given path

=cut
sub dirname {
    my($path) = @_;
    my $dirname = $path;
    $dirname    =~ s%/[^/]*$%%gmx;
    return($dirname);
}

##############################################

=head2 looks_like_regex

    looks_like_regex($str)

returns true if $string looks like a regular expression

=cut
sub looks_like_regex {
    my($str) = @_;
    if($str =~ m%[\^\|\*\{\}\[\]]%gmx) {
        return(1);
    }
    return;
}

##############################################

=head2 trim_whitespace

    trim_whitespace()

returns cleaned string

=cut
sub trim_whitespace {
    $_[0] =~ s/^\s+//mxo;
    $_[0] =~ s/\s+$//mxo;
    return($_[0]);
}


########################################

=head2 wildcard_match

    wildcard_match($str, $wildcardpattern)

returns true if string matches given wildcard pattern

=cut
sub wildcard_match {
    my($str, $pattern) = @_;
    return 1 if $pattern eq '*';
    return 1 if $str eq $pattern;
    if($pattern =~ m/\*/mx) {
        $pattern =~ s/\.*/*/gmx;
        $pattern =~ s/\*/.*/gmx;
        return 1 if $str =~ m/^$pattern$/mx;
    }
    return;
}

########################################

=head2 has_binary

    has_binary($bin)

returns true if binary is found in path

=cut
sub has_binary {
    my($bin) = @_;
    for my $p (split/:/mx, $ENV{'PATH'}) {
        return 1 if -x $p."/".$bin;
    }
    return;
}

##############################################

=head1 SEE ALSO

L<Thruk>, L<Thruk::Config>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

Thruk is Copyright (c) 2009-present by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself.

=cut

1;
