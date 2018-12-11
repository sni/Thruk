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

    mouseClickXY(200,130);

    isVisible(_textbox('host'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem(0));
    isVisible(_textbox('service'));
    click(_div('/trigger/', _rightOf(_textbox('service'))));
    _setValue(_textbox("service"), "Example Check");

    click(_span("Appearance"));
    _assertEqual("62.7553515625", _getValue(_textbox("lat1")));
    _assertEqual("-6.0793359375", _getValue(_textbox("lon1")));
    _assertEqual("62.7553515625", _getValue(_textbox("lat2")));
    _assertEqual("2.7097265625", _getValue(_textbox("lon2")));

    mouseMoveXY(300,300);
    screenRegion.waitForImage("arrow_map_geo.png", 3).mouseMove();

    click(_span("save"));

    screenRegion.waitForImage("arrow_map_geo.png", 3).mouseMove();
    mouseMoveXY(300,300);

    mouseRightClickXY(200,130);
    click(_span("Settings"));
    click(_span("Appearance"));
    _setValue(_textbox("lat1"), "48.858222");
    _setValue(_textbox("lon1"), "2.2945");
    _setValue(_textbox("lat2"), "51.50064");
    _setValue(_textbox("lon2"), "-0.12445");
    click(_span("save"));

    screenRegion.waitForImage("geo_paris_london.png", 3).mouseMove();

    mouseRightClickXY(240,310);
    click(_span("Settings"));
    click(_span("Appearance"));

    _assertEqual("48.858222", _getValue(_textbox("lat1")));
    _assertEqual("2.2945", _getValue(_textbox("lon1")));
    _assertEqual("51.50064", _getValue(_textbox("lat2")));
    _assertEqual("-0.12445", _getValue(_textbox("lon2")));

    // test drag / drop
    mouseMoveXY(220,290);
    mouseDrag(220,290, 220, 200);

    _assertEqual("48.858222", _getValue(_textbox("lat1")));
    _assertEqual("2.2945", _getValue(_textbox("lon1")));
    _assertEqual("57.43796875", _getValue(_textbox("lat2")));
    _assertEqual("-0.10277343749999", _getValue(_textbox("lon2")));

    // remove dashboard
    thruk_remove_panorama_dashboard("Arrow Element");

    testCase.endOfStep("panorama arrow widget geo", 180);
};

runTest($case);
