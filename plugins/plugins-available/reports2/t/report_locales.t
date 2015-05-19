use strict;
use warnings;
use Test::More;
use File::Slurp;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 182;
}
BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::Reports");
use_ok("Thruk::Utils::Reports::Render");

# extract languages
my $c = TestUtils::get_c();
my $languages = Thruk::Utils::Reports::get_report_languages($c);
is(ref $languages, 'HASH', 'got some languages');
ok(scalar keys %{$languages} > 0, 'got some languages');

# get required locale patterns
my $local_patterns = {};
for my $path (@{$c->config->{templates_paths}}, $c->config->{'View::TT'}->{'INCLUDE_PATH'}) {
    for my $file (glob($path.'/reports/*.tt')) {
        my $cont = read_file($file);
        my @pattern = $cont =~ m/loc\(['|"](.*?)['|"]\)/gmx;
        map { $local_patterns->{$_} = $_ } @pattern;
    }
    for my $file (glob($path.'/reports/comp/*.tt')) {
        my $cont = read_file($file);
        my @pattern = $cont =~ m/loc\(['|"](.*?)['|"]\)/gmx;
        map { $local_patterns->{$_} = $_ } @pattern;
    }
}

for my $l (sort keys %{$languages}) {
    ok($l, $l);
    my $abrv = $languages->{$l}->{'abrv'};
    my $tr = Thruk::Utils::get_template_variable($c, 'reports/locale/'.$abrv.'.tt', 'translations');
    is(ref $tr, 'HASH', 'got translation table');
    next if $abrv eq 'en';
    for my $p (sort keys %{$local_patterns}) {
        if(!defined $tr->{$p}) {
            fail($p.' does not exist in language pack '.$abrv);
            $tr->{$p} = '';
        }
        ok(defined $tr->{$p}, $abrv.': "'.$p.'"');
        if(substr($p, -1) eq ':') {
            is(substr($tr->{$p}, -1), ':', 'translation pattern does end with colon');
        }
    }
}
