_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    click(_link("Services"));

    click(_submit("/add_bookmark/"));
    isVisible(_textbox("newname"));
    _setValue(_textbox("newname"), "Test Bookmark");
    click(_select("section"));
    _setSelected(_select("section"), "General");
    click(_submit("add bookmark"));

    isVisible(_link("Test Bookmark"));
    click(_submit("/add_bookmark/"));
    click(_link("Remove Bookmarks"));
    click(_imageSubmitButton("delete"));
    click(_submit("save changes"));

    isNotVisible(_link("Test Bookmark"));

    click(_link("Problems"));
    click(_submit("/show_link/"));
    isVisible(_textbox("url_input"));
    _assertEqual("/^http:/", _getValue(_textbox("url_input")));
    _assertNotEqual("/&amp;/", _getValue(_textbox("url_input")));

    testCase.endOfStep("bookmarks", 30);
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
