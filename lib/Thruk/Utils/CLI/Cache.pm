package Thruk::Utils::CLI::Cache;

=head1 NAME

Thruk::Utils::CLI::Cache - Cache CLI module

=head1 DESCRIPTION

The cache handles the internal thruk cache.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] cache <command>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<command>

    Available commands are:

        - dump                  displays the internal cache
        - clean                 drop the internal cache

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/:all/;
use Cpanel::JSON::XS ();

##############################################
# no backends required for this command
our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data) = @_;
    $c->stats->profile(begin => "_cmd_cache($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    # cache actions
    my $command = shift @{$commandoptions} || 'help';
    if($command eq 'dump') {
        my $cache_data = $c->cache->dump;
        my $filter = shift @{$commandoptions};
        if($filter) {
            $filter =~ s/^\.//gmx;
            for my $key (split/\./mx, $filter) {
                if(ref $cache_data eq 'HASH' && defined $cache_data->{$key}) {
                    $cache_data = $cache_data->{$key};
                } else {
                    $data->{'rc'}     = 1;
                    $data->{'output'} = "";
                    return $data;
                }
            }
        }
        $data->{'rc'} = 0;
        my $json = Cpanel::JSON::XS->new->utf8;
        $json = $json->pretty;
        $json = $json->canonical; # keys will be randomly ordered otherwise
        $data->{'output'} = $json->encode($cache_data);
    }
    elsif($command eq 'clear' || $command eq 'clean' || $command eq 'drop') {
        $data->{'rc'} = 0;
        unlink($c->config->{'tmp_path'}.'/thruk.cache');
        $data->{'output'} = "cache cleared\n";
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_cache($action)");
    return($data);
}

##############################################

=head1 EXAMPLES

Display complete cache

  %> thruk cache dump

Display specific key from cache:

  %> thruk cache dump .users.thrukadmin

Drop cache (you might need to reload apache/thruk afterwards)

  %> thruk cache clean

=cut

##############################################

1;
