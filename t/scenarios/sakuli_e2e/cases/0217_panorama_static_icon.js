_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Static Image"));

    mouseClickXY(100,100);

    isVisible(_textbox("src"));
    click(_div('/trigger/', _rightOf(_textbox('src'))));
    _setValue(_textbox("src"), "ok");
    click(_div("status/default/ok.png"));

    screenRegion.waitForImage("green.png", 3).mouseMove();

    click(_link("save"));

    screenRegion.waitForImage("green.png", 3).rightClick();
    click(_span("Remove"));
    click(_link("Yes"));

    testCase.endOfStep("panorama static image widget", 30);
};

runTest($case);