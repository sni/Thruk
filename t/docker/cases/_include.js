var testCase      = new TestCase(180, 240);
var env           = new Environment();
var screenRegion  = new Region();
var $waitTimeout  = 5000;
var $testUser     = "thrukadmin"
var $testPassword = "thrukadmin"
_set($testUser,     $testUser);
_set($testPassword, $testPassword);
_set($waitTimeout,  $waitTimeout);
testCase.addImagePaths("../_images/");

_setSpeed(50);              // default is 100ms
env.setSimilarity(0.92);    // default is 0.7

function mouseClickXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.click();
}

function mouseRightClickXY($x, $y) {
    var region = new RegionRectangle($x-10,$y-10,$x+10,$y+10);
    region.rightClick();
}

function thruk_login() {
    _navigateTo("http://localhost/thruk");
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
    click(_button($testUser));
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

    if(_isVisible(_link("Create New"))) {
        click(_link("Create New"));
    }

    isVisible(_emphasis("Dashboard"));
    _assertEqual("Dashboard", _getText(_emphasis("Dashboard")));
    _assertContainsText("Dashboard", _emphasis("Dashboard"));
}

/* unlock dashboard by name */
function thruk_unlock_dashboard($name) {
    if($name == undefined) { $name = "Dashboard"; }
    rightClick(_emphasis($name));
    click(_span("Unlock Dashboard"));
    isVisible(_button("add"));
    testCase.endOfStep("panorama unlock", 20);
}

/* remove panorama dashboard */
function thruk_remove_panorama_dashboard($name) {
    isVisible(_button($name));
    click(_button("", _rightOf(_button($name))));

    click(_span("Dashboard Management", _near(_span("New Dashboard"))));
    click(_button("My"));

    isVisible(_cell($name));
    click(_image("delete.png", _rightOf(_cell($name))));

    click(_button("Yes"));

    isNotVisible(_button($name));
    click(_image("/close/", _in(_div("/dashboardmanagementwindow/"))));
}

/* wrap click in a highlight */
function click($el, $combo) {
    _wait($waitTimeout, _assertExists($el));
    try {
        _mouseOver($el, $combo);
    } catch(e) {};
    isVisible($el, "red");
    _click($el, $combo);
}

/* wrap rightclick in a highlight */
function rightClick($el, $combo) {
    _wait($waitTimeout, _assertExists($el));
    try {
        _mouseOver($el, $combo);
    } catch(e) {};
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
        //env.sleep(60);
    }
    _highlight($el, $color);
}

/* wrap !isVisible with a small wait */
function isNotVisible($el) {
    _wait($waitTimeout, !_isVisible($el));
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
