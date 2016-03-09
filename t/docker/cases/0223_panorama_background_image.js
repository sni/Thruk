_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    click(_button("", _rightOf(_button("Dashboard"))));
    click(_span("New Dashboard"));

    click(_button("add"));
    click(_span("Icons & Widgets"));
    click(_span("Hostgroup Status"));
    mouseClickXY(20,30);
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_button("save"));

    // rename dashboard and change background image
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "Background Image Test");
    click(_div('/trigger/', _rightOf(_textbox('background'))));
    _click(_div("europa.png"));

    _setValue(_textbox('backgroundoffset_x'), "8");
    _setValue(_textbox('backgroundoffset_y'), "8");

    click(_div('/up/', _rightOf(_textbox('backgroundoffset_x'))));
    click(_div('/up/', _rightOf(_textbox('backgroundoffset_y'))));

    _assertEqual("9 px", _getValue(_textbox("backgroundoffset_x")));
    _assertEqual("9 px", _getValue(_textbox("backgroundoffset_y")));

    click(_textbox('backgroundoffset_x'));
    _keyPress(_textbox('backgroundoffset_x'), 38);

    click(_textbox('backgroundoffset_y'));
    _keyPress(_textbox('backgroundoffset_y'), 38);

    _setValue(_textbox('backgroundscale'), "39");
    click(_div('/up/', _rightOf(_textbox('backgroundscale'))));
    _assertEqual("40 %", _getValue(_textbox("backgroundscale")));

    click(_button("save"));
    screenRegion.waitForImage("island_map_green_offset.png", 3).mouseMove();

    testCase.endOfStep("panorama background I", 60);

    thruk_panorama_exit();
    thruk_open_panorama();
    screenRegion.waitForImage("island_map_green_offset.png", 3).mouseMove();

    // remove dashboard
    thruk_remove_panorama_dashboard("Background Image Test");

    testCase.endOfStep("panorama background II", 60);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
