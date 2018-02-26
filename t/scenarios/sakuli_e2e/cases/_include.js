var testCase      = new TestCase(180, 240);
var env           = new Environment();
var screenRegion  = new Region();
var $waitTimeout  = 5000;
var $testUser     = "omdadmin"
var $testPassword = "omd"
_set($testUser,     $testUser);
_set($testPassword, $testPassword);
_set($waitTimeout,  $waitTimeout);
_set($isChrome, _eval("_sahi._isChrome();"));
_set($isIE, _eval("_sahi._isIE();"));
if(isChrome()) {
    testCase.addImagePaths("../_images_chrome/");
} else if(isIE()) {
    testCase.addImagePaths("../_images_ie/");
} else {
    testCase.addImagePaths("../_images_firefox/");
}

_setSpeed(50);              // default is 100ms
env.setSimilarity(0.90);    // default is 0.7

function runTest($case) {
    try {
        $case();
    } catch (e) {
        /* uncomment to start console on errors*/
        //openDebugConsole();

        testCase.handleException(e);
    } finally {
        testCase.saveResult();
    }
}

function openDebugConsole() {
    env.type(Key.F11);
    _eval("_sahi.openController();");
    env.sleep(99999);
}

function mouseMoveXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.mouseMove();
}

function mouseClickXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.click();
}

function mouseRightClickXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.rightClick();
}

function thruk_login() {
    // workaround problem where login fails on first try
    var $lastUrl = testCase.getLastURL();
    _set($lastUrl, $lastUrl);
    _navigateTo($lastUrl+"cgi-bin/login.cgi");

    testCase.endOfStep("login page", 20);

    _setValue(_textbox("login"), $testUser);
    _setValue(_password("password"), $testPassword);

    click(_submit("Login"));

    isVisible(_link("Home"));

    // ensure fullscreen mode
    tryMultiple('!screenRegion.exists("applications.png", 1)', 'env.type(Key.F11)', 3, false);

    testCase.endOfStep("login", 20);
}

function thruk_logout() {
    click(_link("Logout"));
    isVisible(_textbox("login"));
    testCase.endOfStep("logout", 20);
}

function thruk_panorama_exit() {
    click(_link($testUser));
    click(_link("Exit Panorama View"));
    testCase.endOfStep("panorama exit", 20);
}

function thruk_panorama_logout() {
    thruk_panorama_exit();
    thruk_logout();
}

/* open panorama dashboard */
function thruk_open_panorama() {
    click(_link("Panorama View"));

    isVisible(_link($testUser));
    if(_isVisible(_link("Create New"), true)) {
        click(_link("Create New"));
        /* tests expect dashboard to be locked */
        rightClick(_link("Dashboard"));
        click(_span("Lock Dashboard"));
    }

    isVisible(_link("Dashboard"));
    _assertEqual("Dashboard", _getText(_link("Dashboard")));
    _assertContainsText("Dashboard", _link("Dashboard"));
}

/* unlock dashboard by name */
function thruk_unlock_dashboard($name) {
    if($name == undefined) { $name = "Dashboard"; }
    rightClick(_link($name));
    click(_span("Unlock Dashboard"));
    isVisible(_link("add"));
    testCase.endOfStep("panorama unlock", 20);
}

/* remove panorama dashboard */
function thruk_remove_panorama_dashboard($name) {
    click(_link($testUser));

    click(_span("Dashboard Management"));
    click(_link("My"));

    isVisible(_cell($name));
    click(_image("delete.png", _rightOf(_cell($name))));

    click(_link("Yes"));

    isNotVisible(_link($name));
    click(_image("/close/", _in(_div("/dashboardmanagementwindow/"))));
}

/* wrap click in a highlight */
function click($el, $combo) {
    _wait($waitTimeout, _assertExists($el));
    if(!_isVisible($el, true)) {
        try {
            _mouseOver($el, $combo);
        } catch(e) {};
    }
    isVisible($el, "red");
    _click($el, $combo);
}

/* wrap rightclick in a highlight */
function rightClick($el, $combo) {
    _wait($waitTimeout, _assertExists($el));
    if(!_isVisible($el, true)) {
        try {
            _mouseOver($el, $combo);
        } catch(e) {};
    }
    isVisible($el, "red");
    _rightClick($el, $combo);
}

/* wrap isVisible with a small wait */
function isVisible($el, $color) {
    if(!$color) { $color = "blue"; }
    _wait($waitTimeout, _isVisible($el, true));

    _assert(_isVisible($el, true));
    if(!_isVisible($el, true)) {
        _log("ERROR: "+$el+" is not visible");
        if(_exists($el)) {
            var $position = _position($el);
            _log("not visible but exists at "+$el+" at "+$position[0]+"/"+$position[1]);
            _call(_eval("document.body.appendChild(document.createElement('div'))").innerHTML = "<div style='position:absolute; width: 30px; height: 30px; left; "+$position[0]+"px; top: "+$position[1]+"px; border: 2px solid green;'></div>");
        }
    }
    if(!isChrome()) {
        // breaks chrome
        _highlight($el, $color);
    }
}

/* wrap !isVisible with a small wait */
function isNotVisible($el) {
    _wait(1000, !_isVisible($el));
    _assert(!_isVisible($el));
}

/* try something multiple times */
function tryMultiple($test, $action, $retries, $atLeastOnce) {
    for(var $x = 0; $x < $retries; $x++) {
        if($x > 0) {
            env.sleep(1);
        }
        if(($x == 0 && $atLeastOnce) || !eval($test)) {
            eval($action);
        } else {
            break;
        }
    }
}

function isChrome() {
    return($isChrome == true);
}

function isIE() {
    return($isIE == true);
}
