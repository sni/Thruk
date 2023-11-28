use warnings;
use strict;
use Cwd;
use Test::More;

use lib Cwd::cwd().'/lib';

use_ok("Thruk::Utils::IO");

my @logs = qw(
    /opt/omd/sites/demo/var/log/apache/error_log
    /opt/omd/sites/demo/var/log/thruk.log
    /opt/omd/sites/demo/var/thruk/cron.log
);
my @errors = (
    qr/\Qsyntax error near unexpected\E/mx,
    qr/\QBEGIN failed--compilation aborted\E/mx,
    qr/\s+at\s+[\w\/\.\-]+\s+line/mx,
    qr/\[ERROR\]/mx,
);

my @exceptions = (
    qr/\QThruk::Utils::Cluster::pong failed on\E/mx,
);

# get running container
chdir($ENV{'THRUK_CONFIG'});
my($rc, $services) = Thruk::Utils::IO::cmd("docker-compose config --services");
for my $svc (split/\n/mx, $services) {
    my($rc, $container) = Thruk::Utils::IO::cmd("docker-compose ps -q $svc");
    my $index = 0;
    for my $cont (split/\n/mx, $container) {
        $index++;
        my $logfiles_printed = {};
        ok(1, sprintf("%s_%d - %s", $svc, $index, $cont));

        # check omd version
        my($rc, $sites) = Thruk::Utils::IO::cmd("docker exec -t --user root $cont omd sites");
        next unless $rc == 0;
        next if $sites =~ m/demo\s+2\.\d+\-labs/mx; # skip very old sites

        for my $logfile (@logs) {
            my($rc, $log) = Thruk::Utils::IO::cmd("docker exec -t --user root $cont cat $logfile");
            next unless $rc == 0;
            ok(1, sprintf("  %s", $logfile));

            # remove connection errors which might happen during provisioning
            $log =~ s|\Q[ERROR]\E.*?\Q********\E.*?\QNo backend available\E.*?\Q[ERROR]\E.*?\Q********\E||sgmxi;
            $log =~ s|\Q[ERROR]\E.*?\QNo backend available\E.*?\Q[ERROR]\E.*?\Qfailed to connect\E||sgmxi;

            for my $err (@errors) {
                if($log =~ $err) {
                    my $ok = 0;
                    for my $ex (@exceptions) {
                        if($log =~ $ex) {
                            $ok = 1;
                            last;
                        }
                    }
                    if(!$ok) {
                        fail(sprintf("%s_%d: %s matches %s", $svc, $index, $logfile, $err));
                        if($logfiles_printed->{$logfile}) {
                            diag("* logfile already shown *");
                        } else {
                            diag($log);
                            $logfiles_printed->{$logfile} = 1;
                        }
                    }
                }
            }
        }
    }
}

done_testing();
