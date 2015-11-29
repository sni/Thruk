_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    _log("prepare dashboard");
    click(_button("", _rightOf(_button("Dashboard"))));
    click(_span("New Dashboard"));
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "Export Test");
    click(_button("save"));

    click(_button("add"));
    click(_span("Site Status"));
    isVisible(_div("Naemon"));

    click(_button("add"));
    click(_span("Server Status"));
    isVisible(_div("User"));

    rightClick(_button("Export Test"));
    click(_span("Dashboard Settings"));
    click(_button("Import/Export"));
    click(_button("Export Active Tab as Text"));

    _log("get export string");
    isVisible(_textarea(0));
    var $exportTab = _getValue(_textarea(0));
    click(_button("OK"));

    _log("remove dashboard");
    thruk_remove_panorama_dashboard("Export Test");

    _log("tab import");
    click(_button($testUser));
    click(_span("Dashboard Management"));
    click(_button("Import/Export"));
    click(_button("Import Tab(s) from Text"));
    _setValue(_textarea(0), $exportTab);
    click(_button("OK"));

    isVisible(_div("Naemon"));
    isVisible(_div("User"));

    _log("remove dashboard again");
    thruk_remove_panorama_dashboard("Export Test");

    testCase.endOfStep("panorama import export", 120);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
