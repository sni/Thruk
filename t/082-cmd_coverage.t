use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Slurp qw/read_file/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

# ensure that all naemon commands exist
my $src   = "https://raw.githubusercontent.com/naemon/naemon-core/master/src/naemon/commands.c";
my $cache = "/var/tmp/naemon_commands.c";

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Internet required. Unset $ENV{TEST_SKIP_INTERNET} to run this test.' if $ENV{TEST_SKIP_INTERNET};
eval "use LWP::Protocol::https";
if($@) {
    plan skip_all => 'missing module: LWP::Protocol::https';
}

use_ok("Thruk::Controller::Rest::V1::cmd");

my $data     = _fetch_source();
my $commands = _parse_commands($data);
my $cmd_data = Thruk::Controller::Rest::V1::cmd::get_rest_external_command_data();
for my $cmd (sort keys %{$commands}) {
    my $found = 0;
    next if $cmd eq 'PROCESS_FILE'; # would not work over livestatus
    next if $cmd =~ m/CHANGE_CONTACT_MOD\w*ATTR/mx; # not implemented in core
    next if $cmd =~ m/CHANGE_.*_TIMEPERIOD/mx; # segfaults
    next if $cmd =~ m/DEL_DOWNTIME_BY_HOSTGROUP_NAME/mx; # segfaults
    for my $t (keys %{$cmd_data}) {
        if($cmd_data->{$t}->{lc $cmd}) {
            $found = 1;
            last;
        }
    }
    if($found) {
        ok(1, sprintf("command %s is available via rest api", $cmd));
    } else {
        fail(sprintf("command %s is not available via rest api", $cmd));
        diag(Dumper($commands->{$cmd}));
    }
}

done_testing();


################################################################################
sub _fetch_source {
    if(-e $cache && (stat(_))[10] > time() - 3600) {
        return(scalar read_file($cache));
    }
    my $req = TestUtils::_external_request($src);
    die("fetching source failed: ".Dumper($req)) unless $req->is_success;
    open(my $fh, '>', $cache);
    print $fh $req->content;
    close($fh);
    return(scalar read_file($cache));
}

################################################################################
sub _parse_commands {
    my($data) = @_;
    my $commands = {};
    my $started  = 0;
    my $complete_line = "";
    my $last_command;
    for my $line (split/\n/mx, $data) {
        next unless ($started || $line =~ m/register_core_commands\s*\(/mx);
        $started  = 1;
        $started  = 0 if $line =~ m/^\s*\}$/mx;

        next if $line =~ m/^\s*$/mx;
        $complete_line = $complete_line.$line;
        if($line !~ m/;$/mx) {
            next;
        }
        if($complete_line =~ m/command_create\s*\(([^,]+),([^,]+),\s*"([^"]*)"\s*,([^,]+)\)/mx) {
            my($name, $handler, $description, $args) = ($1, $2, $3, $4);
            $name        = _strip($name);
            $description = _strip($description);
            $args        = _strip($args);
            if($args eq 'NULL') { $args = ""; }
            $commands->{$name} = {description => $description, args => _parse_args($args), name => $name};
            $complete_line = "";
            $last_command = $commands->{$name};
            next;
        }
        if($complete_line =~ m/command_argument_add\s*\(([^,]+),([^,]+),([^,]+),([^,]+)/mx) {
            my $name = _strip($2);
            my $what = _strip($3);
            push @{$last_command->{'args'}}, lc($what)."=".$name;
            $complete_line = "";
            next;
        }
        if($line =~ m/;$/mx) {
            $complete_line = "";
        }
    }
    return($commands);
}

################################################################################
sub _strip {
    my($str) = @_;
    $str =~ s/^\s+//gmx;
    $str =~ s/\s+$//gmx;
    $str =~ s/^"//gmx;
    $str =~ s/"$//gmx;
    return($str);
}

################################################################################
sub _parse_args {
    my($str) = @_;
    return([split/\s*;\s*/mx, $str]);
}

################################################################################
