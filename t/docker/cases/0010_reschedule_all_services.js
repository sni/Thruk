_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();

    click(_link("Hosts"));
    click(_link("select all[1]"));
    _assertNotTrue(_checkbox("force_check").checked);
    click(_checkbox("force_check"));
    click(_submit("submit command for 1 host"));
    click(_link("Services"));
    click(_link("select all[1]"));
    _assertNotTrue(_checkbox("force_check").checked);
    click(_checkbox("force_check"));
    click(_submit("submit command for 6 services"));

    env.sleep(5);

    click(_link("Pending[1]"));
    isVisible(_div("0 Matching Service Entries Displayed"));

    click(_link("Problems"));
    isVisible(_div("0 of 0 Matching Service Entries Displayed"));
    isVisible(_div("0 of 0 Matching Host Entries Displayed"));

    testCase.endOfStep("reschedule all services", 30);

    thruk_logout();
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
