package Thruk::Utils::CLI::Panorama;

=head1 NAME

Thruk::Utils::CLI::Panorama - Panorama CLI module

=head1 DESCRIPTION

The panorama command manages panorama dashboards from the command line.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] panorama [command]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<command>

    available commands are:

      - clean           remove empty dashboards

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/_error _info _debug _trace/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_panorama($action)");

    if(!$c->config->{'use_feature_panorama'}) {
        return("ERROR - panorama dashboard addon is disabled\n", 1);
    }

    eval {
        require Thruk::Utils::Panorama;
    };
    if($@) {
        _debug($@);
        return("panorama plugin is disabled.\n", 1);
    }

    my $command = shift @{$commandoptions} || 'help';
    my $output  = "";
    if($command eq 'clean' || $command eq 'clean_dashboards') {
        $c->stash->{'is_admin'} = 1;
        $c->{'panorama_var'}    = $c->config->{'var_path'}.'/panorama';
        my $num = Thruk::Utils::Panorama::clean_old_dashboards($c);
        $output = "OK - cleaned up $num old dashboards\n";
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_panorama($action)");
    return($output, 0);
}

##############################################

=head1 EXAMPLES

Clean empty dashboards

  %> thruk dashboard clean

=cut

1;
