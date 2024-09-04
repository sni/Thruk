/*
 * save html/url/grafana dashboards as png / pdf
 *
 * usage: node puppeteer.js <url> <output file> <width> <height> <sessionid>
 *
 * docs: https://github.com/puppeteer/puppeteer/blob/main/docs/api.md
 *
 */

const puppeteer = require('puppeteer');
const os        = require('os');
const path      = require('path');


var url       = process.argv[2];
var output    = process.argv[3];
var width     = process.argv[4];
var height    = process.argv[5];
var sessionid = process.argv[6];
var is_report = process.argv[7];
var waitTimeout = 20000;

// Set XDG_CONFIG_HOME and XDG_CACHE_HOME if not already set (chrome >= ~ 128 does not start otherwise)
var tempDir = "";
if(process.env['OMD_ROOT']) {
  tempDir = path.join(process.env['OMD_ROOT'], 'tmp', 'thruk', 'puppeteer.cache');
} else {
  const userId  = process.getuid ? process.getuid() : '0000';
  tempDir = path.join(os.tmpdir(), `puppeteer.cache.${userId}`);
}
if (!process.env['XDG_CONFIG_HOME']) { process.env['XDG_CONFIG_HOME'] = tempDir; }
if (!process.env['XDG_CACHE_HOME'])  { process.env['XDG_CACHE_HOME']  = tempDir; }

(async () => {
  const browser = await puppeteer.launch({
          headless: "1", // keep old headless mode for now but disabled deprecation warning
          ignoreHTTPSErrors: true,
          args: [
              '--no-sandbox',
              '--disable-setuid-sandbox',
              '--window-size='+width+','+height
          ]
          // doesn't work: makes puppeteer twice as slow
          //,userDataDir: '/dev/null' // avoid leaking /tmp/puppeteer_dev_profile-xxxx folders https://github.com/puppeteer/puppeteer/issues/6414
  });
  const page = await browser.newPage();
  page.setViewport({width: Number(width), height: Number(height)});
  if(url.match(/^https?:/)) {
    await page.setCookie({name: "thruk_auth", value: sessionid, url: url});
  }
  page.on('response', (response) => {
    const status = response.status();
    if(status >= 500 && status <= 520) {
      console.error("url "+response.url()+" failed with status: "+status+". Aborting...");
      process.exit(2);
    }
    //console.debug("response:", response.url(), response.status());
  })
  await page.goto(url);
  if(url.match(/histou\.js\?/) || url.match(/\/grafana\//)) {
    await Promise.race([
      page.waitForSelector('#loginuser', {timeout: 0}).then(() => {
        console.error("login window present, export failed");
        process.exit(2);
      }),
      page.waitForSelector('div.alert-error', {timeout: 0}).then(async () => {
        console.error("alert message found, export failed");
        let element = await page.$('div.alert-error')
        let value = await page.evaluate(el => el.textContent, element)
        console.error(value);
        process.exit(2);
      }),
      page.waitForSelector('DIV.markdown-html H1', {timeout: 0}).then(async () => {
        console.error("alert message found, export failed:");
        let element = await page.$('DIV.markdown-html H1')
        let value = await page.evaluate(el => el.textContent, element)
        console.error(value);
        process.exit(2);
      }),
      page.waitForSelector('DIV.flot-text, p.panel-text-content, DIV.uplot', {timeout: waitTimeout}).then(() => {
        console.log("chart panel found, export OK");
      }, async () => {
        console.error("timeout while waiting for chart, export failed");
        process.exit(2);
      })
    ]);
  }


  await createScreenshot(output, page);
  await browser.close();
  process.exit(0);

  async function createScreenshot(output, page) {
    //console.debug("creating screenshot");
    if(output.match(/\.pdf$/)) {
      // pdf reports in din a4 format
      if(is_report == 1) {
        await page.emulateMediaType("print");
        await page.pdf({
          timeout: 600000, // se timeout to 10min
          format: 'A4',
          width: '210mm',
          height: '297mm',
          preferCSSPageSize: true,
          displayHeaderFooter: true,
          printBackground: true,
          margin: {
            top: 0,
            bottom: 0,
            left: 0,
            right: 0
          },
          path: output
        });
      } else {
        // other pages
        await page.emulateMediaType("screen");
        await page.pdf({
          timeout: 600000, // se timeout to 10min
          width: '1600px',
          height: '1200px',
          displayHeaderFooter: true,
          printBackground: true,
          margin: {
            top: 0,
            bottom: 0,
            left: 0,
            right: 0
          },
          path: output
        });
      }
    } else {
      await page.screenshot({path: output});
    }
  }

})();
