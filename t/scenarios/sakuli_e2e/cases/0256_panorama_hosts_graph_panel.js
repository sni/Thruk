_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Hosts Graph"));

    isVisible(_div("Up"));

    click(_image("/x-tool-gear/"));
    click(_link("cancel"));
    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama hosts graph panel", 20);
};

runTest($case);