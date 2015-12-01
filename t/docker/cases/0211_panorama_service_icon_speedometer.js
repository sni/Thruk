_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_button("add"));
    click(_span("Icons & Widgets"));
    click(_span("Service Status"));

    mouseClickXY(100,100);
    isVisible(_textbox('host'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem(0));
    isVisible(_textbox('service'));
    click(_div('/trigger/', _rightOf(_textbox('service'))));
    _setValue(_textbox("service"), "Example Check");
    click(_emphasis('Appearance'));
    isVisible(_textbox('type'));
    click(_div('/trigger/', _rightOf(_textbox('type'))));
    click(_listItem('/Speedometer/'));
    isVisible(_textbox('speedosource'));
    click(_div('/trigger/', _rightOf(_textbox('speedosource'))));
    click(_listItem('/Perf/'));
    click(_button("save"));

    screenRegion.find("speedometer.png").rightClick();
    click(_span("Refresh"));
    isVisible(_paragraph("Commands successfully submitted"));

    screenRegion.find("speedometer.png").rightClick();
    click(_span("Remove"));
    click(_button("Yes"));

    testCase.endOfStep("panorama service speedometer", 40);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
