_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();

    click(_link("Reporting"));
    click(_link("create new report"));

    isVisible(_textbox('params.host'));
    _setValue(_textbox("params.host"), "localhost");
    click(_textbox("params.host"));
    isVisible(_span('1 host'));

    isVisible(_select("params.hostnameformat"));
    _setSelected(_select("params.hostnameformat"), "Alias");

    click(_submit("Create Report"));

    click(_image("Refresh Report"));
    isVisible(_div("job_time"));

    _wait(30000, _isVisible(_image("View Report Preview"), true));
    click(_image("View Report Preview"));

    _wait(3000, _assert(_popup("SLA Report")));
    _popup("SLA Report")._assertExists(_div("New Report"));
    _popup("SLA Report")._assertExists(_tableHeader("Report Timeperiod:"));
    _popup("SLA Report")._closeWindow();

    testCase.endOfStep("reporting", 120);
};

runTest($case);
