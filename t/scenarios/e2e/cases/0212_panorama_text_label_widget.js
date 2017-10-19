_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Text Label"));

    mouseClickXY(100,100);

    mouseRightClickXY(100,100);
    click(_span("Settings"));
    isVisible(_textbox("labeltext"));
    _setValue(_textbox("labeltext"), "Test Label Text");

    click(_link("Layout"));
    isVisible(_textbox("x"));
    _assertNotEqual("0", _getValue(_textbox("x")));
    _assertNotEqual("",  _getValue(_textbox("x")));

    click(_link("save"));

    rightClick(_link("Test Label Text"));
    click(_span("Remove"));
    click(_link("Yes"));

    testCase.endOfStep("panorama text label widget", 30);
};

runTest($case);