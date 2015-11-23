_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_button("add"));
    click(_span("Hosts Totals"));

    isVisible(_div("Up"));
    isVisible(_div("Down"));

    click(_image("x-tool-refresh"));
    click(_image("x-tool-gear"));
    click(_button("cancel"));
    click(_image("x-tool-close"));

    testCase.endOfStep("panorama hosts totals panel", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
