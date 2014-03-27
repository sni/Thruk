function test1() {
    var inp = '/site/thruk/cgi-bin/login.cgi?expired&site/thruk/cgi-bin/tac.cgi';
    var exp = 'expired&/site/thruk/cgi-bin/tac.cgi';
    var got = clean_ref(inp, true);
    if(exp != got) {
        diag("input:        " + inp);
        diag("expected ref: " + exp);
        diag("got ref:      " + got);
        return(0);
    }
    return(1);
}


function test2() {
    var inp = '?site/thruk/';
    var exp = '/site/thruk/';
    var got = clean_ref(inp);
    if(exp != got) {
        diag("input:        " + inp);
        diag("expected ref: " + exp);
        diag("got ref:      " + got);
        return(0);
    }
    return(1);
}

