'use strict';
(function(root){
  const tweaks=Object.freeze({'win-extensions':'Show file extensions','win-hidden':'Show ordinary hidden files','win-theme-dark':'Dark application theme','dock-autohide':'Automatically hide Dock','dock-reveal':'Quicker Dock reveal','dock-scale':'Scale minimise effect','dock-launch':'Stop Dock launch bounce','finder-path':'Finder path bar','finder-status':'Finder status bar','finder-hidden':'Show hidden files','file-extensions':'Show file extensions','scrollbars':'Always show scrollbars','dock-recents':'Hide recent Dock apps','finder-folders-first':'Folders first','natural-scroll':'Natural scrolling'});
  const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const object=p=>p!==null&&typeof p==='object'&&!Array.isArray(p);
  const exact=(p,keys=[])=>object(p)&&Object.keys(p).sort().join(',')===keys.slice().sort().join(',');
  const numeric=(v,min,max)=>typeof v==='number'&&Number.isFinite(v)&&v>=min&&v<=max;
  function privateHost(raw){
    if(typeof raw!=='string'||raw.length>50)return false;
    try{const u=new URL(raw),p=u.hostname.split('.');
      return (raw===u.origin||raw===u.origin+'/')&&u.protocol==='https:'&&!u.username&&!u.password&&!u.search&&!u.hash&&u.port==='8766'&&p.length===4&&p.every(n=>/^(0|[1-9]\d{0,2})$/.test(n)&&Number(n)<=255)&&(p[0]==='10'||p[0]==='172'&&Number(p[1])>=16&&Number(p[1])<=31||p[0]==='192'&&p[1]==='168');
    }catch{return false;}
  }
  function action(method,p={}){
    if(!object(p))return false;
    if(['state','pickHistoryCSV','pickShareFile','openAppSettings','restoreAll','keepAwake','showNativeVolume','finishPairing','remoteState','remoteResult','disconnectLaptop','startCompanion','stopCompanion','companionDetails','discoverPeers','requestPermissions','checkUpdate','nfcStatus','startNfcScan'].includes(method))return exact(p);
    if(['exportLogs','saveErrorReport','shareLogs'].includes(method))return exact(p)||(exact(p,['logs'])&&Array.isArray(p.logs));
    if(method==='installUpdate')return exact(p)||(exact(p,['downloadUrl'])&&typeof p.downloadUrl==='string');
    if(method==='startNfcBeam')return exact(p)||(exact(p,['payload'])&&object(p.payload));
    if(['setVolume','setBrightness'].includes(method))return exact(p,['value'])&&numeric(p.value,method==='setBrightness'?1:0,100);
    if(['applyTweak','restoreTweak'].includes(method))return exact(p,['id'])&&typeof p.id==='string'&&Object.prototype.hasOwnProperty.call(tweaks,p.id);
    if(method==='pairLaptop')return exact(p,['code','host','pin'])&&privateHost(p.host)&&typeof p.pin==='string'&&p.pin.length===64&&/^[a-fA-F0-9]+$/.test(p.pin)&&typeof p.code==='string'&&p.code.length===32&&/^[a-f0-9]+$/.test(p.code);
    if(method==='remoteCommand')return exact(p,['operation','params'])&&object(p.params)&&['setVolume','setBrightness','applyTweak','restoreTweak','restoreAll','keepAwake'].includes(p.operation)&&action(p.operation,p.params);
    return false;
  }
  function fanValues(s,elapsed=0){const f=s?.fan||{};
    return numeric(elapsed,0,12)&&numeric(f.ageSeconds,0,12)&&f.ageSeconds+elapsed<=12&&['ok','partial-or-sensor-unavailable'].includes(f.status)?(Array.isArray(f.fans)?f.fans:[]).filter(x=>x.status==='ok'&&numeric(x.rpm,0,30000)).slice(0,2):[];
  }
  function remoteFresh(reply,elapsed){return object(reply)&&reply.protocol==='KL06_COMPANION_V1'&&reply.status==='fresh'&&object(reply.state)&&numeric(reply.validForSeconds,0,12)&&numeric(elapsed,0,12)&&elapsed<=reply.validForSeconds;}
  const api=Object.freeze({tweaks,escape,exact,numeric,privateHost,action,fanValues,remoteFresh});
  if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.KLCommon=api;
})(typeof globalThis!=='undefined'?globalThis:this);
