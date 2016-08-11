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
    click(_div('/Performance Bar/'));

    isVisible(_image('thermok.png'));
    click(_button("save"));

    isVisible(_image('thermok.png'));

    screenRegion.find("perfbar.png").rightClick();
    click(_span("Refresh"));
    isVisible(_paragraph("Commands successfully submitted"));

    screenRegion.find("perfbar.png").rightClick();
    click(_span("Remove"));
    click(_button("Yes"));

    testCase.endOfStep("panorama service performance bar", 40);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
