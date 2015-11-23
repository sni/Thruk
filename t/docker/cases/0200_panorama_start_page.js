_dynamicInclude($includeFolder);
_include('../_include.js');

try {
    thruk_login();
    thruk_open_panorama();

    isVisible(_button($testUser));
    _assertEqual($testUser, _getText(_button($testUser)));
    _assertContainsText($testUser, _button($testUser));
    testCase.endOfStep("panorama start page", 20);

    thruk_panorama_logout();
} catch (e) {
    testCase.handleException(e);
} finally {
    testCase.saveResult();
}
