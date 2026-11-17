'use strict';
(()=>{
  const M=window.KLCommon,e=M.escape;
  let counter=0,pending=new Map(),state=null,page='device',busy=false,polling=false,recording=null,remote=null;
  let receivedAt=-Infinity,remoteAt=-Infinity,remoteWall=-Infinity;
  const now=()=>window.performance.now()/1000;
  const native=!!(window.chrome?.webview||window.KLNative||window.webkit?.messageHandlers?.kl06mobile);
  function receive(message){
    if(typeof message==='string'){try{message=JSON.parse(message);}catch{return;}}
    if(!message||typeof message.id!=='string'||typeof message.ok!=='boolean')return;
    const p=pending.get(message.id);if(!p)return;
    clearTimeout(p.timer);pending.delete(message.id);
    message.ok?p.resolve(message.result):p.reject(Error(message.error||'Action unavailable.'));
  }
  window.KL06=Object.freeze({receive});
  window.chrome?.webview?.addEventListener('message',event=>receive(event.data));
  function request(method,params={}){
    if(!M.action(method,params))return Promise.reject(Error('Unsupported or invalid action.'));
    if(!native)return Promise.reject(Error('Browser preview only. No system control or connection was made.'));
    return new Promise((resolve,reject)=>{
      const id='kl-'+(++counter),timer=setTimeout(()=>{pending.delete(id);reject(Error('Native response timed out. A native dialog may still be open; check this device before retrying. No action was automatically retried.'));},120000);
      pending.set(id,{resolve,reject,timer});const msg={id,method,params};
      if(window.chrome?.webview)window.chrome.webview.postMessage(msg);
      else if(window.KLNative)window.KLNative.postMessage(JSON.stringify(msg));
      else window.webkit.messageHandlers.kl06mobile.postMessage(msg);
    });
  }
  const n=(v,d=0)=>typeof v==='number'&&Number.isFinite(v)?v.toFixed(d):'—';
  const button=(label,action,extra='',disabled=false)=>`<button data-action="${e(action)}" ${extra} ${busy||disabled?'disabled':''}>${e(label)}</button>`;
  const metric=(label,value,note,kind='')=>`<section class="metric ${kind}"><span>${e(label)}</span><strong>${e(value)}</strong><small>${e(note)}</small></section>`;
  function toast(s){const node=document.getElementById('notice');node.textContent=s;node.classList.add('show');clearTimeout(toast.timer);toast.timer=setTimeout(()=>node.classList.remove('show'),8000);}
  function elapsedRemote(){return Math.max(now()-remoteAt,Date.now()/1000-remoteWall,0);}
  function remoteFresh(){return M.remoteFresh(remote,elapsedRemote());}
  function localFresh(){return !!state&&(!native||now()-receivedAt<=12);}
  function devices(s=state,paired=false){
    const b=s.battery||{},f=M.fanValues(s,paired?elapsedRemote():0);
    return `<div class="metrics" data-reading-group="${paired?'remote':'local'}">${metric('Battery',n(b.chargePercent)+'%',b.onAC===true?'Connected to power':b.onAC===false?'On battery':'Power source unavailable','mint')}${metric('Memory',n(s.memory?.usedGB,1)+' / '+n(s.memory?.totalGB,1)+' GiB',s.memory?.source||'OS-reported; a missing field stays unavailable','blue')}${metric('Free space',n(s.storage?.freeGB,1)+' GiB','Reported filesystem/container capacity','amber')}${metric(paired?'Laptop fan RPM':'CPU utilization',paired?(f.length?f.map(x=>n(x.rpm)).join(' / '):'Unavailable'):n(s.cpu?.loadPercent)+'%',paired?'Existing desktop provider; never a fan-control interface':s.cpu?.source||'No supported system CPU counter; not fabricated','violet')}</div>`;
  }
  function device(){return `<section class="hero"><span class="eyebrow">CIRRUS · CONNECTED WITH CONSENT</span><h1>Your device. Clearly connected.</h1><p>Real supported controls, source-labelled history and a laptop connection you explicitly pair.</p><div class="badges"><b>${e(state.platform||'preview')}</b><b>${e(state.sampledAt||'No native reading')}</b><b>No firmware writes</b></div></section>${devices()}<section class="panel"><h2>One view. Honest boundaries.</h2><p>Phone readings belong to this device. The Laptop page uses a separately paired native desktop provider. HWiNFO imports remain historical Windows recordings on every OS.</p><p>0.3.0-beta.2 · build 5. Missing clocks, RPM and hardware-only features stay unavailable, never inferred from a model name. RAM formulas and phone app-window brightness are not calibration tests.</p></section>`;}
  function volumePanel(){const c=state.capabilities||{};return `<section class="panel"><h2>Output volume</h2><strong class="value" data-livevalue="local">${n(state.volume)}%</strong>${c.volume?`<input aria-label="Output volume" id="volume" type="range" min="0" max="100" value="${n(state.volume)}" ${busy?'disabled':''}>`:'<p>Direct output-volume writes unavailable on this platform.</p>'}${c.nativeVolume?button('Open native system volume','native-volume'):''}<p>Default media/output route only. No DTS, microphone recording, codec replacement or system-wide DSP. A desktop volume change is immediate, not a journalled preference. Phone rollback is best-effort on background if still owned.</p></section>`;}
  function brightnessPanel(){const c=state.capabilities||{};return `<section class="panel"><h2>Temporary brightness</h2><strong class="value" data-livevalue="local">${n(state.brightness)}%</strong>${c.brightness?`<input aria-label="Temporary brightness" id="brightness" type="range" min="1" max="100" value="${n(state.brightness)}" ${busy?'disabled':''}>`:'<p>No supported brightness write is exposed by this build.</p>'}<p>${e(c.brightnessScope||'Use existing OS/Fn controls. No OLED/backlight driver change or physical-nits claim.')}</p><p>Phone brightness restores on background if still unchanged. A forced termination cannot guarantee restoration.</p></section>`;}
  function controls(){const c=state.capabilities||{};return `<h1>Useful changes. No fake switches.</h1><p class="intro">Every native write is allowlisted and explicit. No root, firmware, partition or driver controls.</p><div class="grid">${volumePanel()}${brightnessPanel()}</div><section class="panel"><h2>Temporary keep-awake</h2><p>At most 15 minutes. Phone: app screen only; released on background. Desktop: idle-SYSTEM sleep only; stops on quit. Not a lid, forced-sleep or firmware fix.</p>${button(state.awake?'Stop keep-awake':'Keep awake, up to 15 min','awake','',!c.awake)}</section>${(state.tweaks||[]).length?`<section class="panel"><h2>Reversible Windows preferences</h2>${state.tweaks.map(t=>`<div class="row"><div><strong>${e(M.tweaks[t.id]||'Unsupported preference')}</strong><small>${t.conflict?'Newer external choice: blocked':t.saved?'Exact original saved':'Original saved before the first write'}</small></div>${button(t.saved?'Restore':'Apply',t.saved?'restore':'apply',`data-id="${e(t.id)}"`,t.conflict||t.blocked||t.managed)}</div>`).join('')}</section>`:''}<section class="panel"><h2>Restore supported changes</h2><p>Windows: restore eligible journalled preferences, not immediate desktop volume. Phones: restore owned temporary brightness/awake and Android media volume if unchanged. Newer external choices are preserved. No desktop journal is silently erased.</p>${button('Restore my supported changes','restore-all')}</section>`;}
  function display(){return `<h1>Display, without disturbing your setup.</h1>${brightnessPanel()}<section class="panel"><h2>HDR and panel capability</h2><p>No HDR switch, panel overclock, EDID, OLED PWM or driver write. The working Mac stays HDR OFF; Windows HDR is left to Windows Settings. Mobile brightness is a supported OS/app-window control, not a laptop panel control.</p></section>`;}
  function audio(){return `<h1>Sound, through the existing output.</h1>${volumePanel()}<section class="panel"><h2>Keep working routes intact</h2><p>Speakers/headphones use the existing system route. No DTS licensing claim, codec/layout change, microphone access, audio-driver install or system-wide microphone DSP.</p></section>`;}
  function storage(){return `<h1>Your storage. Read, not rearranged.</h1><div class="metrics" data-reading-group="local">${metric('Available',n(state.storage?.freeGB,1)+' GiB','OS-reported free space','mint')}${metric('Capacity',n(state.storage?.totalGB,1)+' GiB','App/user filesystem volume, not an SSD health test','blue')}</div><section class="panel"><h2>No cleaner, boot or partition operations</h2><p>This app never erases caches, reformats disks, touches EFI/Windows boot files or changes partitions. Storage capacity is not SMART health. No serial, volume name or source path is displayed or sent to a companion.</p></section>`;}
  function fan(){const rows=M.fanValues(state);return `<h1>Fan readings. Firmware stays in charge.</h1><div class="metrics" data-reading-group="local">${metric('Current RPM',rows.length?rows.map(x=>n(x.rpm)).join(' / '):'Unavailable',state.fan?.source||'No public local fan provider in this platform build','violet')}</div><section class="panel"><h2>${e(state.fan?.status||'Unsupported on this device')}</h2><p>Windows: explicitly import a HWiNFO sensor CSV on History; no HWiNFO driver/shared-memory reader is silently installed. Android/iOS: no public fan sensor/control exposed. Live Mac RPM is queried by the native Mac build from an already-present standard SMC provider, then may be shared via an authenticated laptop session.</p><p>No fan curves, manual target RPM, EC writes, ASUS firmware mode, charge cap or invented zero-RPM fallback.</p></section>`;}
  function graph(series){
    const p=(series.recent||[]).filter(x=>Number.isFinite(x.time)&&Number.isFinite(x.value));if(p.length<2)return '';
    const times=p.map(x=>x.time),values=p.map(x=>x.value),minT=Math.min(...times),maxT=Math.max(...times),minV=Math.min(...values),maxV=Math.max(...values),segments=[];let segment=[];
    for(const item of p){const previous=segment[segment.length-1];if(previous&&(item.time<=previous.time||item.time-previous.time>6)){segments.push(segment);segment=[];}segment.push(item);}if(segment.length)segments.push(segment);
    const points=part=>part.map(x=>`${(8+((x.time-minT)/Math.max(.001,maxT-minT))*624).toFixed(2)},${(100-((x.value-minV)/Math.max(.001,maxV-minV))*80).toFixed(2)}`).join(' ');
    return `<section class="panel history-graph"><h2>${e(series.label)} <small>${e(series.unit)} · ${e(series.source)}</small></h2><svg viewBox="0 0 640 116" role="img" aria-label="${e(series.label)} historical numeric graph"><path d="M8 100H632" stroke="#38535c"/>${segments.map(part=>`<polyline points="${points(part)}" fill="none" stroke="#91ead5" stroke-width="2.5"/>`).join('')}</svg><p>Last ${p.length} retained timestamped points. Gaps/non-monotonic times are not connected. Unverified recording-local clock, never live data.</p></section>`;
  }
  function history(){return `<h1>History, with its source attached.</h1><p class="intro">Windows HWiNFO CSV · local only · never live Mac/phone telemetry.</p>${button('Import local HWiNFO CSV','history-import')}${recording?`<section class="panel"><h2>${e(recording.samples)} timestamped rows · ${e(recording.recordedDate)}</h2><p>Only fixed numeric channels retained; raw paths/identities discarded. Recording timezone, sensor calibration and platform equivalence are unverified.</p><div class="table-wrap"><table><thead><tr><th>Historical channel</th><th>Samples</th><th>Min</th><th>Median</th><th>Max</th></tr></thead><tbody>${recording.series.map(s=>`<tr><td>${e(s.label)}<small>${e(s.source)} · ${e(s.unit)}</small></td><td>${e(s.count)}</td><td>${n(s.min,2)}</td><td>${n(s.median,2)}</td><td>${n(s.max,2)}</td></tr>`).join('')}</tbody></table></div>${button('Clear imported history','history-clear')}</section>${recording.series.slice(0,8).map(graph).join('')}`:'<section class="panel empty"><h2>No recording imported</h2><p>Choose a sensor CSV up to 5 MiB / 10,000 samples. No file is scanned automatically or uploaded. Numeric data remains in app memory until cleared or quit.</p></section>'}`;}
  function laptop(){
    if(state.platform==='windows')return `<h1>Phone companion host</h1><section class="panel"><h2>${state.companion?.running?'Temporary session active':'Session is off'}</h2><p>Enable only on your trusted private LAN. Requires installed Python 3. The native dialog shows the HTTPS URL, full certificate SHA-256 and random five-minute pairing code. Approve pairing and every requested write on this laptop. No public listener, cloud tunnel, firewall or security change.</p>${button('Enable temporary session','host-start','',state.companion?.running)}${button('Show private pairing details','host-details','',!state.companion?.running)}${button('Stop and revoke all devices','host-stop','',!state.companion?.running)}<p>Maximum 30-minute session; quit stops the broker. No laptop credentials leave this device. A forced desktop crash may leave the read-only broker until its short lifetime ends; native writes are unavailable and telemetry expires.</p></section>`;
    const fresh=remoteFresh(),r=remote?.state;
    return `<h1>Your laptop. Explicitly paired.</h1><p class="intro">Same private LAN · full TLS certificate pin · no arbitrary shell.</p><section class="panel"><h2>Pair from the native laptop dialog</h2><p>Enable Phone companion in KL-06 on Mac/Windows. Copy all three fields. Never accept an unknown fingerprint. Approve this phone on the laptop, then finish pairing.</p><label>LAN HTTPS URL<input id="host" type="text" autocomplete="off" placeholder="https://192.168.x.x:8766" spellcheck="false"></label><label>Full certificate SHA-256<input id="pin" type="text" autocomplete="off" maxlength="64" spellcheck="false"></label><label>Five-minute random pairing code<input id="code" type="password" autocomplete="off" maxlength="32" spellcheck="false"></label><div class="actions">${button('Request pairing','pair')}${button('Finish approved pairing','pair-finish')}${button('Disconnect this phone','disconnect')}</div><p>${state.companion?.paired?'Paired in native session memory. Token never reaches the web UI.':'Not paired. No network connection until you choose Request pairing.'}</p></section><section class="panel"><h2>Paired laptop · <span id="remote-status">${e(fresh?'fresh':remote?'expired/unavailable':'not sampled')}</span></h2>${button('Refresh laptop readings','remote-refresh')}<div id="remote-readings">${fresh&&r?devices(r,true):'<p>No fresh laptop snapshot. Historical recordings and cached zeroes are not substituted.</p>'}</div>${fresh&&r?`<p>Native snapshot: ${e(r.sampledAt)} · ${e(r.platform)}. Physical fan-sensor age/calibration is unknown.</p><div id="remote-controls"><label>Requested laptop output volume<input id="remote-volume" type="range" min="0" max="100" value="${n(r.volume)}"></label>${button('Request laptop volume change','remote-volume','',!M.numeric(r.volume,0,100))}${button('Request temporary laptop keep-awake','remote-awake')}<div class="rows">${(r.tweaks||[]).map(t=>`<div class="row"><span>${e(M.tweaks[t.id]||'Unknown preference')}</span>${button(t.saved?'Request restore':'Request apply',t.saved?'remote-restore':'remote-apply',`data-id="${e(t.id)}"`,t.conflict||t.blocked||t.managed)}</div>`).join('')}</div></div>`:''}<p>Every write requires this laptop’s local confirmation, showing its exact value/preference ID, and expires after 90 seconds. Pairing never unlocks firmware, fan curves or administrator commands.</p>${button('Check last requested action','remote-result')}</section>`;
  }
  function privacy(){return `<h1>Small footprint. Visible consent.</h1><section class="panel"><h2>Never quietly enabled</h2><p>No cloud account, telemetry upload, microphone recording, accessibility bypass, root/jailbreak, hidden login item, automatic driver install or unrestricted laptop command. Opt-in TLS sessions are bounded and full-certificate-pinned; tokens stay in native memory and are revoked when the laptop session stops.</p><h2>Historical does not mean live</h2><p>HWiNFO is a Windows data source, not a Mac/mobile driver or hardware write protocol. Local CSV import works across these apps. Live Mac fan RPM is read separately from an existing SMC provider, if available. Missing interfaces stay unavailable; source/snapshot age is not physical acquisition age.</p><h2>Preserve the working system</h2><p>No EFI, Windows boot/partition, kernel, firmware or security changes. DTS, system mic DSP, charge caps, fan modes/curves and arbitrary clocks are not implemented. Restore desktop preferences before removing their private journal. Phone temporary changes restore on background if still owned; forced termination cannot guarantee rollback.</p><h2>Testing and release boundaries</h2><p>Source/build verification, mocked UI tests and owner physical-device results are separate. No successful native Mac/iPhone build or physical-device compatibility is implied. Drive releases remain disabled until private-repo, read-only identity and offline owner signing setup; a source ZIP or false/unfilled test template can never approve itself.</p><details class="legal"><summary>Application and third-party licenses</summary><pre>${e(window.KLLicenses||'See the bundled source license files.')}</pre></details></section>`;}
  const pages=[['device','Overview'],['controls','Device controls'],['display','Display'],['audio','Audio'],['storage','Storage'],['fan','Fans & sensors'],['history','Windows history'],['laptop','Laptop companion'],['privacy','Safety & privacy']];
  let shellRendered = false;
  function render(){
    const platform=state?.platform||'device';
    const app = document.getElementById('app');
    if (!shellRendered || !app.querySelector('.shell')) {
      app.innerHTML=`<div class="shell"><aside><div class="brand"><img src="icon.svg" alt=""><strong>KL-06<small>MANAGER · v0.4.0-BETA.1</small></strong></div><nav id="app-nav">${pages.map(([id,label])=>`<button data-page="${id}" class="${page===id?'selected':''}" ${page===id?'aria-current="page"':''}>${e(label)}</button>`).join('')}</nav><p class="aside-note">0.4.0-beta.1 · build 6<br>No firmware writes.</p></aside><main><header><span id="header-platform">My workspace / ${e(platform)}</span><b id="header-badge">${native?'NATIVE · CAPABILITY-GATED':'DEMO · NOT LIVE'}</b></header><div class="content" id="app-content">${(localFresh()||!native)?({device,controls,display,audio,storage,fan,history,laptop,privacy}[page])():`<section class="panel"><h1>Waiting for fresh native counters…</h1><p>No preview readings are substituted. The last device state is unavailable/expired; no write is automatically retried.</p></section>`}</div></main></div>`;
      shellRendered = true;
    } else {
      app.querySelectorAll('#app-nav button').forEach(btn => {
        const isCurrent = btn.dataset.page === page;
        btn.classList.toggle('selected', isCurrent);
        if (isCurrent) btn.setAttribute('aria-current', 'page');
        else btn.removeAttribute('aria-current');
      });
      const hPlat = document.getElementById('header-platform');
      if (hPlat) hPlat.textContent = `My workspace / ${platform}`;
      const hBadge = document.getElementById('header-badge');
      if (hBadge) hBadge.textContent = native ? (localFresh() ? 'NATIVE · CAPABILITY-GATED' : 'REFRESHING COUNTERS…') : 'DEMO · NOT LIVE';
      const contentEl = document.getElementById('app-content');
      if (contentEl) {
        contentEl.innerHTML = (localFresh() || !native || state) ? ({device,controls,display,audio,storage,fan,history,laptop,privacy}[page])() : `<section class="panel"><h1>Waiting for fresh native counters…</h1><p>No preview readings are substituted. The last device state is unavailable/expired; no write is automatically retried.</p></section>`;
      }
    }
  }
  async function refresh(force=false){
    if(!native||document.hidden||busy||polling||(!force&&document.querySelector('input:focus')))return;
    polling=true;
    try{const value=await request('state');if(!value||!['windows','android','ios'].includes(value.platform))throw Error();if(!force&&document.querySelector('input:focus'))return;state=value;receivedAt=now();render();}
    catch{receivedAt=-Infinity;toast('Native state unavailable. No substitute readings.');render();}
    finally{polling=false;}
  }
  async function act(method,params={}){
    if(busy)return;busy=true;document.querySelectorAll('button[data-action],input[type=range]').forEach(x=>x.disabled=true);
    try{const r=await request(method,params);
      if(method==='pickHistoryCSV'){recording=window.KLHistory.parse(r.csvText);page='history';}
      else if(method==='remoteState'){remote=r;remoteAt=now();remoteWall=Date.now()/1000;}
      toast(typeof r==='string'?r:r?.message||r?.status||'Completed.');
    }catch(err){toast(err.message);if(method==='remoteState')remote=null;}
    finally{busy=false;await refresh(true);render();}
  }
  document.addEventListener('click',ev=>{
    const b=ev.target.closest('button');if(!b||b.disabled)return;
    if(b.dataset.page){page=b.dataset.page;render();return;}
    const id=b.dataset.id;
    switch(b.dataset.action){
      case'history-clear':recording=null;render();return;
      case'history-import':act('pickHistoryCSV');return;
      case'awake':act('keepAwake');return;
      case'native-volume':act('showNativeVolume');return;
      case'apply':act('applyTweak',{id});return;
      case'restore':act('restoreTweak',{id});return;
      case'restore-all':act('restoreAll');return;
      case'pair':{const params={host:document.getElementById('host').value.trim(),pin:document.getElementById('pin').value.trim(),code:document.getElementById('code').value.trim()};document.getElementById('code').value='';act('pairLaptop',params);return;}
      case'pair-finish':act('finishPairing');return;
      case'disconnect':remote=null;act('disconnectLaptop');return;
      case'remote-refresh':act('remoteState');return;
      case'remote-result':act('remoteResult');return;
      case'remote-volume':if(remoteFresh())act('remoteCommand',{operation:'setVolume',params:{value:Number(document.getElementById('remote-volume').value)}});return;
      case'remote-awake':if(remoteFresh())act('remoteCommand',{operation:'keepAwake',params:{}});return;
      case'remote-apply':case'remote-restore':if(remoteFresh())act('remoteCommand',{operation:b.dataset.action==='remote-apply'?'applyTweak':'restoreTweak',params:{id}});return;
      case'host-start':act('startCompanion');return;
      case'host-stop':act('stopCompanion');return;
      case'host-details':act('companionDetails');return;
    }
  });
  document.addEventListener('change',event=>{if(event.target.id==='volume')act('setVolume',{value:Number(event.target.value)});if(event.target.id==='brightness')act('setBrightness',{value:Number(event.target.value)});});
  if(!native)state={platform:'preview',version:'0.4.0-beta.1',sampledAt:'Illustrative interface only',battery:{chargePercent:72,onAC:false},memory:{usedGB:3.1,totalGB:8},storage:{freeGB:40},capabilities:{},tweaks:[]};
  render();if(native){refresh();setInterval(refresh,5000);}
  setInterval(()=>{
    if(document.hidden)return;
    if(native&&!localFresh()){
      document.querySelectorAll('[data-reading-group="local"] strong,[data-livevalue="local"]').forEach(x=>x.textContent='Unavailable');
    }
    if(remote&&!remoteFresh()){
      const readings=document.getElementById('remote-readings'),controls=document.getElementById('remote-controls'),status=document.getElementById('remote-status');
      if(readings)readings.innerHTML='<p>Laptop snapshot expired. Refresh it explicitly; no stale readings are retained as current.</p>';
      if(controls)controls.hidden=true;if(status)status.textContent='expired/unavailable';
    }else if(remote&&document.getElementById('remote-readings'))document.getElementById('remote-readings').innerHTML=devices(remote.state,true);
  },1000);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden){remote=null;refresh();}});
})();
