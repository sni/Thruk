_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    click(_link("", _rightOf(_link("Dashboard"))));
    click(_span("New Dashboard"));

    mouseRightClickXY(100, 100);
    click(_span("Dashboard Settings"));
    _click(_label("Geo Map"));
    isVisible(_div("lockButton locked"));
    _click(_link("cancel"));
    isNotVisible(_div("lockButton locked"));

    mouseRightClickXY(100, 100);
    click(_span("Dashboard Settings"));

    // rename dashboard
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "GeoMap Test");

    _click(_label("Geo Map"));
    _click(_link("save"));
    isVisible(_div("lockButton locked"));

    mouseRightClickXY(100, 100);
    click(_span("Dashboard Settings"));
    _click(_label("Static Image"));
    isNotVisible(_div("lockButton locked"));
    _click(_link("cancel"));
    isVisible(_div("lockButton locked"));

    thruk_remove_panorama_dashboard("GeoMap Test");

    testCase.endOfStep("panorama geo map cancel", 60);
};

runTest($case);