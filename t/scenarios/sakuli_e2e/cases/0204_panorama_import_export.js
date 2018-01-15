_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    _log("prepare dashboard");
    click(_link("", _rightOf(_link("Dashboard"))));
    click(_span("New Dashboard"));
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "Export Test");
    click(_link("save"));

    click(_link("add"));
    click(_span("Site Status"));
    isVisible(_div("demo"));

    click(_link("add"));
    click(_span("Server Status"));
    isVisible(_div("User"));

    rightClick(_link("Export Test"));
    click(_span("Dashboard Settings"));
    click(_link("Import/Export"));
    click(_link("Export Active Tab as Text"));

    _log("get export string");
    isVisible(_textarea(0));
    var $exportTab = _getValue(_textarea(0));
    click(_link("OK"));

    _log("remove dashboard");
    thruk_remove_panorama_dashboard("Export Test");

    _log("tab import");
    click(_link($testUser));
    click(_span("Dashboard Management"));
    click(_link("Import/Export"));
    click(_link("Import Tab(s) from Text"));
    _setValue(_textarea(0), $exportTab);
    click(_link("OK"));

    isVisible(_div("demo"));
    isVisible(_div("User"));

    _log("remove dashboard again");
    thruk_remove_panorama_dashboard("Export Test");

    testCase.endOfStep("panorama import export", 120);
};

runTest($case);