_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Services"));

    isVisible(_div("localhost"));
    isVisible(_span("Hostname"));
    isVisible(_span("Service"));

    click(_image("/x-tool-refresh/"));
    isVisible(_div("Ok"));

    click(_image("/x-tool-search/"));
    isVisible(_span("Filter"));

    _click(_textbox("servicestatustypes"));

    click(_div("x-combo-list-item"));
    click(_link("save"));
    isVisible(_div("Critical"));

    click(_image("/x-tool-gear/"));
    click(_link("cancel"));


    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama services panel", 60);
};

runTest($case);