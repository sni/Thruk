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
    click(_div('/Trend Icon/'));

    isVisible(_textbox('trendiconset'));
    click(_div('/trigger/', _rightOf(_textbox('trendiconset'))));
    click(_div('/default_64/'));

    isVisible(_textbox('trendsource'));
    click(_div('/trigger/', _rightOf(_textbox('trendsource'))));
    click(_listItem('/Perf/'));

    screenRegion.waitForImage("neutral_trend.png", 3).mouseMove();

    click(_div('/trigger/', _rightOf(_textbox('trendfunctionvs'))));
    click(_listItem('/fixed/'));
    isVisible(_textbox('trendfixedvs'));
    _setValue(_textbox('trendfixedvs'), "4.7");
    screenRegion.waitForImage("bad.png", 3).mouseMove();

    isVisible(_textbox('trendfixedvs'));
    _setValue(_textbox('trendfixedvs'), "5.3");
    screenRegion.waitForImage("good.png", 3).mouseMove();

    isVisible(_textbox('trendfixedvs'));
    _setValue(_textbox('trendfixedvs'), "10");

    click(_button("save"));

    screenRegion.find("very_good.png").rightClick();
    click(_span("Refresh"));
    isVisible(_paragraph("Commands successfully submitted"));

    screenRegion.find("very_good.png").rightClick();
    click(_span("Remove"));
    click(_button("Yes"));

    testCase.endOfStep("panorama service trend icon", 60);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
