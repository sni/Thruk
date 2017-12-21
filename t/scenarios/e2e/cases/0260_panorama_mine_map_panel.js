_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Mine Map"));

    isVisible(_span("Hostname"));
    isVisible(_div("localhost"));
    isVisible(_span("HTTP"));

    click(_image("/x-tool-refresh/"));

    click(_image("/x-tool-gear/"));
    click(_link("cancel"));

    screenRegion.waitForImage("minemap.png", 3).mouseMove();

    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama mine map panel", 20);
};

runTest($case);