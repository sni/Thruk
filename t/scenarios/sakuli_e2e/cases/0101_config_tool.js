_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();

    click(_link("Config Tool"));
    click(_link("Object settings"));

    click(_textbox("data.name"));
    click(_link("localhost"));

    isVisible(_textbox('obj.host_name'));
    _assertEqual("localhost", _getValue(_textbox("obj.host_name")));

    isVisible(_textbox('obj.address'));
    _setValue(_textbox("obj.address"), "127.0.0.5");

    // add custom by name
    click(_textbox("newattr"));
    _setValue(_textbox("newattr"), "worker");
    click(_link("add custom variable"));

    isVisible(_textbox("objkey.-1"));
    _assertEqual("_WORKER", _getValue(_textbox("objkey.-1")));

    isVisible(_textbox('obj._WORKER'));
    _setValue(_textbox("obj._WORKER"), "local");

    // add another custom variable
    click(_textbox("newattr"));
    click(_link("customvariable"));

    isVisible(_textbox("objkey.-2"));
    _assertEqual("_", _getValue(_textbox("objkey.-2")));
    _setValue(_textbox("objkey.-2"), "_TEST");

    click(_textarea("conf_comment"));
    _setValue(_textarea("conf_comment"), "test comment");

    isVisible(_textbox('obj._TEST'));
    _setValue(_textbox("obj._TEST"), "test");

    // hit apply button
    click(_submit("apply[1]"));
    isVisible(_span("Host changed successfully"));

    // check if everything was saved
    isVisible(_textbox("obj._WORKER"));
    _assertEqual("local", _getValue(_textbox("obj._WORKER")));

    isVisible(_textbox("obj._TEST"));
    _assertEqual("test", _getValue(_textbox("obj._TEST")));

    _assertEqual("127.0.0.5", _getValue(_textbox("obj.address")));

    // raw edit
    click(_submit("raw edit"));
    isVisible(_div("79"));
    _assertEqual("lineno lineselect", _div("79").className);
    _assertNotEqual("/ARRAY/", _getValue(_textarea("texteditor")));
    click(_link("save"));

    isVisible(_textbox("obj.host_name"));
    _assertEqual("localhost", _getValue(_textbox("obj.host_name")));

    // revert changes
    click(_link("Apply"));
    click(_submit("discard all unsaved changes"));
    isVisible(_span("Changes have been discarded"));
    isVisible(_cell("There are no pending changes."));

    testCase.endOfStep("config tool", 120);
};

runTest($case);
