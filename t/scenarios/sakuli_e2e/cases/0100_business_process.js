_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();

    click(_link("Business Process"));

    /* Create Business Process */
    click(_link("create new business process"));
    isVisible(_span("business process sucessfully created"));
    rightClick(_span("Example Node"));
    click(_link("Edit Node"));
    click(_label("Dummy"));
    _setValue(_textbox("bp_label_fixed"), "Test Node");
    click(_label("Warning"));
    click(_button("Save"));
    isVisible(_div("WARNING"));
    click(_link("Business Process"));
    click(_span("(DRAFT)"));
    click(_submit("save changes"));
    isVisible(_span("business process updated sucessfully"));
    isVisible(_div("WARNING"));

    /* Test Mode */
    click(_link("Business Impact Analysis"));
    isVisible(_span("(Business-Impact-Analysis-Mode)"));
    rightClick(_span("Test Node"));
    _mouseOver(_link("Test Mode"));
    _click(_link("Critical"));
    isVisible(_div("CRITICAL"));
    isVisible(_div("testmode"));

    /* Remove Business Process */
    click(_link("List All Business Processes"));
    isVisible(_link("New Business Process"));
    click(_image("Edit Graph"));
    click(_link("Delete this Business Process"));
    isVisible(_span("business process sucessfully removed"));

    testCase.endOfStep("business process", 60);
};

runTest($case);
