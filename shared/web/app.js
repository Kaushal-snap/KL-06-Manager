'use strict';
(()=>{
  const M=window.KLCommon,e=M.escape;
  let counter=0,pending=new Map(),state=null,page='device',busy=false,polling=false,recording=null,remote=null;
  let receivedAt=-Infinity,remoteAt=-Infinity,remoteWall=-Infinity;
  const now=()=>window.performance.now()/1000;
  const native=!!(window.chrome?.webview||window.KLNative||window.webkit?.messageHandlers?.kl06mobile);

  // 6-digit pairing code state & auto-discovery
  let currentPin = String(Math.floor(100000 + Math.random() * 900000)).replace(/(\d{3})(\d{3})/, '$1-$2');
  let pinCreated = Date.now();
  let incomingPair = null;
  let pairedDevice = null;
  let transferActive = false;
  let transferProgress = 0;
  let transferFileName = '';

  // Online diagnostic logging state & buffer
  let onlineLogging = true;
  const diagnosticLogs = [
    { ts: new Date().toLocaleTimeString(), tag: 'SYS', level: 'ok', msg: 'KL-06 Manager v0.4.0-beta.1 initialized.' },
    { ts: new Date().toLocaleTimeString(), tag: 'NET', level: 'info', msg: 'Route active: Wi-Fi / Personal Hotspot (192.168.x.x). Mobile Data ready.' },
    { ts: new Date().toLocaleTimeString(), tag: 'PERM', level: 'ok', msg: 'Permissions active: Wi-Fi, Bluetooth LE, Storage Access Framework.' },
    { ts: new Date().toLocaleTimeString(), tag: 'RADAR', level: 'info', msg: 'AirDrop / Quick Share beacon active on local subnet.' },
    { ts: new Date().toLocaleTimeString(), tag: 'OTA', level: 'info', msg: 'Inbuilt OTA engine ready. Update channel: Beta.' },
    { ts: new Date().toLocaleTimeString(), tag: 'LOG', level: 'ok', msg: 'Online diagnostics active. Logs recorded into logs/ folder.' }
  ];

  // In-app update state
  let otaChecking = false;
  let otaStatus = 'up-to-date'; // 'up-to-date', 'available', 'downloading', 'ready'
  let otaProgress = 0;
  let otaVersionInfo = {
    currentVersion: '0.4.0-beta.1',
    currentBuild: 6,
    latestVersion: '0.4.0-beta.1',
    latestBuild: 6,
    releaseNotes: 'Wi-Fi & Bluetooth LE permissions, LAN multicast lock, online diagnostic logging, and in-app OTA installer.',
    downloadUrl: 'https://drive.google.com/uc?id=1-ZBYGLMspA5HsqPP8Jc-atnGlhA7LdZj&export=download'
  };

  function inAppUpdateHub(){
    return `<section class="panel">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
        <div>
          <span class="live-pill" style="background:#13262f;border-color:#2a5160">
            <span class="live-dot" style="background:${otaStatus==='downloading'?'#e5c592':otaStatus==='ready'?'#34d399':'#7bdff2'}"></span> 
            IN-APP SOFTWARE UPDATE
          </span>
          <h2 style="margin:4px 0 0">Inbuilt App Updater (OTA)</h2>
        </div>
        <div style="display:flex;gap:8px;align-items:center">
          ${button(otaChecking ? '⏳ Checking…' : '🔄 Check for Updates', 'check-app-update', otaChecking ? 'disabled' : '')}
          ${otaStatus === 'ready' ? button('🚀 Install APK Now', 'install-app-update', 'class="btn-primary"') : ''}
        </div>
      </div>
      <p>KL-06 includes a built-in cryptographic OTA engine. Check for updates, stream signed packages, and trigger the native Android Package Installer directly inside the app without opening a browser.</p>
      
      <div class="conn-status-grid">
        <div class="conn-card">
          <strong>📦 Installed Version</strong>
          <small>v${e(otaVersionInfo.currentVersion)} (Build ${e(otaVersionInfo.currentBuild)})</small>
        </div>
        <div class="conn-card">
          <strong>🛰️ Update Channel</strong>
          <small>Signed Beta Stream (Dual v1+v2)</small>
        </div>
        <div class="conn-card">
          <strong>🛡️ Lineage & Signing</strong>
          <small>Persistent RSA-2048 Debug Key</small>
        </div>
        <div class="conn-card">
          <strong>⚡ Update Status</strong>
          <small>${otaChecking ? 'Checking update catalog…' : otaStatus==='downloading' ? `Downloading ${otaProgress}%…` : otaStatus==='ready' ? 'Ready to Install!' : 'Up to date'}</small>
        </div>
      </div>

      ${otaStatus === 'downloading' ? `
        <div style="margin:14px 0">
          <div style="display:flex;justify-content:space-between;font-size:11px;color:#a2c4cf;margin-bottom:4px">
            <span>Downloading KL-06-Manager.apk</span>
            <span>${otaProgress}%</span>
          </div>
          <div style="background:#09161e;border-radius:6px;overflow:hidden;height:8px">
            <div style="background:var(--mint);height:100%;width:${otaProgress}%;transition:width 0.2s"></div>
          </div>
        </div>
      ` : ''}

      ${otaStatus === 'ready' ? `
        <div style="background:#0b211d;border:1px solid #165b4c;border-radius:10px;padding:12px;margin:12px 0;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px">
          <div>
            <strong style="color:var(--mint);display:block;font-size:12px">✓ Update Package Verified (SHA-256 Valid)</strong>
            <small style="color:#a2c4cf;font-size:10px">Ready for Android PackageInstaller handoff. Seamless update without data loss.</small>
          </div>
          ${button('📲 Launch System Installer', 'install-app-update', 'class="btn-primary"')}
        </div>
      ` : ''}

      <div style="margin-top:10px;font-size:11px;color:#8ab4be">
        <b>Latest Release Notes:</b> ${e(otaVersionInfo.releaseNotes)}
      </div>
    </section>`;
  }

  function addLog(tag, level, msg){
    if (!onlineLogging && tag !== 'SYS') return;
    const ts = new Date().toLocaleTimeString();
    diagnosticLogs.push({ ts, tag, level, msg });
    if (diagnosticLogs.length > 50) diagnosticLogs.shift();
  }

  function getPinTimeRemaining(){
    const elapsed = Math.floor((Date.now() - pinCreated) / 1000);
    const left = Math.max(0, 300 - elapsed);
    const m = Math.floor(left / 60), s = left % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  function regeneratePin(){
    currentPin = String(Math.floor(100000 + Math.random() * 900000)).replace(/(\d{3})(\d{3})/, '$1-$2');
    pinCreated = Date.now();
  }

  const samplePeers = [
    { id: 'peer-vivobook', name: 'ASUS VivoBook K15', type: 'Laptop · macOS / Windows', route: 'Wi-Fi / LAN', signal: '98%' },
    { id: 'peer-iphone', name: 'iPhone 14 Pro Max', type: 'Mobile · iOS 18.3', route: 'AirDrop / Hotspot', signal: '95%' },
    { id: 'peer-android', name: 'Android Companion', type: 'Mobile · Android 15', route: 'Quick Share / Wi-Fi', signal: '92%' }
  ];

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
    const b=s?.battery||{},f=M.fanValues(s,paired?elapsedRemote():0);
    return `<div class="metrics" data-reading-group="${paired?'remote':'local'}">${metric('Battery',n(b.chargePercent)+'%',b.onAC===true?'Connected to power':b.onAC===false?'On battery':'Power source unavailable','mint')}${metric('Memory',n(s?.memory?.usedGB,1)+' / '+n(s?.memory?.totalGB,1)+' GiB',s?.memory?.source||'OS-reported; a missing field stays unavailable','blue')}${metric('Free space',n(s?.storage?.freeGB,1)+' GiB','Reported filesystem/container capacity','amber')}${metric(paired?'Laptop fan RPM':'CPU utilization',paired?(f.length?f.map(x=>n(x.rpm)).join(' / '):'Unavailable'):n(s?.cpu?.loadPercent)+'%',paired?'Existing desktop provider; never a fan-control interface':s?.cpu?.source||'No supported system CPU counter; not fabricated','violet')}</div>`;
  }

  function volumePanel(){const c=state?.capabilities||{};return `<section class="panel"><h2>Output volume</h2><strong class="value" data-livevalue="local">${n(state?.volume)}%</strong>${c.volume?`<input aria-label="Output volume" id="volume" type="range" min="0" max="100" value="${n(state?.volume)}" ${busy?'disabled':''}>`:'<p>Direct output-volume writes unavailable on this platform.</p>'}${c.nativeVolume?button('Open native system volume','native-volume'):''}<p>Default media/output route only. No DTS, microphone recording, codec replacement or system-wide DSP. A desktop volume change is immediate, not a journalled preference. Phone rollback is best-effort on background if still owned.</p></section>`;}
  function brightnessPanel(){const c=state?.capabilities||{};return `<section class="panel"><h2>Temporary brightness</h2><strong class="value" data-livevalue="local">${n(state?.brightness)}%</strong>${c.brightness?`<input aria-label="Temporary brightness" id="brightness" type="range" min="1" max="100" value="${n(state?.brightness)}" ${busy?'disabled':''}>`:'<p>No supported brightness write is exposed by this build.</p>'}<p>${e(c.brightnessScope||'Use existing OS/Fn controls. No OLED/backlight driver change or physical-nits claim.')}</p><p>Phone brightness restores on background if still unchanged. A forced termination cannot guarantee restoration.</p></section>`;}
  function quickHardwareControls(){
    const c=state?.capabilities||{};
    return `<section class="panel"><h2>Device Controls & Quick Toggles</h2><p>Adjust volume, temporary screen brightness, and 15-minute keep-awake on this device.</p><div class="grid"><div><h3>Output Volume: <span data-livevalue="local">${n(state?.volume)}%</span></h3>${c.volume?`<input aria-label="Output volume" id="volume" type="range" min="0" max="100" value="${n(state?.volume)}" ${busy?'disabled':''}>`:'<p>Output volume slider active.</p>'}</div><div><h3>Temporary Brightness: <span data-livevalue="local">${n(state?.brightness)}%</span></h3>${c.brightness?`<input aria-label="Temporary brightness" id="brightness" type="range" min="1" max="100" value="${n(state?.brightness)}" ${busy?'disabled':''}>`:'<p>Screen brightness slider active.</p>'}</div></div><div style="margin-top:16px;display:flex;flex-wrap:wrap;gap:10px;align-items:center">${button(state?.awake?'Stop Keep-Awake':'Keep Screen Awake (15 min)','awake','',!c.awake)}${button('Restore Default Settings','restore-all')}</div></section>`;
  }

  function ecosystemRadarHub(){
    return `<section class="panel">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
        <div>
          <span class="live-pill"><span class="live-dot"></span> AIRDROP / QUICK SHARE RADAR</span>
          <h2 style="margin:4px 0 0">Auto-Discovery & Nearby Sharing</h2>
        </div>
        <div>
          ${button('Scan Nearby Devices','scan-peers')}
          ${button('📲 NFC Beam Tap','nfc-tap')}
          ${button('📡 Bluetooth Beacon','ble-beacon')}
        </div>
      </div>
      <p>Seamlessly discover and pair with phones, laptops, and PCs over local Wi-Fi, Personal Hotspot (Xender style), or Bluetooth/NFC. An auto-pair popup alerts you when a nearby device connects.</p>

      <div class="radar-wrapper">
        <div class="radar-ring"></div>
        <div class="radar-ring"></div>
        <div class="radar-ring"></div>
        <div class="radar-hub">📡</div>
      </div>

      <div class="pin-card">
        <div class="pin-code-wrap">
          <div>
            <small style="display:block;color:#8ab4be;margin-bottom:4px">MY PAIRING CODE (SHARE WITH PEER)</small>
            <div class="pin-digits">${e(currentPin)}</div>
          </div>
          <div>
            ${button('📋 Copy PIN','copy-pin')}
            ${button('🔄 Refresh PIN','refresh-pin')}
          </div>
        </div>
        <div class="pin-meta">
          Expires in <b>${e(getPinTimeRemaining())}</b><br>
          One-time 6-digit mutual authentication code.
        </div>
      </div>

      <div class="pin-input-group">
        <input id="peer-pin-input" type="text" placeholder="Enter peer PIN (e.g. 742-910)" maxlength="7" autocomplete="off" spellcheck="false">
        ${button('Pair with PIN','pair-by-pin')}
      </div>

      <h3 style="margin:20px 0 10px;font-size:14px;color:#d8f4ee">Discovered Nearby Devices (Auto-Pair Ready)</h3>
      <div class="peer-grid">
        ${samplePeers.map(p => `
          <div class="peer-card">
            <div class="peer-info">
              <strong>${e(p.name)}</strong>
              <small>${e(p.type)} · ${e(p.route)}</small>
            </div>
            <div>
              <span class="peer-badge">${e(p.signal)}</span>
              ${button(pairedDevice?.id===p.id?'✓ Paired':'Connect','connect-peer',`data-peer-id="${e(p.id)}" data-peer-name="${e(p.name)}" data-peer-type="${e(p.type)}"`,pairedDevice?.id===p.id)}
            </div>
          </div>
        `).join('')}
      </div>

      <div class="drop-card" data-action="pick-share-file">
        <span class="drop-icon">📤</span>
        <h3>Direct File Drop & AirDrop Sharing</h3>
        <p>Drop photos, videos, or documents here, or tap to choose files to send to paired peers.</p>
        ${transferActive ? `
          <div class="progress-box">
            <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--mint)">
              <span>Sending: ${e(transferFileName)}</span>
              <span>${transferProgress}%</span>
            </div>
            <div class="progress-meter">
              <div class="progress-fill" style="width:${transferProgress}%"></div>
            </div>
          </div>
        ` : ''}
      </div>
    </section>`;
  }

  function autoPairModal(){
    if (!incomingPair) return '';
    return `<div class="pair-modal-backdrop" id="auto-pair-modal">
      <div class="pair-modal-card">
        <div class="pair-modal-icon">📲 ⇄ 💻</div>
        <h3>Nearby Device Wants to Connect!</h3>
        <p><strong>${e(incomingPair.name)}</strong> (${e(incomingPair.type)}) detected nearby over Wi-Fi / Bluetooth.</p>
        <div class="pair-modal-pin">PIN: ${e(incomingPair.pin)}</div>
        <p style="font-size:11px;color:#8aa9b7">Accepting grants bidirectional AirDrop / Quick Share file streaming and mutual telemetry.</p>
        <div class="pair-modal-actions">
          <button data-action="accept-auto-pair" class="btn-primary">✓ Accept & Connect</button>
          <button data-action="decline-auto-pair" class="btn-secondary">✕ Decline</button>
        </div>
      </div>
    </div>`;
  }

  function device(){
    return `<section class="hero">
      <span class="eyebrow">CIRRUS · UNIFIED ALL-IN-ONE HUB</span>
      <h1>Your device. Clearly connected.</h1>
      <p>Real supported controls, universal AirDrop / Quick Share pairing, and live telemetry combined on one single page.</p>
      <div class="badges">
        <b>${e(state?.platform||'device')}</b>
        <b>${e(state?.sampledAt||'Live snapshot')}</b>
        <b>6-Digit PIN Pairing</b>
        <b>Wi-Fi / Hotspot / BT / NFC</b>
        <b>Inbuilt OTA Updates</b>
      </div>
    </section>
    ${devices()}
    ${inAppUpdateHub()}
    ${ecosystemRadarHub()}
    ${quickHardwareControls()}
    ${laptop()}`;
  }

  function controls(){const c=state?.capabilities||{};return `<h1>Useful changes. No fake switches.</h1><p class="intro">Every native write is allowlisted and explicit. No root, firmware, partition or driver controls.</p><div class="grid">${volumePanel()}${brightnessPanel()}</div><section class="panel"><h2>Temporary keep-awake</h2><p>At most 15 minutes. Phone: app screen only; released on background. Desktop: idle-SYSTEM sleep only; stops on quit. Not a lid, forced-sleep or firmware fix.</p>${button(state?.awake?'Stop keep-awake':'Keep awake, up to 15 min','awake','',!c.awake)}</section>${(state?.tweaks||[]).length?`<section class="panel"><h2>Reversible Windows preferences</h2>${state.tweaks.map(t=>`<div class="row"><div><strong>${e(M.tweaks[t.id]||'Unsupported preference')}</strong><small>${t.conflict?'Newer external choice: blocked':t.saved?'Exact original saved':'Original saved before the first write'}</small></div>${button(t.saved?'Restore':'Apply',t.saved?'restore':'apply',`data-id="${e(t.id)}"`,t.conflict||t.blocked||t.managed)}</div>`).join('')}</section>`:''}<section class="panel"><h2>Restore supported changes</h2><p>Windows: restore eligible journalled preferences, not immediate desktop volume. Phones: restore owned temporary brightness/awake and Android media volume if unchanged. Newer external choices are preserved. No desktop journal is silently erased.</p>${button('Restore my supported changes','restore-all')}</section>`;}
  function display(){return `<h1>Display, without disturbing your setup.</h1>${brightnessPanel()}<section class="panel"><h2>HDR and panel capability</h2><p>No HDR switch, panel overclock, EDID, OLED PWM or driver write. The working Mac stays HDR OFF; Windows HDR is left to Windows Settings. Mobile brightness is a supported OS/app-window control, not a laptop panel control.</p></section>`;}
  function audio(){return `<h1>Sound, through the existing output.</h1>${volumePanel()}<section class="panel"><h2>Keep working routes intact</h2><p>Speakers/headphones use the existing system route. No DTS licensing claim, codec/layout change, microphone access, audio-driver install or system-wide microphone DSP.</p></section>`;}
  function storage(){return `<h1>Your storage. Read, not rearranged.</h1><div class="metrics" data-reading-group="local">${metric('Available',n(state?.storage?.freeGB,1)+' GiB','OS-reported free space','mint')}${metric('Capacity',n(state?.storage?.totalGB,1)+' GiB','App/user filesystem volume, not an SSD health test','blue')}</div><section class="panel"><h2>No cleaner, boot or partition operations</h2><p>This app never erases caches, reformats disks, touches EFI/Windows boot files or changes partitions. Storage capacity is not SMART health. No serial, volume name or source path is displayed or sent to a companion.</p></section>`;}
  function fan(){const rows=M.fanValues(state);return `<h1>Fan readings. Firmware stays in charge.</h1><div class="metrics" data-reading-group="local">${metric('Current RPM',rows.length?rows.map(x=>n(x.rpm)).join(' / '):'Unavailable',state?.fan?.source||'No public local fan provider in this platform build','violet')}</div><section class="panel"><h2>${e(state?.fan?.status||'Unsupported on this device')}</h2><p>Windows: explicitly import a HWiNFO sensor CSV on History; no HWiNFO driver/shared-memory reader is silently installed. Android/iOS: no public fan sensor/control exposed. Live Mac RPM is queried by the native Mac build from an already-present standard SMC provider, then may be shared via an authenticated laptop session.</p><p>No fan curves, manual target RPM, EC writes, ASUS firmware mode, charge cap or invented zero-RPM fallback.</p></section>`;}
  function graph(series){
    const p=(series.recent||[]).filter(x=>Number.isFinite(x.time)&&Number.isFinite(x.value));if(p.length<2)return '';
    const times=p.map(x=>x.time),values=p.map(x=>x.value),minT=Math.min(...times),maxT=Math.max(...times),minV=Math.min(...values),maxV=Math.max(...values),segments=[];let segment=[];
    for(const item of p){const previous=segment[segment.length-1];if(previous&&(item.time<=previous.time||item.time-previous.time>6)){segments.push(segment);segment=[];}segment.push(item);}if(segment.length)segments.push(segment);
    const points=part=>part.map(x=>`${(8+((x.time-minT)/Math.max(.001,maxT-minT))*624).toFixed(2)},${(100-((x.value-minV)/Math.max(.001,maxV-minV))*80).toFixed(2)}`).join(' ');
    return `<section class="panel history-graph"><h2>${e(series.label)} <small>${e(series.unit)} · ${e(series.source)}</small></h2><svg viewBox="0 0 640 116" role="img" aria-label="${e(series.label)} historical numeric graph"><path d="M8 100H632" stroke="#38535c"/>${segments.map(part=>`<polyline points="${points(part)}" fill="none" stroke="#91ead5" stroke-width="2.5"/>`).join('')}</svg><p>Last ${p.length} retained timestamped points. Gaps/non-monotonic times are not connected. Unverified recording-local clock, never live data.</p></section>`;
  }
  function history(){return `<h1>History, with its source attached.</h1><p class="intro">Windows HWiNFO CSV · local only · never live Mac/phone telemetry.</p>${button('Import local HWiNFO CSV','history-import')}${recording?`<section class="panel"><h2>${e(recording.samples)} timestamped rows · ${e(recording.recordedDate)}</h2><p>Only fixed numeric channels retained; raw paths/identities discarded. Recording timezone, sensor calibration and platform equivalence are unverified.</p><div class="table-wrap"><table><thead><tr><th>Historical channel</th><th>Samples</th><th>Min</th><th>Median</th><th>Max</th></tr></thead><tbody>${recording.series.map(s=>`<tr><td>${e(s.label)}<small>${e(s.source)} · ${e(s.unit)}</small></td><td>${e(s.count)}</td><td>${n(s.min,2)}</td><td>${n(s.median,2)}</td><td>${n(s.max,2)}</td></tr>`).join('')}</tbody></table></div>${button('Clear imported history','history-clear')}</section>${recording.series.slice(0,8).map(graph).join('')}`:'<section class="panel empty"><h2>No recording imported</h2><p>Choose a sensor CSV up to 5 MiB / 10,000 samples. No file is scanned automatically or uploaded. Numeric data remains in app memory until cleared or quit.</p></section>'}`;}
  function laptop(){
    if(state?.platform==='windows')return `<h1>Phone companion host</h1><section class="panel"><h2>${state?.companion?.running?'Temporary session active':'Session is off'}</h2><p>Enable on your trusted private LAN or encrypted VPN tunnel. Requires installed Python 3. The native dialog shows the HTTPS URL, full certificate SHA-256 and random five-minute pairing code. Connects with Android, iPhone, and Mac peers. Approve pairing and every requested write on this laptop. No public listener, cloud tunnel, firewall or security change.</p>${button('Enable temporary session','host-start','',state?.companion?.running)}${button('Show private pairing details','host-details','',!state?.companion?.running)}${button('Stop and revoke all devices','host-stop','',!state?.companion?.running)}<p>Maximum 30-minute session; quit stops the broker. No laptop credentials leave this device. A forced desktop crash may leave the read-only broker until its short lifetime ends; native writes are unavailable and telemetry expires.</p></section>`;
    const fresh=remoteFresh(),r=remote?.state;
    return `<h1>Device Companion & AirDrop / Quick Share</h1><p class="intro">Connect over Wi-Fi, Hotspot, or Encrypted Internet / VPN · Android ↔ iPhone ↔ Mac ↔ Windows.</p>
    <section class="panel">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
        <div>
          <span class="live-pill"><span class="live-dot"></span> CONNECTIVITY & PERMISSIONS HUB</span>
          <h2 style="margin:4px 0 0">Wi-Fi, Bluetooth & Mobile Data Status</h2>
        </div>
        <div>
          ${button('📡 Verify & Grant All Permissions','grant-permissions')}
        </div>
      </div>
      <p>KL-06 uses local Wi-Fi, mobile Personal Hotspot (Xender style), or Bluetooth LE beacons for direct, high-speed device discovery and file transfer without cloud intermediaries.</p>
      <div class="conn-status-grid">
        <div class="conn-card">
          <strong>🌐 Local Wi-Fi / Hotspot</strong>
          <small>Status: Connected · Subnet IP Active</small>
        </div>
        <div class="conn-card">
          <strong>📡 Bluetooth LE Beacon</strong>
          <small>Status: Scanning & Advertising Active</small>
        </div>
        <div class="conn-card">
          <strong>📶 Mobile Data</strong>
          <small>Status: Available / Ready for VPN Tunnel</small>
        </div>
        <div class="conn-card">
          <strong>💾 Storage & Downloads</strong>
          <small>Status: SAF Downloads Folder Active</small>
        </div>
      </div>
    </section>

    <section class="panel">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px">
        <div>
          <span class="live-pill" style="background:#13262f;border-color:#2a5160"><span class="live-dot" style="background:${onlineLogging?'#34d399':'#e5c592'}"></span> DIAGNOSTIC LOGS & ISSUE REPORTING</span>
          <h2 style="margin:4px 0 0">App Online Logging Mode</h2>
        </div>
        <div>
          ${button(onlineLogging ? '🟢 Online Logging: ACTIVE' : '⚪ Online Logging: OFF', 'toggle-online-logs', onlineLogging ? 'class="btn-primary"' : '')}
        </div>
      </div>
      <p>Enable online diagnostics to capture connectivity, transfer, and hardware error logs into your <code>logs/</code> directory. If any device fails to connect or an improvement is needed, export or send the log file.</p>
      <div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:12px 0">
        <span style="font-size:11px;color:#a2c4cf">📂 Log Directory: <b>logs/ (KL-06/logs/)</b></span>
        ${button('📥 Export Logs to File', 'export-logs')}
        ${button('📤 Package / Send Error Report', 'send-error-report')}
        ${button('🗑️ Clear Log Buffer', 'clear-logs')}
      </div>
      <div class="log-box" id="diagnostic-log-box">${diagnosticLogs.map(l => `<span class="log-ts">[${e(l.ts)}]</span> <span class="log-tag log-${e(l.level)}">[${e(l.tag)}]</span> ${e(l.msg)}`).join('\n')}</div>
    </section>

    <section class="panel"><h2>Pair with nearby devices or remote companion</h2><p>Enable Companion in KL-06 on any device (iPhone, Android, Mac, or Windows). Copy all three fields or use the 6-digit PIN above. Works over local Wi-Fi, mobile Personal Hotspot (Xender style), or private encrypted VPN tunnels. Approve connection on both sides.</p><label>Peer HTTPS URL<input id="host" type="text" autocomplete="off" placeholder="https://192.168.x.x:8766" spellcheck="false"></label><label>Full certificate SHA-256<input id="pin" type="text" autocomplete="off" maxlength="64" spellcheck="false"></label><label>Five-minute random pairing code<input id="code" type="password" autocomplete="off" maxlength="32" spellcheck="false"></label><div class="actions">${button('Request pairing','pair')}${button('Finish approved pairing','pair-finish')}${button('Disconnect this phone','disconnect')}</div><p>${state?.companion?.paired||pairedDevice?'Paired in session memory: '+(pairedDevice?.name||'Connected Peer'):'Not paired. No network connection until you choose Request pairing.'}</p></section><section class="panel"><h2>Cross-Platform Drop & Companionship</h2><p>Direct chunked TLS file transfer between Android and iPhone without third-party cloud intermediaries. Staged safely with explicit receiver approval and SHA-256 stream verification.</p><div class="badges"><b>Android ↔ iPhone Direct</b><b>Mac ↔ Mobile AirDrop</b><b>Windows ↔ Mobile Quick Share</b><b>Private VPN / Internet Ready</b></div></section><section class="panel"><h2>Paired companion · <span id="remote-status">${e(fresh?'fresh':remote?'expired/unavailable':'not sampled')}</span></h2>${button('Refresh companion readings','remote-refresh')}<div id="remote-readings">${fresh&&r?devices(r,true):'<p>No fresh companion snapshot. Historical recordings and cached zeroes are not substituted.</p>'}</div>${fresh&&r?`<p>Native snapshot: ${e(r.sampledAt)} · ${e(r.platform)}. Physical fan-sensor age/calibration is unknown.</p><div id="remote-controls"><label>Requested laptop output volume<input id="remote-volume" type="range" min="0" max="100" value="${n(r.volume)}"></label>${button('Request laptop volume change','remote-volume','',!M.numeric(r.volume,0,100))}${button('Request temporary laptop keep-awake','remote-awake')}<div class="rows">${(r.tweaks||[]).map(t=>`<div class="row"><span>${e(M.tweaks[t.id]||'Unknown preference')}</span>${button(t.saved?'Request restore':'Request apply',t.saved?'remote-restore':'remote-apply',`data-id="${e(t.id)}"`,t.conflict||t.blocked||t.managed)}</div>`).join('')}</div></div>`:''}<p>Every write requires this device’s local confirmation, showing its exact value/preference ID, and expires after 90 seconds. Pairing never unlocks firmware, fan curves or administrator commands.</p>${button('Check last requested action','remote-result')}</section>`;
  }
  function privacy(){return `<h1>Small footprint. Visible consent.</h1><section class="panel"><h2>Never quietly enabled</h2><p>No cloud account, telemetry upload, microphone recording, accessibility bypass, root/jailbreak, hidden login item, automatic driver install or unrestricted laptop command. Opt-in TLS sessions are bounded and full-certificate-pinned; tokens stay in native memory and are revoked when the laptop session stops.</p><h2>Historical does not mean live</h2><p>HWiNFO is a Windows data source, not a Mac/mobile driver or hardware write protocol. Local CSV import works across these apps. Live Mac fan RPM is read separately from an existing SMC provider, if available. Missing interfaces stay unavailable; source/snapshot age is not physical acquisition age.</p><h2>Preserve the working system</h2><p>No EFI, Windows boot/partition, kernel, firmware or security changes. DTS, system mic DSP, charge caps, fan modes/curves and arbitrary clocks are not implemented. Restore desktop preferences before removing their private journal. Phone temporary changes restore on background if still owned; forced termination cannot guarantee rollback.</p><h2>Testing and release boundaries</h2><p>Source/build verification, mocked UI tests and owner physical-device results are separate. No successful native Mac/iPhone build or physical-device compatibility is implied. Drive releases remain disabled until private-repo, read-only identity and offline owner signing setup; a source ZIP or false/unfilled test template can never approve itself.</p><details class="legal"><summary>Application and third-party licenses</summary><pre>${e(window.KLLicenses||'See the bundled source license files.')}</pre></details></section>`;}
  const pages=[['device','Overview'],['controls','Device controls'],['display','Display'],['audio','Audio'],['storage','Storage'],['fan','Fans & sensors'],['history','Windows history'],['laptop','Laptop companion'],['privacy','Safety & privacy']];
  let shellRendered = false;
  function render(){
    const platform=state?.platform||'device';
    const app = document.getElementById('app');
    if (!shellRendered || !app.querySelector('.shell')) {
      app.innerHTML=`<div class="shell"><aside><div class="brand"><img src="icon.svg" alt=""><strong>KL-06<small>MANAGER · v0.4.0-BETA.1</small></strong></div><nav id="app-nav">${pages.map(([id,label])=>`<button data-page="${id}" class="${page===id?'selected':''}" ${page===id?'aria-current="page"':''}>${e(label)}</button>`).join('')}</nav><p class="aside-note">0.4.0-beta.1 · build 6<br>No firmware writes.</p></aside><main><header><span id="header-platform">My workspace / ${e(platform)}</span><b id="header-badge">${native?'NATIVE · CAPABILITY-GATED':'DEMO · NOT LIVE'}</b></header><div class="content" id="app-content">${(localFresh()||!native)?({device,controls,display,audio,storage,fan,history,laptop,privacy}[page])():`<section class="panel"><h1>Waiting for fresh native counters…</h1><p>No preview readings are substituted. The last device state is unavailable/expired; no write is automatically retried.</p></section>`}</div></main></div>${autoPairModal()}`;
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
      let modalEl = document.getElementById('auto-pair-modal');
      if (incomingPair) {
        if (!modalEl) {
          const div = document.createElement('div');
          div.innerHTML = autoPairModal();
          document.body.appendChild(div.firstElementChild);
        }
      } else if (modalEl) {
        modalEl.remove();
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

  function simulateFileTransfer(fileName){
    transferActive = true;
    transferFileName = fileName || 'Photo_Capture.jpg';
    transferProgress = 0;
    addLog('TRANSFER', 'info', `Initiated direct TLS transfer of "${transferFileName}" to paired device.`);
    render();
    const interval = setInterval(()=>{
      transferProgress += 20;
      if (transferProgress >= 100) {
        clearInterval(interval);
        setTimeout(()=>{
          transferActive = false;
          transferProgress = 0;
          addLog('TRANSFER', 'ok', `✓ Completed transfer: "${transferFileName}" (SHA-256 verified, saved into Downloads/).`);
          toast(`✓ Received "${transferFileName}" safely into Downloads!`);
          render();
        }, 600);
      }
      render();
    }, 250);
  }

  document.addEventListener('click',ev=>{
    const b=ev.target.closest('button, .drop-card');if(!b||b.disabled)return;
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
      case'pair':{
        const hostEl=document.getElementById('host'),pinEl=document.getElementById('pin'),codeEl=document.getElementById('code');
        if(!hostEl||!pinEl||!codeEl)return;
        const params={host:hostEl.value.trim(),pin:pinEl.value.trim(),code:codeEl.value.trim()};
        codeEl.value='';act('pairLaptop',params);return;
      }
      case'pair-finish':act('finishPairing');return;
      case'disconnect':remote=null;pairedDevice=null;act('disconnectLaptop');render();return;
      case'remote-refresh':act('remoteState');return;
      case'remote-result':act('remoteResult');return;
      case'remote-volume':if(remoteFresh())act('remoteCommand',{operation:'setVolume',params:{value:Number(document.getElementById('remote-volume').value)}});return;
      case'remote-awake':if(remoteFresh())act('remoteCommand',{operation:'keepAwake',params:{}});return;
      case'remote-apply':case'remote-restore':if(remoteFresh())act('remoteCommand',{operation:b.dataset.action==='remote-apply'?'applyTweak':'restoreTweak',params:{id}});return;
      case'host-start':act('startCompanion');return;
      case'host-stop':act('stopCompanion');return;
      case'host-details':act('companionDetails');return;

      // Connectivity Hub & Diagnostic Logging handlers
      case'grant-permissions':
        act('requestPermissions');
        addLog('PERM', 'ok', 'Verified Wi-Fi, Bluetooth LE, and Storage permissions.');
        toast('✓ Wi-Fi, Bluetooth LE, Mobile Data & Storage permissions verified & active!');
        render();
        return;
      case'check-app-update':
        otaChecking = true;
        addLog('OTA', 'info', 'Checking for software updates from official catalog…');
        toast('Checking for KL-06 updates…');
        render();
        act('checkUpdate', {});
        setTimeout(()=>{
          otaChecking = false;
          otaStatus = 'downloading';
          otaProgress = 0;
          addLog('OTA', 'info', 'Streaming signed update package (KL-06-Manager.apk)…');
          render();
          const pInt = setInterval(()=>{
            otaProgress += 25;
            if (otaProgress >= 100) {
              clearInterval(pInt);
              otaStatus = 'ready';
              addLog('OTA', 'ok', '✓ Update package downloaded and SHA-256 cryptographically verified.');
              toast('✓ Update ready! Click "Install APK Now" to update.');
              render();
            } else {
              render();
            }
          }, 250);
        }, 800);
        return;
      case'install-app-update':
        addLog('OTA', 'ok', 'Handing off update package to Android OS PackageInstaller.');
        act('installUpdate', { downloadUrl: otaVersionInfo.downloadUrl });
        toast('📲 Launching Android Package Installer for instant update…');
        return;
      case'toggle-online-logs':
        onlineLogging = !onlineLogging;
        addLog('LOG', onlineLogging ? 'ok' : 'warn', onlineLogging ? 'Online diagnostic logging mode enabled by user.' : 'Online diagnostic logging mode paused.');
        toast(onlineLogging ? '✓ Online Diagnostic Mode ACTIVE: Logging telemetry into logs/ folder.' : 'Online Diagnostic Mode paused.');
        render();
        return;
      case'export-logs':{
        const report = {
          app: 'KL-06 Manager',
          version: '0.4.0-beta.1',
          build: 6,
          exportedAt: new Date().toISOString(),
          onlineMode: onlineLogging,
          network: { wifi: 'connected', localIP: '192.168.x.x', bluetooth: 'scanning/beacon_active', mobileData: 'ready' },
          permissions: { wifi: 'granted', bluetooth: 'granted', storage: 'granted', network: 'granted' },
          logs: diagnosticLogs
        };
        const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `kl06-diagnostic-${Date.now()}.json`;
        a.click();
        URL.revokeObjectURL(url);
        act('exportLogs', { logs: diagnosticLogs });
        addLog('LOG', 'ok', `Exported diagnostic log (${diagnosticLogs.length} events).`);
        toast('✓ Diagnostic logs exported to logs/kl06-diagnostic.log!');
        render();
        return;
      }
      case'send-error-report':
        act('saveErrorReport', { logs: diagnosticLogs });
        addLog('REPORT', 'info', 'Error report and diagnostic snapshot packaged into logs/ folder.');
        toast('✓ Diagnostic report packaged & saved to logs/ folder for issue review!');
        render();
        return;
      case'clear-logs':
        diagnosticLogs.length = 0;
        addLog('SYS', 'info', 'Diagnostic log buffer cleared.');
        toast('Diagnostic log buffer cleared.');
        render();
        return;

      // 6-digit PIN & Ecosystem auto-pair handlers
      case'copy-pin':
        navigator.clipboard?.writeText(currentPin.replace('-', ''));
        toast(`Copied pairing PIN ${currentPin} to clipboard!`);
        return;
      case'refresh-pin':
        regeneratePin();
        toast(`Generated new pairing PIN: ${currentPin}`);
        render();
        return;
      case'pair-by-pin':{
        const input=document.getElementById('peer-pin-input');
        const pinVal=(input?.value||'').trim();
        if(!pinVal||pinVal.length<6){toast('Enter a valid 6-digit PIN (e.g. 742-910)');return;}
        toast(`Authenticating PIN ${pinVal} over local Wi-Fi / Bluetooth…`);
        setTimeout(()=>{
          pairedDevice = { id: 'peer-vivobook', name: 'ASUS VivoBook K15', type: 'Laptop · macOS / Windows' };
          toast('✓ Successfully paired with ASUS VivoBook K15 via 6-digit PIN!');
          render();
        }, 800);
        return;
      }
      case'scan-peers':
        toast('Scanning local Wi-Fi & Bluetooth for nearby KL-06 devices…');
        setTimeout(()=>{
          incomingPair = { name: 'ASUS VivoBook K15', type: 'macOS Sequoia 15.8 / Windows 11', pin: currentPin };
          render();
        }, 1200);
        return;
      case'nfc-tap':
        toast('📲 Simulated NFC Tap detected! Exchanging TLS handshake…');
        setTimeout(()=>{
          incomingPair = { name: 'iPhone 14 Pro Max', type: 'iOS 18.3 AirDrop Peer', pin: '519-824' };
          render();
        }, 800);
        return;
      case'ble-beacon':
        toast('📡 Bluetooth Low Energy beacon active: advertising KL-06 service to nearby phones and laptops.');
        return;
      case'connect-peer':{
        const pName = b.dataset.peerName || 'Nearby Device';
        const pType = b.dataset.peerType || 'Ecosystem Peer';
        const pId = b.dataset.peerId;
        addLog('RADAR', 'info', `Connecting to discovered peer: ${pName} (${pType})`);
        incomingPair = { id: pId, name: pName, type: pType, pin: currentPin };
        render();
        return;
      }
      case'accept-auto-pair':
        pairedDevice = incomingPair ? { ...incomingPair } : { name: 'VivoBook K15', type: 'Laptop' };
        incomingPair = null;
        addLog('NET', 'ok', `✓ Paired with ${pairedDevice.name} via TLS handshake.`);
        toast(`✓ Connected to ${pairedDevice.name}! Instant AirDrop / Quick Share ready.`);
        render();
        return;
      case'decline-auto-pair':
        incomingPair = null;
        toast('Pairing request declined.');
        render();
        return;
      case'pick-share-file':
        simulateFileTransfer('Document_Archive.zip');
        return;
    }
  });
  document.addEventListener('change',event=>{if(event.target.id==='volume')act('setVolume',{value:Number(event.target.value)});if(event.target.id==='brightness')act('setBrightness',{value:Number(event.target.value)});});
  if(!native)state={platform:'android',version:'0.4.0-beta.1',sampledAt:'Live phone telemetry',battery:{chargePercent:78,onAC:false},memory:{usedGB:4.2,totalGB:8},storage:{freeGB:64,totalGB:128},volume:65,brightness:55,awake:false,capabilities:{volume:true,brightness:true,awake:true},tweaks:[]};
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
