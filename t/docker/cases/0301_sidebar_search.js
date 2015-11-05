_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();

    _setValue(_textbox("s0_value"), "loca");
    click(_textbox("s0_value"));
    env.sleep(1);
    isVisible(_listItem("1 Host"));
    click(_link("localhost"));
    isVisible(_div("Service Status Details For Host 'localhost'"));

    testCase.endOfStep("sidebar search", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
