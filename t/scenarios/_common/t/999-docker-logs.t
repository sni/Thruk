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
        ok(1, sprintf("%s_%d - %s", $svc, $index, $cont));
        for my $logfile (@logs) {
            my($rc, $log) = Thruk::Utils::IO::cmd("docker exec -t --user root $cont cat $logfile");
            next unless $rc == 0;
            ok(1, sprintf("  %s", $logfile));
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
                        diag($log);
                    }
                }
            }
        }
    }
}

done_testing();
