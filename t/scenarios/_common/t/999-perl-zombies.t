use warnings;
use strict;
use Cwd;
use Test::More;

use lib Cwd::cwd().'/lib';

use_ok("Thruk::Utils::IO");

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
        my($rc, $log) = Thruk::Utils::IO::cmd("docker exec -t --user root $cont ps auxww");
        next unless $rc == 0;

        if($log =~ m/^(.*?)perl.*defunct/mx) {
            # found zombies, wait 3 seconds to disappear
            sleep(3);
            ($rc, $log) = Thruk::Utils::IO::cmd("docker exec -t --user root $cont ps auxww");
            next unless $rc == 0;
        }

        if($log =~ m/^(.*?)perl.*defunct/mx) {
            my($usr, $pid) = split(/\s+/, $1);
            fail(sprintf("%s_%d: has perl zombies", $svc, $index));
            diag($log);
            for my $cmd ("ls -la /proc/$pid/", "cat /proc/$pid/cmdline", "cat /proc/$pid/environ") {
                diag($cmd);
                my(undef, $details) = Thruk::Utils::IO::cmd("docker exec -t --user root $cont $cmd");
                diag($details);
            }
        }
    }
}

done_testing();
