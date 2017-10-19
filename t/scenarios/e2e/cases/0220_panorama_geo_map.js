_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    click(_link("", _rightOf(_link("Dashboard"))));
    click(_span("New Geo Map"));

    // give the map some time to load
    screenRegion.waitForImage("controls_unlock.png", 10).mouseMove();

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Hostgroup Status"));

    mouseClickXY(100,100);
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_link("save"));

    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_link("Yes"));

    screenRegion.find("controls_unlock.png").click();
    isVisible(_image("zoom-world-mini.png"));

    // rename dashboard
    mouseRightClickXY(100,100);
    click(_span("Dashboard Settings"));

    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "GeoMap Test");

    click(_link("save"));

    isVisible(_link("GeoMap Test"));

    thruk_remove_panorama_dashboard("GeoMap Test");

    testCase.endOfStep("panorama geo map", 60);
};

runTest($case);