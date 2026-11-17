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
    {id:'scrollbars',group:'Appearance',title:'Always show scroll bars',description:'Keep a visible scroll position in compatible apps. Relaunch affected apps if needed.',icon:'sliders',restart:'Relaunch affected apps'}
  ];
  const pages = ['overview','performance','battery','display','tweaks','hardware','recovery','about'];
  function escapeHTML(value) { return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
  function boundedNumber(value, min, max) { return typeof value === 'number' && Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : null; }
  function capacityHealth(battery) {
    const design = battery?.DesignCapacity, full = battery?.AppleRawMaxCapacity ?? battery?.MaxCapacity;
    if (typeof design !== 'number' || typeof full !== 'number' || design <= 100 || full <= 100 || full >= design * 1.5) return null;
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
  function canRestore(row) { return !!row?.saved && !row.conflict && !row.managed && !row.blocked; }
  function actionAllowed(method, params = {}) {
    if (['state','restoreAll','keepAwake','powerSample','exportReport'].includes(method)) return true;
    if (['applyTweak','restoreTweak'].includes(method)) return tweaks.some(t => t.id === params.id);
    if (method === 'restartUI') return ['Dock','Finder'].includes(params.app);
    if (method === 'setVolume') return typeof params.value === 'number' && Number.isFinite(params.value) && params.value >= 0 && params.value <= 100;
    if (method === 'openSetting') return ['display','audio','keyboard','trackpad','battery','accessibility','login','wifi','bluetooth','storage','notifications'].includes(params.id);
    return false;
  }
  function demoState() {
    return {mode:'demo',version:'0.2.1',architecture:'x86_64',os:'macOS Sequoia 15.8.3',smbiosModel:'MacBookPro16,2',cpu:{name:'Intel Core i5-1135G7',logicalCores:8,loadPercent:14},memory:{totalGB:8,usedGB:5.2,compressedGB:0.86,swapMB:58},gpu:[{name:'Intel Iris Xe Graphics',lowPower:true,metal3Family:false}],battery:{chargePercent:37,charging:false,onAC:false,DesignCapacity:3549,AppleRawMaxCapacity:2237,MaxCapacity:2237,CycleCount:314},storage:{freeGB:29.6,totalGB:100.4},display:{width:1920,height:1080,refreshHz:60,screenCount:1},volume:42,thermalState:0,awake:false,powerSample:[],tweaks:tweaks.map(t=>({id:t.id,saved:false,matches:false,conflict:false,managed:false,blocked:false}))};
  }
  class DemoProvider {
    async request(method, params = {}) {
      if (!actionAllowed(method,params)) throw new Error('Unsupported action.');
      if (method === 'state') return demoState();
      throw new Error('Preview only. Build and open the native Mac app to use this control. No system change was made.');
    }
  }
  const api = {tweaks,pages,escapeHTML,boundedNumber,capacityHealth,usageColor,capabilities,canRestore,actionAllowed,demoState,DemoProvider};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.KLModel = Object.freeze(api);
})(typeof globalThis !== 'undefined' ? globalThis : this);
