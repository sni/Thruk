_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

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

    testCase.endOfStep("panorama hostgroup icon", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
