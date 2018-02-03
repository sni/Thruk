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
    click(_span("New Geo Map"));

    // rename dashboard and change background image
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "Arrow Element");
    click(_span("save"));

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Line / Arrow / Watermark"));

    mouseClickXY(200,100);

    isVisible(_textbox('host'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem(0));
    isVisible(_textbox('service'));
    click(_div('/trigger/', _rightOf(_textbox('service'))));
    _setValue(_textbox("service"), "Example Check");

    screenRegion.waitForImage("arrow_map_geo.png", 3).mouseMove();

    click(_span("save"));

    mouseClickXY(300,300);

    //openDebugConsole();
    screenRegion.waitForImage("arrow_map_geo.png", 3).mouseMove();

    // remove dashboard
    thruk_remove_panorama_dashboard("Arrow Element");

    testCase.endOfStep("panorama arrow widget geo", 120);
};

runTest($case);
