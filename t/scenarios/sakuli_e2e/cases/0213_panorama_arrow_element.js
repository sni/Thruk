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
    _assertEqual("62.7553515625", _getValue(_textbox("connectorfromx")));
    _assertEqual("-6.0793359375", _getValue(_textbox("connectorfromy")));
    _assertEqual("62.7553515625", _getValue(_textbox("connectortox")));
    _assertEqual("2.7097265625", _getValue(_textbox("connectortox")));

    click(_span("save"));

    mouseClickXY(300,300);
    screenRegion.waitForImage("arrow_map.png", 3).mouseMove();

    // remove dashboard
    thruk_remove_panorama_dashboard("Arrow Element");

    testCase.endOfStep("panorama arrow widget", 120);
};

runTest($case);
