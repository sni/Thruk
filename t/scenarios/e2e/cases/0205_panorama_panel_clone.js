_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();
    thruk_unlock_dashboard("Dashboard");

    click(_link("add"));
    click(_span("Site Status"));

    isVisible(_div("demo"));

    click(_image("/x-tool-restore/"));
    mouseClickXY(300,100);

    click(_image("/x-tool-close/"));
    env.sleep(1);
    click(_image("/x-tool-close/"));

    testCase.endOfStep("panorama panel clone", 30);
};

runTest($case);
