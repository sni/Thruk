package Thruk::Utils::CLI::Apikey;

=head1 NAME

Thruk::Utils::CLI::Apikey - APIKeys CLI module

=head1 DESCRIPTION

Show information about a Thruk api keys

=head1 SYNOPSIS

  Usage: thruk [globaloptions] apikey <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - info <key|file>            show information about existing api key
    - create [options]           create new api key
    - new                        alias for 'create'

      options:

       u|user=<name>                use username for key
       r|roles=<restrict to roles>  restrict api key to given roles
       comment=<decription>         add description
       superuser                    make it a superuser key
       force_user                   sets username in combination with super user flag

=back

=cut

use warnings;
use strict;
use Getopt::Long ();

use Thruk::Utils ();
use Thruk::Utils::APIKeys ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Log qw/:all/;

our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_apikeys($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required\n", 1);
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }
    my $mode = shift @{$commandoptions};

    # parse options
    my $opts = {
        roles => [],
    };
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "u|user=s"           => \$opts->{'username'},
       "r|roles=s"          =>  $opts->{'roles'},
         "comment=s"        => \$opts->{'comment'},
         "superuser"        => \$opts->{'superuser'},
         "force_user"       => \$opts->{'force_user'},
    ) || do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my($output, $rc) = ("", 0);
    if($mode eq 'info') {
        my $key = shift @{$commandoptions};
        ## no critic
        if(!$key && -t 0) {
            $key = Thruk::Utils::CLI::read_stdin_password("enter private key: ");
        }
        ## use critic
        $output = _print_key($c, $key);
    }
    elsif($mode eq 'create' || $mode eq 'new') {
        if(!$opts->{'username'} && !$opts->{'superuser'}) {
            return("ERROR - please specify --user or --superuser\n", 1);
        }
        $opts->{'restrict'} = 1;
        my($private_key, $hashed_key, $filename) = Thruk::Utils::APIKeys::create_key_by_params($c, $opts);
        if(!$private_key) {
            return("ERROR - failed to create api key\n", 1);
        }
        _debug("created key: %s", $filename);
        $output .= "new api key has been created:\n\n";
        $output .= ('*'x80)."\n";
        $output .= sprintf("SECRET: %s\n", $private_key);
        $output .= ('*'x80)."\n\n";
        $output .= _print_key($c, $private_key);
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_apikeys($action)");
    return($output, $rc);
}

##############################################
sub _print_key {
    my($c, $key) = @_;
    my($file, $data);
    my($hashed_key, $digest_nr, $digest_name) = Thruk::Utils::APIKeys::get_keyinfo_by_private_key($c->config, $key);
    if($hashed_key) {
        $file = sprintf("%s/api_keys/%s.%s", $c->config->{'var_path'}, $hashed_key, $digest_name);
    }
    if((!$file || !-e $file) && -e $key) {
        $file   = $key;
    }

    $data = Thruk::Utils::APIKeys::read_key($c->config, $file) if $file;
    my $res    = [
        { 'name' => 'hashed key', 'value' => $hashed_key // $data->{'hashed_key'} },
        { 'name' => 'digest',     'value' => $digest_name },
        { 'name' => 'file name',  'value' => $file },
    ];
    if(!$file) {
        push @{$res}, { 'name' => 'info',  'value' => "wrong key format" };
    }
    elsif(!-e $file) {
        push @{$res}, { 'name' => 'info',  'value' => "unable to read key: ".$! };
    }
    elsif(!$data) {
        push @{$res}, { 'name' => 'info',  'value' => "unable to read key: unknown reason" };
    } else {
        push @{$res}, { 'name' => 'super user',       'value' => $data->{'superuser'} ? 'yes' : 'no' };
        push @{$res}, { 'name' => 'user',             'value' => $data->{'user'} // 'any user' };
        push @{$res}, { 'name' => 'role restriction', 'value' => $data->{'roles'}     ? join(", ", @{$data->{'roles'}}) : 'no restrictions' };
        push @{$res}, { 'name' => 'create date',      'value' => $data->{'created'}   ? scalar localtime($data->{'created'}) : 'unknown' };
        push @{$res}, { 'name' => 'last used date',   'value' => $data->{'last_used'} ? scalar localtime($data->{'last_used'}) : 'never' };
        push @{$res}, { 'name' => 'last used from',   'value' => $data->{'last_from'} ? $data->{'last_from'} : '' };
        push @{$res}, { 'name' => 'comment',          'value' => $data->{'comment'} };
    }
    my $output = Thruk::Utils::text_table(
        noheader => 1,
        keys => ['name', 'value'],
        data => $res,
    );
    return($output);
}

##############################################

=head1 EXAMPLES

Show api key information

  %> thruk apikeys info key....

=cut

##############################################

1;
