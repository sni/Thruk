package Thruk::Utils::CLI::Rest;

=head1 NAME

Thruk::Utils::CLI::Rest - Rest API CLI module

=head1 DESCRIPTION

The rest command is a cli interface to the rest api.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] rest <url>

=cut

use warnings;
use strict;
use Getopt::Long ();

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
      'data'   => undef,
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "m|method=s" => \$opt->{'method'},
       "d|data=s"   => \$opt->{'data'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $url = shift @{$commandoptions} || '';
    if(!$url) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }
    $url =~ s|^/||gmx;

    if($opt->{'data'} && !$opt->{'method'}) {
        $opt->{'method'} = 'POST';
    }
    $opt->{'method'} = 'GET' unless $opt->{'method'};

    $c->stats->profile(begin => "_cmd_rest($url)");
    my @res = Thruk::Utils::CLI::request_url($c, '/thruk/r/v1/'.$url, undef, uc($opt->{'method'}), $opt->{'data'});

    $c->stats->profile(end => "_cmd_rest($url)");
    return({output => $res[1]->{'result'}, rc => ($res[1]->{'code'} == 200 ? 0 : 1) });
}

##############################################

=head1 EXAMPLES

Get list of hosts sorted by name

  %> thruk r /hosts?sort=name

Get list of hostgroups starting with literal l

  %> thruk r '/hostgroups?name[~]=^l'

See more examples and additional help at https://thruk.org/documentation/rest.html

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
