var page = require('webpage').create(),
    system = require('system'),
    version = phantom.version.major,
    input, output, width, height;

page.settings.resourceTimeout = 5000;
page.onResourceTimeout = function(e) {
  console.log(e.errorCode);
  console.log(e.errorString);
  console.log(e.url);
  phantom.exit(1);
};

if (system.args.length != 8) {
    console.log('Usage: html2pdf.js SITE SESSIONCOOKIE WIDTH HEIGHT MAPURL OUTPUT.png');
    phantom.exit(1);
} else {
    site    = system.args[1];
    console.log("site: " + site);
    cookie  = system.args[2];
    console.log("cookie: " + cookie);
    width   = system.args[3];
    height  = system.args[4];
    zoom    = system.args[5];
    input   = system.args[6];
    console.log("input: " + input);
    output  = system.args[7];

    phantom.addCookie({
      'name'     : 'thruk_auth',   /* required property */
      'value'    : cookie,  /* required property */
      'path'     : site,                /* required property */
      'expires'  : 'Session'
    });

    page.viewportSize = { width: width, height: height };
    page.clipRect = { top: 0, left: 0, width: width, height: height };
    page.zoomFactor = zoom;

    page.open(input, function (status) {
        if (status !== 'success') {
            console.log('Unable to load the input file!');
            phantom.exit(1);
        } else {
            window.setTimeout(function () {
                page.render(output);
                phantom.exit();
            }, 200);
        }
    });
}
