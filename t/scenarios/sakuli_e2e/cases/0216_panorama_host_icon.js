_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard('Dashboard');

    // add icon
    click(_link('add'));
    click(_span('Icons & Widgets'));
    click(_span('Host Status'));
    mouseClickXY(100,100);

    // set hostname
    isVisible(_textbox('host'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem('localhost'));

    // change label
    click(_link('Label'));
    _setValue(_textbox('labeltext'), 'Host: {{ name }}');
    isVisible(_link('Host: localhost'));
    click(_div('/trigger/', _rightOf(_textbox('bgcolor'))));
    click(_span("x-color-picker-item-inner[31]"));
    _assertEqual("#C0C0C0", _getText(_textbox("bgcolor")));

    // change hostname to see if label updates
    click(_link('General'));
    click(_div('/trigger/', _rightOf(_textbox('host'))));
    click(_listItem('test'));
    isVisible(_link('Host: test'));

    click(_link("save"));

    // remove icon
    screenRegion.waitForImage("green.png", 3).mouseMove();
    screenRegion.find("green.png").rightClick();
    click(_span('Remove'));
    click(_link('Yes'));

    testCase.endOfStep('panorama host icon', 40);
};

runTest($case);