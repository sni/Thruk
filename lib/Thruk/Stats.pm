package Thruk::Stats;

use warnings;
use strict;
use Data::Dumper;
use Time::HiRes qw/gettimeofday tv_interval/;
use Carp qw/longmess/;
#use Thruk::Timer qw/timing_breakpoint/;

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
    #&timing_breakpoint($arg[1], undef, 1) if $arg[0] eq 'end';
    return unless $self->{'enabled'};
    my $t0 = [gettimeofday];
    my $longmess;
    if($ENV{'THRUK_PERFORMANCE_STACKS'} && $arg[0] ne 'end') {
        $longmess = longmess;
    }
    push @{$self->{'profile'}}, [$t0, \@arg, [caller], $longmess];
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

sub _result {
    my($self) = @_;
    my $data = $self->{'profile'};
    my $result = [];
    my $childs = $result;
    my $cur;
    for my $d (@{$data}) {
        my($time, $args, $caller, $stack) = @{$d};
        my($key,$val) = @{$args};
        die("corrupt profile entry: ".Dumper($d)) unless $key;
        die("corrupt profile entry: ".Dumper($d)) unless $val;
        if($key eq 'begin') {
            my $entry = {
                'childs'     => [],
                'parent'     => $cur,
                'name'       => $val,
                'start'      => $time,
                'start_call' => $caller,
                'stack'      => $stack,
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
                'stack'      => $stack,
                'level'      => defined $cur->{'level'} ? $cur->{'level'} + 1 : 1,
            };
            push @{$childs}, $entry;
        }
    }
    return($result);
}

sub report_html {
    my($self) = @_;
    my $result = $self->_result();
    my $report = "Profile:\n";
    $report .= "<table style='border: 1px solid black; width: 800px;'>";
    $self->{'total_time'} = _row_elapsed($result->[0]);
    $self->{'total_time'} =~ s/s$//gmx if $self->{'total_time'};
    $self->{'total_time'} =~ s/^~//gmx if $self->{'total_time'};
    for my $r (@{$result}) {
        $report .= $self->_format_html_row($r);
    }
    $report .= "</table>";
    return($report);
}

sub report {
    my($self) = @_;
    my $result = $self->_result();
    my $report = "Profile:\n";
    $report .= '+'.("-"x82)."+-------------+\n";
    for my $r (@{$result}) {
        $report .= $self->_format_text_row($r);
    }
    $report .= '+'.("-"x82)."+-------------+\n";

    return($report);
}

sub _format_text_row {
    my($self, $row) = @_;
    my $output  = "";
    my $indent  = " "x(2*($row->{'level'}-1));
    my $elapsed = _row_elapsed($row);
    my $name    = substr($indent.$row->{'name'}, 0, 78);
    $output .= sprintf("| %-80s | %11s |\n", $name, $elapsed);
    if($row->{'childs'} && scalar @{$row->{'childs'}} > 0) {
        for my $r (@{$row->{'childs'}}) {
            $output .= $self->_format_text_row($r);
        }
    }
    return($output);
}

sub _format_html_row {
    my($self, $row) = @_;
    our $id;
    $id = 0 unless defined $id;
    $id++;
    my $indent  = " "x(2*($row->{'level'}-1));
    my $elapsed = _row_elapsed($row);
    my $name    = substr($indent.$row->{'name'}, 0, 78);
    my $output  = "<tr>";
    my $clickable = '';
    if($row->{'stack'}) {
        $clickable = " class='clickable' onclick='jQuery(\".pstack_details, .pstack_more\").css(\"display\",\"none\"); jQuery(\".pstack_expand\").css(\"display\",\"\"); toggleElement(\"pstack_".$id."\")' ";
    }
    $output .= "<td".$clickable.">".$name."</td>\n";
    $output .= "<td>".$elapsed."</td>\n";
    if($self->{'total_time'}) {
        if($elapsed && $row->{'level'} > 1) {
            $elapsed =~ s/s$//gmx;
            $elapsed =~ s/^~//gmx;
            my $perc = $elapsed / $self->{'total_time'};
            $output .= "<td style='text-align:right; position: relative;' width=50>";
            $output .= "<div style='width: ".sprintf("%.0f", 100*$perc)."%; height: 16px; position: absolute; top:0; right:0; background-color: #b9b9b9;'></div>";
            $output .= "<span style='position: absolute; top:0; right:0; margin-right: 3px;'>".sprintf("%.1f", $perc*100)."%</span>";
            $output .= "</td>\n";
        } else {
            $output .= "<td></td>\n";
        }
    }
    $output .= "</tr>\n";
    if($row->{'stack'}) {
        my @stack = split(/\n/mx, $row->{'stack'});
        my @show;
        my @rest;
        my $rest = 0;
        for my $s (@stack) {
            if($s =~ m/^\s*Plack/mx) {
                $rest = 1;
            }
            if($rest) {
                push @rest, $s;
            } else {
                push @show, $s;
            }
        }
        $output .= "<tr style='display:none;' id='pstack_".$id."' class='pstack_details'>\n";
        $output .= "<td colspan=2><pre style='overflow: scroll; width: 794px; padding: 0 0 15px 0; margin: 0; height: inherit; min-width: inherit; border: 1px solid grey;'>\n";
        $output .= join("\n", @show);
        if(scalar @rest > 0) {
            $output .= "<span class='clickable pstack_expand' onclick='toggleElement(\"pstack_more_".$id."\"); this.style.display=\"none\";'>\n...</span>";
            $output .= "<span id='pstack_more_".$id."' class='pstack_more' style='display: none;'>";
            $output .= "\n".join("\n", @rest);
            $output .= "</span>";
        }
        $output .= "</pre></td>\n";
        $output .= "</tr>\n";
    }
    if($row->{'childs'} && scalar @{$row->{'childs'}} > 0) {
        for my $r (@{$row->{'childs'}}) {
            $output .= $self->_format_html_row($r);
        }
    }
    return($output);
}

sub _row_elapsed {
    my($row) = @_;
    if(!$row->{start}) {
        return("");
    }
    if(defined $row->{end}) {
        return(sprintf("%.5fs", tv_interval($row->{start}, $row->{end})));
    }
    # get parents end date and use that one
    my $parent = $row->{'parent'};
    while(defined $parent->{'parent'} && !defined $parent->{'end'}) {
        $parent = $parent->{'parent'};
    }
    my $end = $parent->{'end'};
    if(defined $end) {
        return(sprintf("~%.5fs", tv_interval($row->{start}, $end)));
    }
    return("");
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

=head2 report_html

    report_html()

return report from profiled data in html format

=cut

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
