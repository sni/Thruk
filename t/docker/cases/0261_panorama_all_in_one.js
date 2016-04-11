_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    env.runCommand('cp /src/t/docker/99.tab /var/lib/thruk/panorama/99.tab');
    env.runCommand('chown www-data: /var/lib/thruk/panorama/99.tab');

    click(_button("", _rightOf(_button("Dashboard"))));
    click(_span("My Dashboards"));
    click(_span("All In One"));

    testCase.endOfStep("panorama all in one", 40);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
