function test1() {
    var str = 'a=1&b=2&c=3&c=4&d=5&d=6&d=7&e';
    var obj = toQueryParams(str);
    if(str != toQueryString(obj)) {
        diag("failed: " + str + " != " + toQueryString(obj));
        return 0;
    }
    return 1;
}

function test1a() {
    var str = 'a=1&b=&c=3&c=4&d=5&d=6&d=7&e';
    var obj = toQueryParams(str);
    if(str != toQueryString(obj)) {
        diag("failed: " + str + " != " + toQueryString(obj));
        return 0;
    }
    return 1;
}


function test_allowed_frames() {
    var tests = [
        { url: "http://thruk.org",  allowed: ["thruk.org"],         expect: true },
        { url: "https://thruk.org", allowed: ["thruk.org"],         expect: true },
        { url: "http://thruk.org",  allowed: ["*.org"],             expect: true },
        { url: "https://thruk.org", allowed: ["http://thruk.org"],  expect: false },
        { url: "https://thruk.org", allowed: ["https://thruk.org"], expect: true },
        { url: "https://thruk.org", allowed: ["https://*.org"],     expect: true },
        { url: "https://thruk.org", allowed: ["http://*.org"],      expect: false },
    ];
    for(var i=0; i<tests.length; i++) {
        var t = tests[i];
        if(is_frame_url_allowed(t.url, t.allowed) !== t.expect) {
            diag("is_frame_url_allowed "+i+" failed for url: "+t.url);
            return 0;
        }
    }
    return 1;
}
