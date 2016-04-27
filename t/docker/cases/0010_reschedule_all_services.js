_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();

    click(_link("Hosts"));
    click(_link("select all[1]"));
    _assertNotTrue(_checkbox("force_check").checked);
    click(_submit("submit command for 2 hosts"));
    click(_link("Services"));
    click(_link("select all[1]"));
    _assertNotTrue(_checkbox("force_check").checked);
    click(_submit("submit command for 19 services"));

    click(_cell("ok_downtime"));
    click(_cell("critical_downtime"));
    click(_cell("warning_downtime"));
    click(_cell("unknown_downtime"));
    isVisible(_select("quick_command"));
    _setSelected(_select("quick_command"), "Add Downtime");
    _setValue(_textbox("com_data"), "Test Downtime");
    click(_submit("submit command for 4 services"));

    click(_cell("critical_ack"));
    click(_cell("warning_ack"));
    click(_cell("unknown_ack"));
    isVisible(_select("quick_command"));
    _setSelected(_select("quick_command"), "Add Acknowledgement");
    _setValue(_textbox("com_data"), "Test Acknowledgement");
    click(_submit("submit command for 3 services"));

    click(_link("Pending[1]"));
    isVisible(_div("1 of 1 Matching Service Entries Displayed"));

    click(_link("Problems"));
    isVisible(_div("3 of 3 Matching Service Entries Displayed"));
    isVisible(_div("0 of 0 Matching Host Entries Displayed"));

    testCase.endOfStep("reschedule all services", 60);

    thruk_logout();
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
