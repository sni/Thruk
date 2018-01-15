_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Hosts"));

    isVisible(_div("localhost"));
    isVisible(_span("Hostname"));
    isVisible(_div("Up"));
    isVisible(_div("Icons"));

    _mouseOver(_div("x-column-header-trigger"));
    _click(_div("x-column-header-trigger"));

    click(_span("Columns"));
    click(_span("Icons[1]"));
    isNotVisible(_div("Icons"));

    click(_image("/x-tool-refresh/"));
    click(_image("/x-tool-gear/"));
    _setValue(_textbox("title"), "Hostlist");
    click(_button("/checkboxfield/"));
    click(_link("save"));
    isNotVisible(_span("Hostlist"));

    testCase.endOfStep("panorama hosts panel part I", 60);

    thruk_panorama_exit();
    thruk_open_panorama();

    _mouseOver(_span("Hostlist"));
    isVisible(_span("Hostlist"));
    isNotVisible(_div("Icons"));

    thruk_unlock_dashboard();

    isVisible(_span("Hostname"));
    click(_image("/x-tool-gear/"));
    click(_button("/checkboxfield/"));
    click(_link("save"));

    _mouseOver(_span("Hostlist"));
    isVisible(_span("Hostlist"));
    isNotVisible(_div("Icons"));

    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama hosts panel part II", 60);
};

runTest($case);