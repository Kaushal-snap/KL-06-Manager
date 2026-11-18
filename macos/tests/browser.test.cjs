'use strict';
// Optional developer test: npm install --no-save playwright, then playwright install chromium.
// Test origin is deliberately local; this is browser UI verification, NOT a native Mac test.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict');
const path=require('node:path'),os=require('node:os');
const M=require('../Resources/model.js');
const ORIGIN=process.env.KL_PREVIEW_ORIGIN||'http://127.0.0.1:4185/';
(async()=>{
 const browser=await chromium.launch({headless:true});
 const page=await browser.newPage({viewport:{width:1440,height:1050},deviceScaleFactor:1});
 const errors=[],external=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('request',r=>{if(!r.url().startsWith(ORIGIN))external.push(r.url());});
 await page.goto(ORIGIN);
 await page.getByRole('heading',{name:'Your Mac. Clearly connected.'}).waitFor();
 assert.match(await page.locator('.mode-badge').innerText(),/DEMO · NOT LIVE/);
 assert.equal(await page.locator('.metric').count(),4);
 for(const id of M.pages){
   await page.locator(`.nav[data-page="${id}"]`).click();
   assert.equal(await page.locator('h1').count(),1);
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'page overflows '+id);
 }
 await page.locator('.nav[data-page="about"]').click();
 assert.match(await page.locator('.main-content').innerText(),/Available only in the running native app, not this browser preview/);
 // Playwright's key table does not include F13. This is a synthetic DOM event,
 // not OS input or verification of the Carbon shortcut on a Mac.
 await page.evaluate(()=>document.dispatchEvent(new KeyboardEvent('keydown',{key:'F13',code:'F13',bubbles:true})));
 assert.equal(await page.getByRole('heading',{name:'A companion. Not a replacement firmware.'}).count(),1,'browser must not claim a native F13 binding');
 await page.locator('.nav[data-page="tweaks"]').click();
 assert.equal(await page.locator('.setting-row').count(),12);
 await page.getByRole('button',{name:'Finder',exact:true}).click();
 assert.equal(await page.locator('.setting-row').count(),M.tweaks.filter(t=>t.group==='Finder').length);
 await page.locator('[data-action="tweak"]').first().click();
 assert.match(await page.getByRole('dialog').innerText(),/visual preview/);
 await page.getByRole('button',{name:'Got it',exact:true}).click();
 assert.equal(await page.getByRole('dialog').count(),0);
 await page.getByRole('button',{name:'Switch appearance'}).click();
 assert.equal(await page.locator('html.light').count(),1);
 await page.getByRole('button',{name:'Switch appearance'}).click();
 await page.locator('.nav[data-page="overview"]').click();
 await page.screenshot({path:process.env.KL_SCREENSHOT||path.join(os.tmpdir(),'KL-06-demo-preview.png'),fullPage:false});
 await page.setViewportSize({width:390,height:844});
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'mobile page overflows');
 for(const id of M.pages){
   await page.locator(`.nav[data-page="${id}"]`).click();
   assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'mobile overflow '+id);
 }
 assert.deepEqual(errors,[],'browser errors');assert.deepEqual(external,[],'unexpected external requests');
 // A separate browser context mocks the bridge only to check UI wiring and output escaping.
 const native=await browser.newPage({viewport:{width:1260,height:900}});
 native.on('pageerror',e=>errors.push(e.message));native.on('request',r=>{if(!r.url().startsWith(ORIGIN))external.push(r.url());});
 const fixture=M.demoState();fixture.mode='native';fixture.cpu.name='<img src=x onerror="alert(1)">';
 fixture.sampledUptimeSeconds=10;fixture.sampledAtUnix=1767225600;fixture.sampledAt='2026-01-01T00:00:00Z';fixture.hotkey={keyCode:105,modifiers:0,registered:true};fixture.fan={status:'ok',ageSeconds:0.1,queryDurationSeconds:0.01,reportedAt:'2026-01-01T00:00:00Z',source:'Synthetic test provider',fans:[{status:'ok',index:0,rpm:1900}],manualControl:false};
 await native.addInitScript(fixture=>{
   window.nativeCalls=[];window.testFixture=fixture;
   window.webkit={messageHandlers:{kl06:{postMessage(message){
     window.nativeCalls.push(message);
     if(message.method==='state'){fixture.sampledUptimeSeconds+=2;fixture.sampledAtUnix+=2;}
     let result=fixture;
     if(message.method==='setVolume'){fixture.volume=message.params.value;result='Volume updated (test mock).';}
     if(message.method==='openSetting')result='Opened (test mock).';
     if(message.method==='pickHistoryCSV')result={csvText:'Date,Time,CPU [RPM]\n1.1.2026,12:00:00.000,1000\n1.1.2026,12:00:02.000,2000'};
     if(message.method==='applyTweak'){fixture.tweaks.find(t=>t.id===message.params.id).saved=true;result='Applied (test mock).';}
     if(message.method==='restoreTweak'){fixture.tweaks.find(t=>t.id===message.params.id).saved=false;result='Restored (test mock).';}
     setTimeout(()=>window.KL06.receive({id:message.id,ok:true,result}),5);
   }}}};
 },fixture);
 await native.goto(ORIGIN);
 await native.getByRole('heading',{name:'Your Mac. Clearly connected.'}).waitFor();
 await native.locator('.nav[data-page="about"]').click();
 assert.match(await native.locator('.main-content').innerText(),/Registered: F13 alone \(virtual keyCode 105\)/);
 await native.evaluate(()=>{window.testFixture.hotkey.registered=false;});
 await native.getByRole('button',{name:'Refresh counters'}).click();
 await native.getByText(/Unavailable: macOS did not register the shortcut/).waitFor();
 await native.locator('.nav[data-page="performance"]').click();
 assert.match(await native.locator('.main-content').innerText(),/<img src=x/);
 assert.equal(await native.locator('.main-content img[src="x"]').count(),0,'native data must not become executable HTML');
 await native.locator('.nav[data-page="audio"]').click();
 await native.locator('#volume').fill('26');await native.locator('#volume').dispatchEvent('change');
 await native.waitForFunction(()=>window.nativeCalls.some(c=>c.method==='setVolume'&&c.params.value===26));
 await native.locator('.nav[data-page="tweaks"]').click();
 await native.locator('[data-action="tweak"]').first().click();
 await native.locator('[data-action="restore"]').first().waitFor();
 await native.locator('[data-action="restore"]').first().click();
 await native.waitForFunction(()=>window.nativeCalls.some(c=>c.method==='restoreTweak'));
 await native.locator('.nav[data-page="fan"]').click();
 await native.getByRole('heading',{name:'1900 RPM',exact:true}).waitFor();
 await native.evaluate(()=>{window.testFixture.fan.ageSeconds=20;});
 await native.getByRole('button',{name:'Refresh counters'}).click();
 await native.getByRole('heading',{name:'Fan RPM unavailable',exact:true}).waitFor();
 await native.locator('.nav[data-page="history"]').click();
 await native.getByRole('button',{name:'Import HWiNFO CSV',exact:true}).click();
 await native.getByText('2 timestamped rows',{exact:true}).waitFor();
 assert.match(await native.locator('.history-table').innerText(),/1500.00/);
 assert.equal(await native.locator('.historical-chart').count(),1);
 assert.match(await native.locator('.historical-chart').getAttribute('aria-label'),/historical device-clock timestamps/);
 await native.setViewportSize({width:390,height:844});
 assert.equal(await native.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'imported history mobile page overflows');
 assert.deepEqual(errors,[],'native-mock browser errors');assert.deepEqual(external,[],'native-mock external requests');
 await native.getByRole('button',{name:'Clear imported history',exact:true}).click();
 await native.getByRole('heading',{name:'No recording imported.',exact:true}).waitFor();
 await browser.close();console.log('PASS: 13-page navigation; 12 tweaks/filtering; honest demo action guard; theme; desktop/mobile overflow; no external requests; mocked native volume/apply/restore wiring; native-string HTML escaping; fresh/stale fan UI; timestamped history graph/import/clear; F13 demo/native-registered/unavailable status labels (not a real global-key test).');
})().catch(error=>{console.error(error);process.exit(1);});
