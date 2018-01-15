_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Hostgroup Status"));

    mouseClickXY(100,100);
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_link("save"));

    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_link("Yes"));

    testCase.endOfStep("panorama hostgroup icon", 20);
};

runTest($case);