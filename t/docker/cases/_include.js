var testCase      = new TestCase(90, 120);
var env           = new Environment();
var screenRegion  = new Region();
var $waitTimeout  = 10000;
var $testUser     = "thrukadmin"
var $testPassword = "thrukadmin"
_set($testUser,     $testUser);
_set($testPassword, $testPassword);
_set($waitTimeout,  $waitTimeout);
testCase.addImagePaths("../_images/");

_setSpeed(50);              // default is 100ms
env.setSimilarity(0.9);     // default is 0.7

function mouseClickXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.click().sleep(1);
}

function mouseRightClickXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.rightClick().sleep(1);
}

function thruk_login() {
    _navigateTo("http://localhost/thruk");
    testCase.endOfStep("login page", 20);

    _setValue(_textbox("login"), $testUser);
    _setValue(_password("password"), $testPassword);

    // ensure fullscreen mode
    tryMultiple('!screenRegion.exists("applications.png", 1)', 'env.type(Key.F11)', 3, false);

    click(_submit("Login"));

    isVisible(_link("Home"));
    testCase.endOfStep("login", 20);
}

function thruk_logout() {
    click(_link("Logout"));
    isVisible(_textbox("login"));
    testCase.endOfStep("logout", 20);
}

function thruk_panorama_exit() {
    click(_button($testUser));
    click(_link("Exit Panorama View"));
    testCase.endOfStep("panorama exit", 20);
}

function thruk_panorama_logout() {
    thruk_panorama_exit();
    thruk_logout();
}

function thruk_open_panorama() {
    click(_link("Panorama View"));

    isVisible(_emphasis("Dashboard"));
    _assertEqual("Dashboard", _getText(_emphasis("Dashboard")));
    _assertContainsText("Dashboard", _emphasis("Dashboard"));
}

function thruk_unlock_dashboard($name) {
    if($name == undefined) { $name = "Dashboard"; }
    rightClick(_emphasis($name));
    click(_span("Unlock Dashboard"));
    isVisible(_button("add"));
    testCase.endOfStep("panorama unlock", 20);
}

/* wrap click in a highlight */
function click($el, $combo) {
    _wait($waitTimeout, _assertExists($el));
    _mouseOver($el, $combo);
    isVisible($el, "red");
    _click($el, $combo);
}

/* wrap rightclick in a highlight */
function rightClick($el, $combo) {
    _wait($waitTimeout, _assertExists($el));
    _mouseOver($el, $combo);
    isVisible($el, "red");
    _rightClick($el, $combo);
}

/* wrap isVisible with a small wait */
function isVisible($el, $color) {
    if(!$color) { $color = "blue"; }
    _wait($waitTimeout, _isVisible($el));
    _assert(_isVisible($el));
    _highlight($el, $color);
}

/* wrap !isVisible with a small wait */
function isNotVisible($el) {
    _wait($waitTimeout, !_isVisible($el));
    _assert(!_isVisible($el));
}


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