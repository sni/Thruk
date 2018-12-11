_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    click(_link("", _rightOf(_link("Dashboard"))));
    click(_span("New Dashboard"));

    // rename dashboard and change background image
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "Arrow Element");
    click(_div('/trigger/', _rightOf(_textbox('background'))));
    click(_div("europa.png"));
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

    click(_span("Appearance"));
    if(isChrome()) {
        _assertEqual("187 px", _getValue(_textbox("connectorfromx")));
        _assertEqual("137 px", _getValue(_textbox("connectorfromy")));
        _assertEqual("387 px", _getValue(_textbox("connectortox")));
        _assertEqual("137 px", _getValue(_textbox("connectortoy")));
    } else {
        _assertEqual("187 px", _getValue(_textbox("connectorfromx")));
        _assertEqual("136 px", _getValue(_textbox("connectorfromy")));
        _assertEqual("387 px", _getValue(_textbox("connectortox")));
        _assertEqual("136 px", _getValue(_textbox("connectortoy")));
    }

    click(_span("save"));

    mouseClickXY(300,300);
    screenRegion.waitForImage("arrow_map.png", 3).mouseMove();

    mouseMoveXY(130,100);
    mouseDrag(130,100, 130, 150);

    mouseRightClickXY(130, 150);

    click(_span("Settings"));
    click(_span("Appearance"));

    if(isChrome()) {
        _assertEqual("187 px", _getValue(_textbox("connectorfromx")));
        _assertEqual("212 px", _getValue(_textbox("connectorfromy")));
        _assertEqual("387 px", _getValue(_textbox("connectortox")));
        _assertEqual("137 px", _getValue(_textbox("connectortoy")));
    } else {
        _assertEqual("187 px", _getValue(_textbox("connectorfromx")));
        _assertEqual("211 px", _getValue(_textbox("connectorfromy")));
        _assertEqual("387 px", _getValue(_textbox("connectortox")));
        _assertEqual("136 px", _getValue(_textbox("connectortoy")));
    }

    _setValue(_textbox("connectorfromx"), "187");
    _setValue(_textbox("connectorfromy"), "136");
    click(_span("save"));

    screenRegion.waitForImage("arrow_map.png", 3).mouseMove();

    // remove dashboard
    thruk_remove_panorama_dashboard("Arrow Element");

    testCase.endOfStep("panorama arrow widget", 180);
};

runTest($case);
