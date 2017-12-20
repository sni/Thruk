_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    if(isChrome()) {
        _log("SKIP: test is broken in chrome");
        return;
    }

    thruk_login();
    thruk_open_panorama();

    click(_link("", _rightOf(_link("Dashboard"))));
    click(_span("New Dashboard"));

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Hostgroup Status"));
    mouseClickXY(50,50);
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_link("save"));

    screenRegion.find("green.png").rightClick();
    click(_span("Clone"));
    mouseClickXY(100,100);

    // rename dashboard and change to geo map
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "GeoMap Test");
    _click(_label("Geo Map"));
    click(_link("save"));

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Hostgroup Status"));
    mouseClickXY(50,100);
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_link("save"));

    screenRegion.find("green.png").rightClick();
    click(_span("Clone"));
    mouseClickXY(100,50);

    screenRegion.waitForImage("island_map_green.png", 3).mouseMove();

    testCase.endOfStep("panorama geo map switch I", 60);

    thruk_panorama_exit();
    thruk_open_panorama();
    screenRegion.waitForImage("island_map_green.png", 3).mouseMove();

    // change dashboard to static image
    thruk_unlock_dashboard("GeoMap Test");
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));

    _click(_label("Static Image"));

    isVisible(_textbox('background'));
    click(_div('/trigger/', _rightOf(_textbox('background'))));
    click(_div("europa.png"));
    click(_link("save"));

    screenRegion.waitForImage("island_green.png", 3).mouseMove();

    thruk_panorama_exit();
    thruk_open_panorama();
    screenRegion.waitForImage("island_green.png", 3).mouseMove();

    // remove dashboard
    thruk_remove_panorama_dashboard("GeoMap Test");

    testCase.endOfStep("panorama geo map switch II", 60);
};

runTest($case);