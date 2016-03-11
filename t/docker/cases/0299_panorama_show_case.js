_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    click(_button("", _rightOf(_button("Dashboard"))));
    click(_span("New Dashboard"));

    // rename dashboard and change background image
    mouseRightClickXY(200,100);
    click(_span("Dashboard Settings"));
    isVisible(_textbox("title"));
    _assertEqual("Dashboard", _getValue(_textbox("title")));
    _setValue(_textbox("title"), "Showcase");
    click(_div('/trigger/', _rightOf(_textbox('background'))));
    click(_div("europa.png"));
    click(_button("save"));

    // add host icon for london
    click(_button("add"));
    click(_span("Icons & Widgets"));
    click(_span("Host Status"));
    mouseClickXY(160, 305);
    isVisible(_textbox('host'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem(0));

    // add label
    click(_button('Label'));
    isVisible(_textbox("labeltext"))
    _setValue(_textbox("labeltext"), "London: ");
    click(_button('/center/', _rightOf(_textbox('labeltext'))));
    click(_italic("perfdata.rta.val"));
    click(_italic("perfdata.rta.unit"));
    click(_button("save[1]"));
    click(_button("save"));

    isVisible(_link("/London:/"));

    click(_button("add"));
    click(_span("Icons & Widgets"));
    click(_span("Host Status"));
    mouseClickXY(420, 150);
    isVisible(_textbox('newcls'));
    click(_div('/trigger/', _rightOf(_textbox('newcls'))));
    click(_div("Hostgroup"));
    isVisible(_textbox('hostgroup'));
    click(_div('/trigger/', _rightOf(_textbox('hostgroup'))));
    click(_listItem(0));
    click(_button('/checkbox/', _rightOf(_label("Include Hosts:"))));
    click(_button('/Appearance/'));
    click(_div('/trigger/', _rightOf(_textbox('type'))));
    click(_listItem("Pie Chart"));
    isVisible(_textbox('piewidth'));
    _setValue(_textbox("piewidth"), "120");
    isVisible(_textbox('piedonut'));
    _setValue(_textbox("piedonut"), "40");
    //click(_button('/checkbox/', _rightOf(_label("Label Value:"))));
    click(_button("/checkbox/[6]"));
    click(_div('/up/', _rightOf(_textbox("piegradient"))));
    click(_div('/up/', _rightOf(_textbox("piegradient"))));
    click(_button("save"));

    testCase.endOfStep("panorama show case", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
