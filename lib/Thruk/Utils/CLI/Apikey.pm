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

    - info <key|file>            show information about api key

=back

=cut

use warnings;
use strict;

use Thruk::Utils ();
use Thruk::Utils::APIKeys ();
use Thruk::Utils::CLI ();

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
        return("ERROR - authorized_for_admin role required", 1);
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }
    my $mode = shift @{$commandoptions};

    my($output, $rc) = ("", 0);
    if($mode eq 'info') {
        my $key = shift @{$commandoptions};
        ## no critic
        if(!$key && -t 0) {
            $key = Thruk::Utils::CLI::read_stdin_password("enter private key: ");
        }
        ## use critic
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
            push @{$res}, { 'name' => 'super user',     'value' => $data->{'superuser'} ? 'yes' : 'no' };
            push @{$res}, { 'name' => 'user',           'value' => $data->{'user'} // 'any user' };
            push @{$res}, { 'name' => 'roles',          'value' => $data->{'roles'}     ? join(", ", @{$data->{'roles'}}) : '' };
            push @{$res}, { 'name' => 'create date',    'value' => $data->{'created'}   ? scalar localtime($data->{'created'}) : 'unknown' };
            push @{$res}, { 'name' => 'last used date', 'value' => $data->{'last_used'} ? scalar localtime($data->{'last_used'}) : 'never' };
            push @{$res}, { 'name' => 'last used from', 'value' => $data->{'last_from'} ? $data->{'last_from'} : '' };
            push @{$res}, { 'name' => 'comment',        'value' => $data->{'comment'} };
        }
        $output = Thruk::Utils::text_table(
            noheader => 1,
            keys => ['name', 'value'],
            data => $res,
        );
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_apikeys($action)");
    return($output, $rc);
}

##############################################

=head1 EXAMPLES

Show api key information

  %> thruk apikeys info key....

=cut

##############################################

1;
