/*
 * save grafana dashboards as png
 *
 * usage: node puppeteer.js <url> <width> <height> <sessionid>
 *
 * docs: https://github.com/puppeteer/puppeteer/blob/main/docs/api.md
 *
 */

const puppeteer = require('puppeteer');

var url       = process.argv[2];
var output    = process.argv[3];
var width     = process.argv[4];
var height    = process.argv[5];
var sessionid = process.argv[6];

(async () => {
  const browser = await puppeteer.launch({
          headless: true,
          ignoreHTTPSErrors: true,
          args: [
              '--no-sandbox',
              '--disable-setuid-sandbox',
              '--window-size='+width+','+height
          ]
  });
  const page = await browser.newPage();
  page.setViewport({width: Number(width), height: Number(height)});
  await page.setCookie({name: "thruk_auth", value: sessionid, url: url});
  await page.goto(url);
  if(url.match(/histou\.js\?/) || url.match(/grafana\/dashboard/)) {
    await Promise.race([
      page.waitForSelector('#loginuser').then(() => {
        console.error("login window present, export failed");
        process.exit(2);
      }),
      page.waitForSelector('div.alert-error').then(() => {
        console.error("alert message found, export failed");
        process.exit(2);
      }),
      page.waitForSelector('DIV.flot-text', {timeout: 20000}).then(() => {
        console.log("chart panel found, export OK");
      }, () => {
        console.error("timeout while waiting for chart, export failed");
        process.exit(2);
      }),
      page.waitForSelector('p.panel-text-content', {timeout: 30000}).then(() => {
        console.log("text panel found, export OK");
      })
    ]);
  }
  console.log("creating screenshot");
  await page.screenshot({path: output});

  await browser.close();
})();
