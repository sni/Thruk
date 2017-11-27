_dynamicInclude($includeFolder);
_include('../_include.js');

var $case = function() {
    thruk_login();
    thruk_open_panorama();

    isVisible(_link($testUser));
    _assertEqual($testUser, _getText(_link($testUser)));
    _assertContainsText($testUser, _link($testUser));
    testCase.endOfStep("panorama start page", 30);

    thruk_panorama_logout();
};

runTest($case);
