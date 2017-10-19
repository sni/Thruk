_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Icons & Widgets"));
    click(_span("Host Status"));

    mouseClickXY(50,50);
    isVisible(_textbox('host'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem(0));
    click(_link("save"));

    screenRegion.find("green.png").rightClick();
    click(_span("Clone"));
    mouseClickXY(100,100);

    screenRegion.find("green.png").rightClick();
    click(_span("Clone"));
    mouseClickXY(50,100);

    screenRegion.find("green.png").rightClick();
    click(_span("Clone"));
    mouseClickXY(100,50);

    /* set background */
    rightClick(_link("Dashboard"));
    click(_span("Dashboard Settings"));
    isVisible(_textbox('background'));
    click(_div('/trigger/', _rightOf(_textbox('background'))));
    click(_div("europa.png"));
    click(_link("save"));

    screenRegion.waitForImage("island_green.png", 3).mouseMove();
    testCase.endOfStep("panorama icon clone, part 1", 60);

    thruk_panorama_exit();
    thruk_open_panorama();
    screenRegion.waitForImage("island_green.png", 3).mouseMove();

    thruk_unlock_dashboard("Dashboard");

    /* remove background */
    rightClick(_link("Dashboard"));
    click(_span("Dashboard Settings"));
    click(_div('/trigger/', _rightOf(_textbox('background'))));
    click(_div("none"));
    click(_link("save"));

    /* remove icons */
    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_link("Yes"));
    env.sleep(1);

    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_link("Yes"));
    env.sleep(1);

    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_link("Yes"));
    env.sleep(1);

    screenRegion.find("green.png").rightClick();
    click(_span("Remove"));
    click(_link("Yes"));

    isNotVisible(_div("x-surface x-surface-default"));

    testCase.endOfStep("panorama icon clone, part 2", 60);
};

runTest($case);