_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    // open context menu
    mouseRightClickXY(100,100);
    click(_span("Unlock Dashboard"));

    // open context menu again
    mouseRightClickXY(100,100);
    isVisible(_span("Lock Dashboard"));

    // close by clicking somewhere
    mouseClickXY(50,100);
    isNotVisible(_span("Lock Dashboard"));

    click(_button("add"));
    isVisible(_span("Icons & Widgets"));

    mouseClickXY(50,100);
    isNotVisible(_span("Icons & Widgets"));

    testCase.endOfStep("panorama basic controls", 20);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
