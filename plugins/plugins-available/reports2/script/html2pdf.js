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

if (system.args.length != 3) {
    console.log('Usage: html2pdf.js INPUT.html OUTPUT.pdf');
    phantom.exit(1);
} else {
    input  = system.args[1];
    output = system.args[2];

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
