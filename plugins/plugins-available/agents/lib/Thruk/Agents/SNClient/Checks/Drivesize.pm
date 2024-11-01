package Thruk::Agents::SNClient::Checks::Drivesize;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Drivesize - returns disk related checks for snclient

=head1 METHODS

=cut

##########################################################

=head2 get_checks

    get_checks()

returns snclient checks

=cut
sub get_checks {
    my($self, $c, $inventory, $hostname, $password, $section) = @_;
    my $checks = [];

    return unless $inventory->{'drivesize'};

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'drivesize', {
            'fstype'     => '= cdfs',
            'drive'      => '~ ^(/sys|/run|/dev|/proc|/var/lib/docker|/Volumes/com.apple.TimeMachine.localsnapshots|/Volumes/.timemachine|/private/tmp/)',
            'mounted'    => "0",
            'size_bytes' => "0",
    });

    for my $drive (@{$inventory->{'drivesize'}}) {
        my $prefix = "disk";
        $drive->{'fstype'} = lc($drive->{'fstype'} // '');
        $prefix = "nfs"  if $drive->{'fstype'} eq 'nfs';
        $prefix = "nfs"  if $drive->{'fstype'} eq 'nfs4';
        $prefix = "cifs" if $drive->{'fstype'} eq 'cifs';
        $prefix = "fuse" if $drive->{'fstype'} eq 'fuseblk';
        $prefix = "fuse" if $drive->{'fstype'} eq 'fuse';
        if($drive->{'type'} && $drive->{'type'} eq 'cdrom') {
            # add check if cdrom is empty
            push @{$checks}, {
                'id'       => 'cdrom.'.Thruk::Utils::Agents::to_id($drive->{'drive_or_id'}),
                'name'     => 'cdrom empty '.$drive->{'drive_or_id'},
                'check'    => 'check_drivesize',
                'args'     => { "drive" => $drive->{'drive_or_id'}, 'warn' => 'mounted = 1' },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::make_info($drive),
                'disabled' => Thruk::Utils::Agents::check_disable($drive, $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}, ['cdrom']),
            };
        } else {
            my $def_opts = Thruk::Agents::SNClient::default_opt($c, 'drivesize') // 'show-all freespace-ignore-reserved=false';
            push @{$checks}, {
                'id'       => 'df.'.Thruk::Utils::Agents::to_id($drive->{'drive_or_id'}),
                'name'     => $prefix.' '.$drive->{'drive_or_id'},
                'check'    => 'check_drivesize',
                'args'     => [ "drive='".$drive->{'drive_or_id'}."'", $def_opts ],
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::make_info($drive),
                'disabled' => !$drive->{'drive'} ? 'drive has no name' : Thruk::Utils::Agents::check_disable($drive, $disabled_config, ['drivesize', $prefix]),
            };
        }
    }

    return $checks;
}

##########################################################

1;
