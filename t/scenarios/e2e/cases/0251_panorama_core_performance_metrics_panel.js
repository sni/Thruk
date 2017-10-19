_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Core Performance Metrics"));

    isVisible(_div("Servicechecks"));
    isVisible(_div("Hostchecks"));
    isVisible(_div("Requests"));

    click(_image("/x-tool-refresh/"));
    click(_image("/x-tool-gear/"));
    click(_link("cancel"));
    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama core performance metrics panel", 20);

    thruk_panorama_logout();
};

runTest($case);