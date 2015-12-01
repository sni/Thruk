_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_button("add"));
    click(_span("Site Status"));

    isVisible(_div("Naemon"));

    click(_image("x-tool-restore"));
    mouseClickXY(300,100);

    click(_image("x-tool-close"));
    env.sleep(1);
    click(_image("x-tool-close"));

    testCase.endOfStep("panorama panel clone", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
