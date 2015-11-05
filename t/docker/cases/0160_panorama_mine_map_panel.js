_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_button("add"));
    click(_span("Mine Map"));

    isVisible(_span("Hostname"));
    isVisible(_div("localhost"));
    isVisible(_span("HTTP"));

    click(_image("x-tool-refresh"));
    click(_image("x-tool-gear"));

    click(_button("cancel"));
    click(_image("x-tool-close"));

    testCase.endOfStep("panorama mine map panel", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
