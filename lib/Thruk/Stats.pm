package Thruk::Stats;

use warnings;
use strict;
use Data::Dumper;
use Time::HiRes qw/gettimeofday tv_interval/;

sub new {
    my($class) = @_;
    my $self = {
        'profile' => [],
        'enabled' => 0,
    };
    bless($self, $class);
    return($self);
}

sub profile {
    my($self, @arg) = @_;
    return unless $self->{'enabled'};
    my $t0 = [gettimeofday];
    push @{$self->{'profile'}}, [$t0, \@arg, [caller]];
    return;
}
sub enable {
    $_[0]->{'enabled'} = 1;
    return;
}

sub clear {
    $_[0]->{'profile'} = [];
    return;
}

sub report {
    my($self) = @_;
    my $data = $self->{'profile'};
    my $result = [];
    my $childs = $result;
    my $cur;
    for my $d (@{$data}) {
        my($time, $args, $caller) = @{$d};
        my($key,$val)             = @{$args};
        die("corrupt profile entry: ".Dumper($d)) unless $key;
        die("corrupt profile entry: ".Dumper($d)) unless $val;
        if($key eq 'begin') {
            my $entry = {
                'childs'     => [],
                'parent'     => $cur,
                'name'       => $val,
                'start'      => $time,
                'start_call' => $caller,
                'level'      => defined $cur->{'level'} ? $cur->{'level'} + 1 : 1,
            };
            push @{$childs}, $entry;
            $childs = $entry->{'childs'};
            $cur    = $entry;
        }
        elsif($key eq 'end') {
            # find matching start
            my $entry = $cur;
            while($cur && $cur->{'name'} ne $val) {
                $cur = $cur->{'parent'};
            }
            if($cur && $cur->{'name'} eq $val) {
                $cur->{'end'} = $time;
                if(!defined $cur->{'parent'}->{'name'}) {
                    # add to result root
                    $cur    = $entry;
                    $childs = $result;
                } else {
                    $cur    = $cur->{'parent'};
                    $childs = $cur->{'childs'};
                }
            } else {
                # found no start
                print STDERR "no start found for: ".$entry->{'name'}."\n";
                die("no start found for: ".Dumper($entry)) if Thruk->debug;
            }
        }
        elsif($key eq 'comment') {
            my $entry = {
                'parent'     => $cur,
                'name'       => $val,
                'time'       => $time,
                'start_call' => $caller,
                'level'      => defined $cur->{'level'} ? $cur->{'level'} + 1 : 1,
            };
            push @{$childs}, $entry;
        }
    }

    my $report = "Profile:\n";
    $report .= '+'.("-"x82)."+-------------+\n";
    for my $r (@{$result}) {
        $report .= $self->_format_row($r);
    }
    $report .= '+'.("-"x82)."+-------------+\n";

    return($report);
}

sub _format_row {
    my($self, $row) = @_;
    my $output  = "";
    my $indent  = " "x(2*($row->{'level'}-1));
    my $elapsed = "";
    if($row->{start}) {
        if(!defined $row->{end}) {
            # get parents end date
            my $parent = $row->{'parent'};
            while(defined $parent->{'parent'} && !defined $parent->{'end'}) {
                $parent = $parent->{'parent'};
            }
            my $end = $parent->{'end'};
            if(defined $end) {
                $elapsed = sprintf("~%.5fs", tv_interval($row->{start}, $end));
            }
        } else {
            $elapsed = sprintf("%.5fs", tv_interval($row->{start}, $row->{end}));
        }
    }
    my $name    = substr($indent.$row->{'name'}, 0, 78);
    $output .= sprintf("| %-80s | %11s |\n", $name, $elapsed);
    if($row->{'childs'} && scalar @{$row->{'childs'}} > 0) {
        for my $r (@{$row->{'childs'}}) {
            $output .= $self->_format_row($r);
        }
    }
    return($output);
}

1;
__END__

=head1 NAME

Thruk::Stats - Application profiling

=head1 SYNOPSIS

  $c->stats->profile(begin => <name>);
  ...
  $c->stats->profile(end => <name>);

=head1 DESCRIPTION

C<Thruk::Stats> provides simple profiling

=head1 METHODS

=head2 new

    new()

return new stats object

=head2 profile

    profile(begin|end => $name)
    profile(comment => $text)

sets breakpoint with message

=head2 enable

    enable()

enable profiling

=head2 clear

    clear()

reset current profile

=head2 report

    report()

return report from profiled data

=cut

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
