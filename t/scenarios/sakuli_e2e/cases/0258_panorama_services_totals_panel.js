_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Services Totals"));

    isVisible(_div("Ok"));
    isVisible(_div("Warning"));

    click(_image("/x-tool-refresh/"));
    click(_image("/x-tool-gear/"));
    click(_link("cancel"));
    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama services totals panel", 20);
};

runTest($case);