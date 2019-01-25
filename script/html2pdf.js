var page = require('webpage').create(),
    system = require('system'),
    version = phantom.version.major,
    input, output;

if (version >= 2) {
    // pdf sizing workarounds for phantomjs 2.0.0
    page.paperSize = { width: "21.8cm", height: "30.9cm", margin: '0px' }
} else {
    page.paperSize = { format: 'A4', orientation: 'portrait', margin: '0'  }
    // workaround for html page being too small
    page.zoomFactor = 1.4;
}

function debug(something) {
    // uncomment to enable debug output
    //console.log(something);
}

debug('html2pdf.js starting');

if (system.args.length < 3) {
    console.log('Usage: html2pdf.js INPUT.html OUTPUT.pdf [<options>]');
    console.log('');
    console.log('Options:');
    console.log('  --width=<width>       (in px)');
    console.log('  --height=<height>     (in px)');
    console.log('  --format=<pdf|png>');
    console.log('  --autoscale');
    console.log('  --cookie=<name>,<value>');
    console.log('  --header=<name>:<value>');
    phantom.exit(1);
} else {
    var args    = [];
    var options = {}
    system.args.forEach(function(arg, i) {
        var matches = arg.match(/^--([^=]+)=(.*)$/);
        if(matches) {
            if(matches[1] == "cookie" || matches[1] == "header") {
                if(!options[matches[1]]) {
                    options[matches[1]] = [];
                }
                options[matches[1]].push(matches[2]);
            } else {
                options[matches[1]] = matches[2];
            }
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

    // add custom cookies
    if(options.cookie) {
        var domain = input.match(/https?:\/\/([^/:]+)/);
        options.cookie.forEach(function(cookie, i) {
            var c = cookie.match(/^([^,]+),(.*)$/);
            phantom.addCookie({
              'domain'   : domain[1],
              'name'     : c[1],
              'value'    : c[2],
              'path'     : '/'
            });
        });
    }

    // add custom http header
    if(options.header) {
        if(!page.customHeaders) {
            page.customHeaders = {};
        }
        options.header.forEach(function(header, i) {
            var c = header.match(/^([^:]+):\ *(.*)$/);
            page.customHeaders[c[1]] = c[2];
        });
    }

    debug('page open: '+input);
    page.open(input, function (status) {
        debug('page ready: '+status);
        if(options.autoscale) {
            page.evaluate(function() {
                // see https://github.com/ariya/phantomjs/issues/12685
                // and http://stackoverflow.com/questions/24525561/phantomjs-fit-content-to-a4-page
                document.querySelector('body').style.zoom = "0.55";
            });
        }
        if (status !== 'success') {
            console.log('Unable to load the input file!');
            phantom.exit(1);
        } else {
            if(input.match(/histou\.js\?/) || input.match(/grafana\/dashboard/)) {
                var retries = 0;
                window.setInterval(function () {
                    retries++;
                    // wait up to 20 seconds
                    if(checkGrafanaLoaded() || retries > 400) {
                        debug('page render');
                        page.render(output, {format: options.format, quality: 100});
                        debug('page render done');
                        phantom.exit();
                    }
                }, 50);
            } else {
                window.setTimeout(function () {
                    debug('page render');
                    page.render(output, {format: options.format, quality: 100});
                    debug('page render done');
                    phantom.exit();
                }, 3000);
            }
        }
    });
}

function checkGrafanaLoaded() {
    debug("checkGrafanaLoaded");
    var textErrorEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('p.panel-text-content'), function(el) {
            return el.className;
        });
    });
    if(textErrorEl.length > 0) {
        debug('p.panel-text-content found, export finished');
        return(true);
    }
    var textErrorEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('#loginuser'), function(el) {
            return el.className;
        });
    });
    if(textErrorEl.length > 0) {
        debug('#loginuser found, export failed');
        return(true);
    }
    var textErrorEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('div.alert-error'), function(el) {
            return el.className;
        });
    });
    if(textErrorEl.length > 0) {
        debug('div.alert-error found, export failed');
        return(true);
    }
    var chartEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('DIV.flot-text'), function(el) {
            return el.className;
        });
    });
    if(chartEl.length == 0) {
        debug('div.flot-text not found, export still running');
        return(false);
    }
    var loadingEl = page.evaluate(function() {
        return [].map.call(document.querySelectorAll('span.panel-loading'), function(el) {
            return el.className;
        });
    });
    if(loadingEl.length > 0 && loadingEl[0].match(/ng-hide/)) {
        debug('hidden span.panel-loading found, export finished');
        return(true);
    }
    if(chartEl.length > 0 && loadingEl.length == 0) {
        debug('export finished, no loading element but a float-text present');
        return(true);
    }
    return(false);
}
