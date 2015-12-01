_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    click(_button("", _rightOf(_button("Dashboard"))));
    click(_span("New Dashboard"));

    mouseRightClickXY(100, 100);
    click(_span("Dashboard Settings"));
    _click(_label("Geo Map"));
    isVisible(_div("lockButton locked"));
    _click(_button("cancel"));
    isNotVisible(_div("lockButton locked"));

    mouseRightClickXY(100, 100);
    click(_span("Dashboard Settings"));
    _click(_label("Geo Map"));
    _click(_button("save"));
    isVisible(_div("lockButton locked"));

    mouseRightClickXY(100, 100);
    click(_span("Dashboard Settings"));
    _click(_label("Static Image"));
    _click(_button("cancel"));
    isVisible(_div("lockButton locked"));

    _click(_link("x-tab-close-btn[1]"));
    isNotVisible(_link("x-tab-close-btn[1]"));

    testCase.endOfStep("panorama geo map cancel", 60);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
