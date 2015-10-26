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
        options.width   = Number(options.width);
        options.height  = Number(options.height);
        page.zoomFactor = 1;
        page.viewportSize = {
            width:  options.width,
            height: options.height
        };
        if(options.format && options.format == 'pdf') {
            // check if the margin is required for phantomjs 2 too
            page.paperSize = { width: options.width+140, height: options.height+50, margin: 0 }
        }
    }

    if(options.cookie) {
        var c = options.cookie.match(/^([^,]+),(.*)$/);
        var domain = input.match(/https?:\/\/([^/:]+)/);
        phantom.addCookie({
          'domain'   : domain[1],
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
            if(input.match(/histou\.js\?/)) {
                var retries = 0;
                window.setInterval(function () {
                    retries++;
                    if(checkGrafanaLoaded() || retries > 100) {
                        page.render(output, {format: options.format, quality: 100});
                        phantom.exit();
                    }
                }, 100);
            } else {
                window.setTimeout(function () {
                    page.render(output, {format: options.format, quality: 100});
                    phantom.exit();
                }, 3000);
            }
        }
    });
}

function checkGrafanaLoaded() {
    var chartEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('DIV.flot-text'), function(el) {
            return el.className;
        });
    });
    if(chartEl.length == 0) {
        return(false);
    }
    var loadingEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('span.panel-loading'), function(el) {
            return el.className;
        });
    });
    if(loadingEl.length > 0 && loadingEl[0].match(/ng-hide/)) {
        return(true);
    }
    return(false);
}
