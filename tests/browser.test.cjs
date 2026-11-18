'use strict';
// Chromium UI + mocked native bridges only: not WebView2/Android/iOS device validation.
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const assert=require('node:assert/strict');
const ORIGIN=process.env.KL_COMMON_PREVIEW_ORIGIN||'http://127.0.0.1:4186/';
const pages=['device','controls','display','audio','storage','fan','history','laptop','privacy'];
(async()=>{
 const browser=await chromium.launch({headless:true});const errors=[],external=[];
 function observe(page){page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(!r.url().startsWith(ORIGIN))external.push(r.url());});}
 const demo=await browser.newPage({viewport:{width:1400,height:1000}});observe(demo);await demo.goto(ORIGIN);
 await demo.getByRole('heading',{name:'Your device. Clearly connected.'}).waitFor();assert.match(await demo.locator('header').innerText(),/DEMO · NOT LIVE/);
 for(const id of pages){await demo.locator(`button[data-page="${id}"]`).click();assert.equal(await demo.locator('h1').count(),1);assert.equal(await demo.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'desktop overflow '+id);}
 await demo.locator('button[data-page="history"]').click();await demo.locator('[data-action="history-import"]').click();await demo.getByText('Browser preview only. No system control or connection was made.',{exact:true}).waitFor();
 await demo.setViewportSize({width:390,height:844});for(const id of pages){await demo.locator(`button[data-page="${id}"]`).click();assert.equal(await demo.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,'phone demo overflow '+id);}
 for(const platform of ['windows','android','ios']){
  const page=await browser.newPage({viewport:{width:platform==='windows'?1350:390,height:900}});observe(page);
  await page.addInitScript(platform=>{
   const fixture={platform,version:'0.3.0-beta.2',build:5,sampledAt:'Synthetic native-bridge test, not a physical device',battery:{chargePercent:58,onAC:false},cpu:{loadPercent:17,source:'Synthetic native counter'},memory:{totalGB:8,usedGB:3.5},storage:{totalGB:200,freeGB:100},volume:42,brightness:60,awake:false,capabilities:{volume:platform!=='ios',nativeVolume:platform==='ios',brightness:platform!=='windows',brightnessScope:'Synthetic scope',awake:true},companion:{paired:false,running:false},tweaks:platform==='windows'?[{id:'win-extensions',saved:false,conflict:false,managed:false,blocked:false}]:[]};
   window.nativeCalls=[];window.nativeFixture=fixture;let listener;
   const post=raw=>{
    const msg=typeof raw==='string'?JSON.parse(raw):raw;window.nativeCalls.push(msg);let result=structuredClone(fixture);
    if(msg.method==='setVolume'){fixture.volume=msg.params.value;result='Local volume mock read back.';}
    if(msg.method==='setBrightness'){fixture.brightness=msg.params.value;result='Local brightness mock read back.';}
    if(msg.method==='applyTweak'){fixture.tweaks[0].saved=true;result='Mock applied.';}
    if(msg.method==='restoreTweak'){fixture.tweaks[0].saved=false;result='Mock restored.';}
    if(msg.method==='keepAwake'){fixture.awake=!fixture.awake;result='Temporary mock idle assertion.';}
    if(msg.method==='pickHistoryCSV')result={csvText:'Date,Time,CPU [RPM],Private\n1.1.2020,1:2:3,2994,SYNTHETIC-PRIVATE-CANARY\n1.1.2020,1:2:5,4252,SYNTHETIC-PRIVATE-CANARY\n,,ASUS NB EC SYNTHETIC-PRIVATE-CANARY,'};
    if(msg.method==='pairLaptop')result={status:'Mock awaits laptop approval.'};
    if(msg.method==='finishPairing'){fixture.companion.paired=true;result={status:'Paired (synthetic test only).'};}
    if(msg.method==='disconnectLaptop'){fixture.companion.paired=false;result='Disconnected test.';}
    if(msg.method==='remoteState')result={protocol:'KL06_COMPANION_V1',status:'fresh',validForSeconds:12,state:{platform:'macos',sampledAt:'Synthetic remote snapshot',volume:37,battery:{chargePercent:61},memory:{usedGB:4,totalGB:8},storage:{freeGB:50},fan:{status:'ok',ageSeconds:1,source:'Synthetic test provider',fans:[{status:'ok',index:0,rpm:3366}]},tweaks:[{id:'dock-autohide',saved:false}]}};
    if(msg.method==='remoteCommand')result={status:'awaiting-laptop-confirmation'};
    if(msg.method==='remoteResult')result={status:'awaiting-laptop-confirmation'};
    if(msg.method==='startCompanion'){fixture.companion.running=true;result='Mock host started.';}
    if(msg.method==='stopCompanion'){fixture.companion.running=false;result='Mock host stopped.';}
    if(msg.method==='companionDetails')result='Pairing details mocked only in native dialog; no secret returned.';
    if(msg.method==='showNativeVolume')result='Native volume mock shown.';
    if(msg.method==='state'&&window.stopStateResponses)return;
    setTimeout(()=>{const reply={id:msg.id,ok:true,result};if(platform==='windows')listener({data:reply});else window.KL06.receive(reply);},5);
   };
   if(platform==='windows'){window.chrome=window.chrome||{};window.chrome.webview={postMessage:post,addEventListener(_,callback){listener=callback;}};}
   if(platform==='android')window.KLNative={postMessage:post};
   if(platform==='ios')window.webkit={messageHandlers:{kl06mobile:{postMessage:post}}};
  },platform);
  await page.goto(ORIGIN);await page.getByRole('heading',{name:'Your device. Clearly connected.'}).waitFor();assert.match(await page.locator('header').innerText(),/NATIVE · CAPABILITY-GATED/);
  for(const id of pages){await page.locator(`button[data-page="${id}"]`).click();assert.equal(await page.locator('h1').count(),1);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,platform+' overflow '+id);}
  await page.locator('button[data-page="privacy"]').click();await page.locator('details.legal summary').click();
  const legal=await page.locator('details.legal pre').innerText();assert.match(legal,/MIT License/);assert.match(legal,/Apache License/);assert.match(legal,/WEBVIEW2 SDK NOTICE/);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,platform+' offline license overflow');
  await page.locator('button[data-page="audio"]').click();
  if(platform!=='ios'){await page.locator('#volume').fill('26');await page.locator('#volume').dispatchEvent('change');await page.waitForFunction(()=>window.nativeCalls.some(x=>x.method==='setVolume'&&x.params.value===26));await page.getByText('26%',{exact:true}).waitFor();}
  else{assert.equal(await page.locator('#volume').count(),0);await page.locator('[data-action="native-volume"]').click();await page.waitForFunction(()=>window.nativeCalls.some(x=>x.method==='showNativeVolume'));}
  if(platform!=='windows'){await page.locator('button[data-page="display"]').click();await page.locator('#brightness').fill('32');await page.locator('#brightness').dispatchEvent('change');await page.waitForFunction(()=>window.nativeCalls.some(x=>x.method==='setBrightness'&&x.params.value===32));await page.getByText('32%',{exact:true}).waitFor();}
  if(platform==='windows'){
   await page.locator('button[data-page="controls"]').click();await page.locator('[data-action="apply"]').click();await page.locator('[data-action="restore"]').waitFor();await page.locator('[data-action="restore"]').click();await page.locator('[data-action="apply"]').waitFor();
   await page.locator('button[data-page="laptop"]').click();await page.locator('[data-action="host-start"]').click();await page.locator('[data-action="host-details"]:not([disabled])').waitFor();await page.locator('[data-action="host-stop"]').click();await page.locator('[data-action="host-start"]:not([disabled])').waitFor();
  }
  await page.locator('button[data-page="history"]').click();await page.locator('[data-action="history-import"]').click();await page.getByRole('heading',{name:'2 timestamped rows · 1.1.2020'}).waitFor();assert.match(await page.locator('table').innerText(),/3623.00/);assert.equal(await page.locator('.history-graph svg').count(),1);assert.doesNotMatch(await page.locator('.content').innerText(),/SYNTHETIC-PRIVATE-CANARY/);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false,platform+' imported-history overflow');await page.locator('[data-action="history-clear"]').click();await page.getByRole('heading',{name:'No recording imported'}).waitFor();
  if(platform!=='windows'){
   await page.locator('button[data-page="laptop"]').click();await page.locator('#host').fill('https://192.168.1.2:8766');await page.locator('#pin').fill('a'.repeat(64));await page.locator('#code').fill('b'.repeat(32));await page.locator('[data-action="pair"]').click();await page.waitForFunction(()=>window.nativeCalls.some(x=>x.method==='pairLaptop'));await page.locator('[data-action="pair-finish"]').click();await page.getByText('Paired in native session memory. Token never reaches the web UI.',{exact:true}).waitFor();
   await page.locator('[data-action="remote-refresh"]').click();await page.locator('#remote-readings').getByText('3366',{exact:true}).waitFor();await page.locator('#remote-volume').fill('23');await page.locator('[data-action="remote-volume"]').click();await page.waitForFunction(()=>window.nativeCalls.some(x=>x.method==='remoteCommand'&&x.params.operation==='setVolume'&&x.params.params.value===23));
   // Accelerated client timers test expiry without waiting 13 real seconds.
   await page.clock.install();await page.clock.fastForward(13000);
   await page.waitForFunction(()=>!document.getElementById('remote-readings')?.innerText.includes('3366'));assert.equal(await page.locator('#remote-controls:visible').count(),0,'expired remote control UI is hidden');
   await page.locator('[data-action="disconnect"]').click();await page.waitForFunction(()=>window.nativeCalls.some(x=>x.method==='disconnectLaptop'));
  }
  await page.evaluate(()=>{window.nativeFixture.sampledAt='<img src=x onerror=alert(1)>';});await page.locator('button[data-page="device"]').click();assert.equal(await page.locator('img[src="x"]').count(),0);
  await page.close();
 }
 assert.deepEqual(errors,[],'UI browser errors');assert.deepEqual(external,[],'unexpected external resource request');
 await browser.close();console.log('PASS: nine common pages, desktop/phone layout, demo write refusal, mocked WebView2/Android/iOS bridge wiring, supported controls, offline legal notices, journal UI, native-volume route, CSV graph/identity projection, local-pairing fields, remote request wiring and timed stale-readings withholding. No physical-device test was made.');
})().catch(error=>{console.error(error);process.exit(1);});
