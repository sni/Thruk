_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    click(_button("", _rightOf(_button("Dashboard"))));
    click(_span("New Geo Map"));

    // give the map some time to load
    screenRegion.waitForImage("controls_unlock.png", 10).mouseMove();

    click(_button("add"));
    click(_span("Icons & Widgets"));
    click(_span("Hostgroup Status"));

    mouseClickXY(100,100);
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_button("save"));

    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_button("Yes"));

    screenRegion.find("controls_unlock.png").click();
    isVisible(_image("zoom-world-mini.png"));

    // rename dashboard
    mouseRightClickXY(100,100);
    click(_span("Dashboard Settings"));

    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "GeoMap Test");

    click(_button("save"));

    isVisible(_button("GeoMap Test"));

    thruk_remove_panorama_dashboard("GeoMap Test");

    testCase.endOfStep("panorama geo map", 60);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
