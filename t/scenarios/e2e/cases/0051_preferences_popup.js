_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    click(_link("Tactical Overview"));

    click(_submit("preferences"));
    isVisible(_span("/Update in \\d+ seconds/"));
    click(_button("stop"));
    isVisible(_span("This page will not refresh automatically"));
    mouseClickXY(200,150);
    isNotVisible(_span("This page will not refresh automatically"));
    click(_submit("/top_refresh_button/"));
    click(_submit("preferences"));
    isVisible(_span("/Update in \\d+ seconds/"));

    click(_select("theme"));
    isVisible(_button("change"));

    testCase.endOfStep("preferences popup", 20);
};

runTest($case);
