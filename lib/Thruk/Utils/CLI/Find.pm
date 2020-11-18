package Thruk::Utils::CLI::Find;

=head1 NAME

Thruk::Utils::CLI::Find - Find objects and references by name

=head1 DESCRIPTION

The find command looks for references for given objects

=head1 SYNOPSIS

  Usage: thruk [globaloptions] find <type> <name>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<type>

    available types are:

    - host                 find hosts
    - hostgroup            find hostgroups
    - service              find services
    - servicegroup         find servicegroups
    - contact              find contacts

=back

=cut

use warnings;
use strict;
use Thruk::Utils::References;
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $options) = @_;
    $c->stats->profile(begin => "_cmd_find($action)");

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    # collect all available backends
    $c->{'db'}->enable_backends();
    eval {
        $c->{'db'}->get_processinfo();
    };
    _debug($@) if $@;
    Thruk::Action::AddDefaults::set_possible_backends($c, {});

    # collect backends with object configuration
    my $config_backends = {};
    if($c->config->{'use_feature_configtool'}) {
        require Thruk::Utils::Conf;
        $config_backends = Thruk::Utils::Conf::get_backends_with_obj_config($c);
    }

    my $type = shift @{$commandoptions} || '';
    my $name = shift @{$commandoptions} || '';
    my $name2;
    if($type eq 'service') {
        $name2 = shift @{$commandoptions} || '';
    }

    my $selected_backends;
    if($options->{'backends'} && scalar @{$options->{'backends'}} > 0) {
        $selected_backends = {};
        my($disabled_backends) = Thruk::Action::AddDefaults::set_enabled_backends($c, $options->{'backends'});
        for my $key (sort keys %{$disabled_backends} ) {
            $selected_backends->{$key} = 1 if $disabled_backends->{$key} == 0;
        }
    }

    # gather results
    my $res = {};
    for my $peer_key (@{$c->stash->{'backends'}}) {
        next if $selected_backends && !$selected_backends->{$peer_key};

        if($type eq 'host') {
            return("ERROR: please specify hostname", 1) unless $name;
            Thruk::Utils::References::get_host_matches($c, $peer_key, $config_backends, $res, $name);
        }
        elsif($type eq 'hostgroup') {
            return("ERROR: please specify hostgroupname", 1) unless $name;
            Thruk::Utils::References::get_hostgroup_matches($c, $peer_key, $config_backends, $res, $name);
        }
        elsif($type eq 'service') {
            return("ERROR: please specify hostname", 1) unless $name;
            return("ERROR: please specify servicename", 1) unless $name2;
            Thruk::Utils::References::get_service_matches($c, $peer_key, $config_backends, $res, $name, $name2);
        }
        elsif($type eq 'servicegroup') {
            return("ERROR: please specify servicegroupname", 1) unless $name;
            Thruk::Utils::References::get_servicegroup_matches($c, $peer_key, $config_backends, $res, $name);
        }
        elsif($type eq 'contact') {
            return("ERROR: please specify contactname", 1) unless $name;
            Thruk::Utils::References::get_contact_matches($c, $peer_key, $config_backends, $res, $name);
        }
        else {
            return("ERROR: no such type", 1);
        }
    }

    # format results
    my($msg, $rc) = ("", 0);
    for my $peer_key (@{$c->stash->{'backends'}}) {
        next unless $res->{$peer_key};
        $msg .= sprintf("%s:\n", $c->stash->{'backend_detail'}->{$peer_key}->{'name'});
        for my $key (sort keys %{$res->{$peer_key}}) {
            $msg .= sprintf("  %s:\n", $key);
            for my $row (@{$res->{$peer_key}->{$key}}) {
                $msg .= sprintf("    %-30s %s\n", $row->{'name'}, $row->{'details'});
            }
        }
        $msg .= "\n";
    }

    if(!$msg) {
        $msg .= "cannot find any reference for ".$type." '".$name."'";
        $msg .= " - '".$name2."'" if $name2;
        $msg .= "\n";
    }

    $c->stats->profile(end => "_cmd_find($action)");
    return($msg, $rc);
}

##############################################

=head1 EXAMPLES

Find references for host localhost

  %> thruk find host localhost

Find references for service ping on host localhost

  %> thruk find service localhost ping

Find references for contact omdadmin

  %> thruk find contact omdadmin

=cut

##############################################

1;
