_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Host / Service Performance"));

    isVisible(_div("Service Check Execution Time"));
    isVisible(_div("Service Check Latency"));

    click(_image("/x-tool-refresh/"));
    click(_image("/x-tool-gear/"));
    click(_link("cancel"));
    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama host / service performance panel", 20);
};

runTest($case);
