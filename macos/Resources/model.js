'use strict';
(function (root) {
  const tweaks = [
    {id:'dock-autohide',group:'Dock',title:'Automatically hide the Dock',description:'A little more room for your work. Move to the screen edge to reveal it.',icon:'dock',restart:'Dock'},
    {id:'dock-reveal',group:'Dock',title:'A quicker Dock reveal',description:'Set the reveal delay to 0.15 seconds. Requires Dock auto-hide to be enabled.',icon:'timer',restart:'Dock'},
    {id:'dock-scale',group:'Dock',title:'A simpler minimize effect',description:'Use Scale instead of Genie. A visual preference—not a GPU performance unlock.',icon:'layers',restart:'Dock'},
    {id:'dock-launch',group:'Dock',title:'A calmer app launch',description:'Turn off the Dock’s launch animation. No changes to app execution or CPU boost.',icon:'spark',restart:'Dock'},
    {id:'finder-path',group:'Finder',title:'Show the Finder path bar',description:'See where the current folder sits without opening its information window.',icon:'folder',restart:'Finder'},
    {id:'finder-status',group:'Finder',title:'Show the Finder status bar',description:'Keep folder item counts and available-space information in view.',icon:'rows',restart:'Finder'},
    {id:'finder-hidden',group:'Finder',title:'Show hidden files',description:'Reveal dotfiles. This does not grant permission to edit protected system files.',icon:'eye',restart:'Finder'},
    {id:'file-extensions',group:'Finder',title:'Always show file extensions',description:'See the full filename. Renaming an extension can change how a file opens.',icon:'file',restart:'Finder'},
    {id:'scrollbars',group:'Appearance',title:'Always show scroll bars',description:'Keep a visible scroll position in compatible apps. Relaunch affected apps if needed.',icon:'sliders',restart:'Relaunch affected apps'},
    {id:'dock-recents',group:'Dock',title:'Hide recent apps in the Dock',description:'Leave pinned and running apps; preserve the original choice for restore.',icon:'dock',restart:'Dock'},
    {id:'finder-folders-first',group:'Finder',title:'Folders first in Finder',description:'Group folders ahead of files in supported Finder views. No files move.',icon:'folder',restart:'Finder'},
    {id:'natural-scroll',group:'Appearance',title:'Natural scrolling',description:'Change the user-level mouse/trackpad scroll-direction preference. No input driver is replaced.',icon:'sliders',restart:'Relaunch affected apps'}
  ];
  const pages = ['overview','performance','battery','display','audio','tweaks','hardware','fan','history','storage','companion','recovery','about'];
  function escapeHTML(value) { return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
  function boundedNumber(value, min, max) { return typeof value === 'number' && Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : null; }
  function capacityHealth(battery) {
    const design = battery?.DesignCapacity, full = battery?.AppleRawMaxCapacity ?? battery?.MaxCapacity;
    if (typeof design !== 'number' || typeof full !== 'number' || !Number.isFinite(design) || !Number.isFinite(full) || design <= 100 || full <= 100 || full >= design * 1.5) return null;
    return Number.isFinite(full / design) ? 100 * full / design : null;
  }
  function usageColor(value) {
    const n=boundedNumber(value,0,100);
    return n===null?'#92a0b5':n<40?'#7edec2':n<75?'#ffc47f':'#ff829b';
  }
  function capabilities(s={}) {
    return {cpuUsage:boundedNumber(s.cpu?.loadPercent,0,100)!==null,
      memory:typeof s.memory?.totalGB==='number'&&s.memory.totalGB>0&&Number.isFinite(s.memory.totalGB),
      gpuAPI:Array.isArray(s.gpu)&&s.gpu.length>0,
      gpuUsage:boundedNumber(s.gpu?.[0]?.loadPercent,0,100)!==null,
      display:typeof s.display?.width==='number'&&s.display.width>0,
      battery:typeof s.battery?.chargePercent==='number'||capacityHealth(s.battery)!==null,
      volume:boundedNumber(s.volume,0,100)!==null,
      clockControl:false,fanControl:false,chargeLimit:false,autoHDR:false,dts:false,systemMicDSP:false};
  }
  function cpuSample(state) {
    const v=state?.cpu?.loadPercent,t=state?.sampledUptimeSeconds,wall=state?.sampledAtUnix;
    return [v,t,wall].every(n=>typeof n==='number'&&Number.isFinite(n))&&v>=0&&v<=100&&t>=0&&wall>0?{time:wall,value:v,uptime:t}:null;
  }
  function freshFanReadings(fan={},native=false,stale=false,elapsedSeconds=0) {
    const age=fan.ageSeconds;
    if(!native||stale||!['ok','partial-or-sensor-unavailable'].includes(fan.status)||
       typeof age!=='number'||!Number.isFinite(age)||age<0||!Number.isFinite(elapsedSeconds)||elapsedSeconds<0||age+elapsedSeconds>12)return [];
    return (Array.isArray(fan.fans)?fan.fans:[]).slice(0,2).filter(r=>r.status==='ok'&&typeof r.rpm==='number'&&Number.isFinite(r.rpm)&&r.rpm>=0&&r.rpm<=30000);
  }
  function timelineSegments(points,gapSeconds=6) {
    const segments=[];let part=[];
    for(const p of points){
      if(!p||![p.time,p.value].every(Number.isFinite)){if(part.length)segments.push(part);part=[];continue;}
      const previous=part.at(-1);
      if(previous&&(p.time<=previous.time||p.time-previous.time>gapSeconds)){segments.push(part);part=[];}
      part.push(p);
    }
    if(part.length)segments.push(part);return segments;
  }
  function canRestore(row) { return !!row?.saved && !row.conflict && !row.managed && !row.blocked; }
  function actionAllowed(method, params = {}) {
    if (['state','restoreAll','keepAwake','powerSample','exportReport','pickHistoryCSV','startCompanion','stopCompanion','companionDetails','purgeMemory','cleanCaches','checkUpdates','scanPeers'].includes(method)) return true;
    if (['applyTweak','restoreTweak'].includes(method)) return tweaks.some(t => t.id === params.id);
    if (method === 'restartUI') return ['Dock','Finder'].includes(params.app);
    if (['setVolume','setBrightness'].includes(method)) return typeof params.value === 'number' && Number.isFinite(params.value) && params.value >= 0 && params.value <= 100;
    if (method === 'setPowerProfile') return ['High Performance', 'Balanced', 'Battery Saver'].includes(params.profile);
    if (method === 'setBatteryLimit') return [60, 80, 100].includes(params.limit);
    if (method === 'setFanMode') return ['Whisper', 'Standard', 'Turbo'].includes(params.mode);
    if (method === 'sendPeerFile') return typeof params.peerId === 'string' && params.peerId.length > 0;
    if (method === 'openSetting') return ['display','audio','keyboard','trackpad','battery','accessibility','login','wifi','bluetooth','storage','notifications'].includes(params.id);
    return false;
  }
  function demoState() {
    return {mode:'demo',version:'0.5.1-beta.1',architecture:'x86_64',os:'macOS UI preview',smbiosModel:'Not collected in preview',powerProfile:'Balanced',batteryLimit:100,fanMode:'Standard',cpu:{name:'Intel Core i5-12500H',logicalCores:16,loadPercent:17},memory:{totalGB:16,usedGB:6.3,compressedGB:0.5,swapMB:0},gpu:[{name:'Intel Iris Xe Graphics (96 EU)',lowPower:true,metal3Family:false}],battery:{chargePercent:68,charging:false,onAC:false,DesignCapacity:5000,AppleRawMaxCapacity:4250,MaxCapacity:4250,CycleCount:120},storage:{freeGB:120,totalGB:500},display:{width:1920,height:1080,refreshHz:60,screenCount:1},volume:42,brightness:80,thermalState:0,awake:false,powerSample:[],fan:{status:'preview-not-live',fans:[],manualControl:false},tweaks:tweaks.map(t=>({id:t.id,saved:false,matches:false,conflict:false,managed:false,blocked:false}))};
  }
  class DemoProvider {
    async request(method, params = {}) {
      if (!actionAllowed(method,params)) throw new Error('Unsupported action.');
      if (method === 'state') return demoState();
      throw new Error('Preview only. Build and open the native Mac app to use this control. No system change was made.');
    }
  }
  const api = {tweaks,pages,escapeHTML,boundedNumber,capacityHealth,usageColor,capabilities,canRestore,cpuSample,freshFanReadings,timelineSegments,actionAllowed,demoState,DemoProvider};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.KLModel = Object.freeze(api);
})(typeof globalThis !== 'undefined' ? globalThis : this);
