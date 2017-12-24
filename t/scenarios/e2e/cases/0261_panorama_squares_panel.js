_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Squares"));

    isVisible(_div("localhost"));

    click(_image("/x-tool-refresh/"));

    click(_image("/x-tool-gear/"));
    click(_div('/trigger/', _rightOf(_textbox('source'))));
    _click(_listItem("Hosts & Services"));
    click(_link("save"));

    isVisible(_div("localhost - PING"));

    screenRegion.waitForImage("squares.png", 3).mouseMove();

    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama squares panel", 30);
};

runTest($case);