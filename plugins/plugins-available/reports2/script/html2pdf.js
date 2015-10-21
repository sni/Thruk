var page = require('webpage').create(),
    system = require('system'),
    version = phantom.version.major,
    input, output;

if (version == 2) {
    // pdf sizing workarounds for phantomjs 2.0.0
    page.paperSize = { width: "21.8cm", height: "30.9cm", margin: '0px' }
} else {
    page.paperSize = { format: 'A4', orientation: 'portrait', margin: '0'  }
    // workaround for html page being too small
    page.zoomFactor = 1.4;
}

if (system.args.length < 3) {
    console.log('Usage: html2pdf.js INPUT.html OUTPUT.pdf [<options>]');
    phantom.exit(1);
} else {
    var args    = [];
    var options = {}
    system.args.forEach(function(arg, i) {
        var matches = arg.match(/^--([^=]+)=(.*)$/);
        if(matches) {
            options[matches[1]] = matches[2];
        } else {
            args.push(arg);
        }
    });
    input  = args[1];
    output = args[2];

    if(options.width && options.height) {
        page.paperSize  = undefined;
        page.zoomFactor = 1;
        page.viewportSize = {
            width:  options.width*1.3,
            height: options.height*2
        };
    }

    if(options.cookie) {
        var c = options.cookie.match(/^([^,]+),(.*)$/);
        phantom.addCookie({
          'domain'   : 'mo.nierlein.de',
          'name'     : c[1],
          'value'    : c[2],
          'path'     : '/'
        });
    }

    page.open(input, function (status) {
        if (status !== 'success') {
            console.log('Unable to load the input file!');
            phantom.exit(1);
        } else {
            window.setTimeout(function () {
                page.render(output);
                phantom.exit();
            }, 2000);
        }
    });
}
