_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();

    click(_textbox("s0_value"));
    env.type("local");
    isVisible(_listItem("1 Host"));
    click(_link("localhost"));
    isVisible(_div("Service Status Details For Host 'localhost'"));

    testCase.endOfStep("sidebar search", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
