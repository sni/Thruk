function test1() {
    str = 'a=1&b=2&c=3&c=4&d=5&d=6&d=7&e';
    var obj = toQueryParams(str);
    if(str != toQueryString(obj)) {
        diag("failed: " + str + " != " + toQueryString(obj));
        return 0;
    }
    return 1;
}

function test1a() {
    str = 'a=1&b=&c=3&c=4&d=5&d=6&d=7&e';
    exp = 'a=1&b=%3D&c=3&c=4&d=5&d=6&d=7&e';
    var obj = toQueryParams(str);
    if(str != toQueryString(obj)) {
        diag("failed: " + str + " != " + toQueryString(obj));
        return 0;
    }
    return 1;
}

var theme         = 'Thruk';
var perf_bar_mode = 'match';
function custom_perf_bar_adjustments(perf_bar_mode) {
    return(perf_bar_mode);
}
function test2() {
    var write = false,
        state = 0,
        plugin_output = '',
        perfdata = "'c:\ Used Space'=9,38Gb;38,98;43,86;0.00;48,73",
        check_command = '',
        pnp_url = '',
        is_host = false;
    var res = perf_table(write, state, plugin_output, perfdata, check_command, pnp_url, is_host);
    if(res == '') {
        diag("expected perf bar for: " + perfdata);
        return 0;
    }
    return 1;
}
