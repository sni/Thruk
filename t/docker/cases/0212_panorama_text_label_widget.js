_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_button("add"));
    click(_span("Icons & Widgets"));
    click(_span("Text Label"));

    mouseClickXY(100,100);

    mouseRightClickXY(100,100);
    click(_span("Settings"));
    isVisible(_textbox("labeltext"));
    _setValue(_textbox("labeltext"), "Test Label Text");

    click(_button("Layout"));
    isVisible(_textbox("x"));
    _assertNotEqual("0", _getValue(_textbox("x")));
    _assertNotEqual("",  _getValue(_textbox("x")));

    click(_button("save"));

    rightClick(_link("Test Label Text"));
    click(_span("Remove"));
    click(_button("Yes"));

    testCase.endOfStep("panorama text label widget", 30);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
