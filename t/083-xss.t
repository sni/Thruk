use warnings;
use strict;
use Test::More;

use Thruk::Base ();
use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];
my $whitelist_vars = Thruk::Base::array2hash([qw/
    theme url_prefix logo_path_prefix filebranch thrukversion fileversion extjs_version
     date.now pd referer cs j js jsfiles page pages class statusclass statusClass rowclass hostclass serviceclass s_status_text
    loopclass body_class param.breakdown url defaults.$key.link
    c.config.useragentcompat c.stash.last_graph_type c.config.notes_url_target
    c.config.action_url_target avgClass log.class rowclasses show_sitepanel extrabodyclass b.cls
    remote_thruk_url bug_email_rcpt main target prio pnp_url c.config.extra_version_link
    histou_frame_url histou_url c.stash.help_topic n.annotation peer_key passive_icon svcbg
    get_user_token(c) object.get_id() object.get_id object.get_type() svc.get_id()
    obj_id start end servicelink l.url plugin.url r.link link action_url n.node_url
    c.config.use_feature_core_scheduling prefix paneprefix style counter service_comment_count
    sites.up sites.disabled sites.down pb_options.lineheight desc refresh_rate
    h.current_notification_number s.current_notification_number how_far_back audiofile
    host.$host_icon_image_alt host_comment_count param_name state_color last_col
    crit.text crit.value icon pic pnpdata onchange
    day monthday hour hours min key helpkey colprefix columns_name
    has_bp bp.fullid r.fullid hex rd.file b.basefile
    host_health_pic service_health_pic health_perc service_perc
    a.t1 a.t2 nr id first_remaining tblID start_with
    s_status f d i j x key size head_height image_width state hoststate status image_height
    div_id graph_url index loop_index filterprefix center extra_classes
    c.config.jquery_ui c.config.start_page c.config.home_link
    host_health_cls service_health_cls host_perc opt_class ok_pct w_pct u_pct c_pct p_pct
    s.cpu_perc perc plugin_name plugin_editor_path shinken_features_path
/]);
my $whitelist_regex = [
    qr/^\w+\.(id|nr)$/,
    qr/^\w+\.href$/,
    qr/^\w+\.peer_key$/,
    qr/^\w+\.target$/,
    qr/^\w+\.width$/,
    qr/^\w+\.height$/,
    qr/^\w+\.notes_url$/,
    qr/^\w+\.notes_url_expanded$/,
    qr/^\w+\.action_url$/,
    qr/^\w+\.comment_count$/,
    qr/^\w+\.keys\.size$/,
    qr/^\w+\.action_url_expaned$/,
    qr/^\w+\.icon_image$/,
    qr/^[\w\$\.]+icon_image_expanded$/,
    qr/^date.now[\s\d\+\*\-]+$/,
    qr/^loop\.\w+$/,
    qr/^a\.(x|y)\d*$/,
    qr/^action_icon\(/,
    qr/^c\.config/,
];
my @dirs = glob("./templates ./plugins/plugins-available/*/templates ./themes/themes-available/*/templates");
for my $dir (@dirs) {
    for my $file (@{Thruk::Utils::IO::find_files($dir, '\.tt$')}) {
        check_templates($file);
    }
}
@dirs = glob("./lib ./plugins/plugins-available/*/lib");
for my $file (Thruk::Utils::IO::all_perl_files(@dirs) ) {
    check_libs($file);
}
done_testing();

sub check_templates {
    my($file) = @_;
    return if($filter && $file !~ m%$filter%mx);
    return if($file =~ m%templates/excel%mx);
    return if($file =~ m%templates/.*csv.*%mx);
    my $content = Thruk::Utils::IO::read($file);
    my $failed = 0;
    my $escaped_keys = {};

    while($content =~ m/<form[^>]*post[^>]*>.*?<\/form>/gsmxi) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);

        next if $file =~ m%/_blocks\.tt$%mx;
        next if $file =~ m%/login\.tt$%mx;
        next if $file =~ m%/_status_column_select\.tt$%mx;
        next if $tag =~ m%/login\.cgi%mx;

        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        if($tag !~ m/CSRFtoken/mx) {
            fail("$file uses post form without csrf token starting on line $linenr");
        }
    }

    # extract all tags
    $content =~ s/\[%\+?\s*(ELSIF|IF|UNLESS|FOREACH)\s*([^;%]*?)\s*;/[% /gmx;
    $content =~ s/\[%\+?\s*(ELSIF|IF|UNLESS|FOREACH)\s*([^;%]*?)\s*\+?%\]//gmx;
    while($content =~ m%(<[^>]+>)%gms) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        next if substr($tag,0,2) eq '</';
        next if $tag !~ m/\[%/gmx;
        # extract attributes from this tag
        my $str = $tag; # not copying the string seems to miss some matches
        my @attributes = $str =~ m%([\w\-]+)=("[^"]*"|'[^']*')%sgmx;
        while(my ($key,$value) = splice(@attributes,0,2)) {
            next unless $value =~ m/\[%/mx;
            my @tt = $value =~ m/\[%[^%]*%\]/sgmx;
            my $escaped = 0;
            for my $var (@tt) {
                $var =~ s/^\[%\+?\s*(.*?)\s*\+?%\]/$1/gmx;
                $var =~ s/\d+\s+[\+\-*\%]+\s+//gmx;
                next if defined $whitelist_vars->{$var};
                my $found = 0;
                for my $r (@{$whitelist_regex}) {
                    if($var =~ $r) {
                        $found++;
                        last;
                    }
                }
                next if $found;
                next if $var eq '';
                next if $var eq 'END';
                next if $var eq 'ELSE';

                if($key =~ m/^(href|src)$/mx) {
                    if($var =~ m/
                                     \|\s*uri
                                    |\|\s*html
                                    |escape_html\(
                                    |full_uri\(
                                    |short_uri\(
                                    |uri_with\(
                                    |base_url\(
                                    /mx) {
                        $escaped = 1;
                        my $escaped_var = $var;
                        $escaped_var =~ s/\s*\|.*$//gmx;
                        for(1..3) { $escaped_var =~ s/[\w_]+\(([^\)]+)\)/$1/gmx; }
                        $escaped_keys->{$escaped_var} = $linenr;
                        next;
                    }
                    fail(sprintf("%s:%d uses variable '%s' without uri/html filter in: %s=%s", $file, $linenr, $var, $key, $value));
                    $failed++;
                }
                else {
                    if($var =~ m/
                                    \|\s*html
                                    |escape_html\(
                                    |full_uri\(
                                    |short_uri\(
                                    |uri_with\(
                                    |base_url\(
                                    |escape_js\(
                                    |name2id\(
                                    |encode_json_obj\(
                                    |json_encode\(
                                    |date_format\(
                                    /mx) {
                        $escaped = 1;
                        my $escaped_var = $var;
                        $escaped_var =~ s/\s*\|.*$//gmx;
                        for(1..3) { $escaped_var =~ s/[\w_]+\((\s*[^\)]+\s*)\)/$1/gmx; }
                        $escaped_keys->{$escaped_var} = $linenr;
                        next;
                    }
                    next if $var =~ m/\.size$/mx;
                    fail(sprintf("%s:%d uses variable '%s' without html filter in: %s=%s", $file, $linenr, $var, $key, $value));
                    $failed++;
                }
            }
            if($escaped && $value =~ m/^'/mx && $value !~ m/(encode_json_obj|json_encode)\(/mx) {
                fail(sprintf("%s:%d uses single quotes but html/uri filter only escapes double quotes in: %s=%s", $file, $linenr, $key, $value));
                $failed++;
                #diag($tag);
            }
        }
    }
    # check if escaped keys are used elsewhere
    while($content =~ m%(\[\%.*?\%\])%gms) {
        my $tag = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        my $var = $tag;
        $var =~ s/^\[%\+?\s*(.*?)\s*\+?%\]$/$1/gmx;
        if(defined $escaped_keys->{$var}) {
            next if $var eq 'cust.1';
            next if $var eq 'referer';
            next if $var =~ m/^PROCESS/mx;
            next if($var eq 'plugin_output' && $file =~ m/(_status_detail_table|_status_hostdetail_table)\.tt/mx);
            fail(sprintf("%s:%d uses unescaped variable which is used escaped elsewhere in the same file (line %d) in: %s", $file, $linenr, $escaped_keys->{$var}, $tag));
            $failed++;
        }
    }

    if(!$failed) {
        ok(1, $file." seems to be ok");
    }
}

sub check_libs {
    my($file) = @_;
    my $content = Thruk::Utils::IO::read($file);
    my $failed = 0;

    return if($filter && $file !~ m%$filter%mx);

    # do not put json encoded structures into stash, instead use json_encode() from within the template
    while($content =~ m%(\$c->stash[^\n]*encode[^\n]*)%gms) {
        my $match = substr($content, $-[0], $+[0]-$-[0]);
        my $linenr = 1 + substr($content,0,$-[0]) =~ y/\n//;
        next if $match =~ m/Thruk::Utils::Filter::json_encode/gmx;
        fail(sprintf("%s:%d puts encoded structure into stash, better use encoding function from within the template or Thruk::Utils::Filter::json_encode directly: %s", $file, $linenr, $match));
        $failed++;
    }

    if(!$failed) {
        ok(1, $file." seems to be ok");
    }
}
