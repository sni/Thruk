package Thruk::Utils::CLI::Rest;

=head1 NAME

Thruk::Utils::CLI::Rest - Rest API CLI module

=head1 DESCRIPTION

The rest command is a cli interface to the rest api.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] rest [-m method] [-d postdata] <url>

=cut

use warnings;
use strict;
use Getopt::Long ();
use Cpanel::JSON::XS ();

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    # parse options
    my $opt = {
      'method' => undef,
      'data'   => [],
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "m|method=s" => \$opt->{'method'},
       "d|data=s"   =>  $opt->{'data'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $url = shift @{$commandoptions} || '';
    if(!$url) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }
    $url =~ s|^/||gmx;

    if(scalar @{$opt->{'data'}} > 0 && !$opt->{'method'}) {
        $opt->{'method'} = 'POST';
    }
    $opt->{'method'} = 'GET' unless $opt->{'method'};

    my $postdata = {};
    for my $d (@{$opt->{'data'}}) {
        if(ref $d eq '' && $d =~ m/^\{.*\}$/mx) {
            my $data;
            my $json = Cpanel::JSON::XS->new->utf8;
            $json->relaxed();
            eval {
                $data = $json->decode($d);
            };
            if($@) {
                return("failed to parse json data argument: ".$@, 1);
            }
            for my $key (sort keys %{$data}) {
                $postdata->{$key} = $data->{$key};
            }
            next;
        }
        my($key,$val) = split(/=/mx, $d, 2);
        next unless $key;
        if(defined $postdata->{$key}) {
            $postdata->{$key} = [$postdata->{$key}] unless ref $postdata->{$key} eq 'ARRAY';
            push @{$postdata->{$key}}, $val;
        } else {
            $postdata->{$key} = $val;
        }
    }

    $c->stats->profile(begin => "_cmd_rest($url)");
    my $sub_c = $c->sub_request('/r/v1/'.$url, uc($opt->{'method'}), $postdata, 1);
    $c->stats->profile(end => "_cmd_rest($url)");
    return({output => $sub_c->res->body, rc => ($sub_c->res->code == 200 ? 0 : 1) });
}

##############################################

=head1 EXAMPLES

Get list of hosts sorted by name

  %> thruk r /hosts?sort=name

Get list of hostgroups starting with literal l

  %> thruk r '/hostgroups?name[~]=^l'

Reschedule next host check for host localhost:

  %> thruk r -d "start_time=now" /hosts/localhost/cmd/schedule_host_check

See more examples and additional help at https://thruk.org/documentation/rest.html

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
