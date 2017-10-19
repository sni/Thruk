_dynamicInclude($includeFolder);
_include('../_include.js');
_include('../_dashboard_exports.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    click(_link($testUser));
    click(_span("Dashboard Management"));
    click(_link("Import/Export"));
    click(_link("Import Tab(s) from Text"));
    _setValue(_textarea(0), $dashboardTestBackground);
    click(_link("OK"));

    isVisible(_span("World Clock"));

    mouseRightClickXY(200,100);
    click(_span("Direct Link"));

    _wait(3000, _assert(_popup("Test Background")));
    _popup("Test Background")._assertExists(_span("World Clock"));
    _popup("Test Background")._assert(_isVisible(_span("World Clock")));
    _popup("Test Background")._assertNotExists(_div("/loading panel/"));
    _popup("Test Background")._assertNotExists(_link($testUser));
    _popup("Test Background")._closeWindow();

    isVisible(_span("World Clock"));

    thruk_remove_panorama_dashboard("Test Background");

    testCase.endOfStep("panorama direct link", 60);
    thruk_panorama_logout();
};

runTest($case);