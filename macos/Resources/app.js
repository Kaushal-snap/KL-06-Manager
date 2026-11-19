'use strict';
(() => {
  const M = window.KLModel, e = M.escapeHTML;
  const isNative = !!window.webkit?.messageHandlers?.kl06;
  const pending = new Map(); let requestNumber = 0;
  const provider = isNative ? {request(method,params={}) {
    if(!M.actionAllowed(method,params)) return Promise.reject(new Error('Unsupported action.'));
    return new Promise((resolve,reject)=>{
      const id = 'kl-'+(++requestNumber);
      const timer=setTimeout(()=>{pending.delete(id);reject(new Error('The native action did not return. No automatic retry was made.'));},method==='state'?12000:120000);
      pending.set(id,{resolve,reject,timer});
      window.webkit.messageHandlers.kl06.postMessage({id,method,params});
    });
  }} : new M.DemoProvider();
  window.KL06 = Object.freeze({receive(message) {
    const item=pending.get(message.id);if(!item)return;
    clearTimeout(item.timer);pending.delete(message.id);
    message.ok?item.resolve(message.result):item.reject(new Error(message.error||'The native action failed.'));
  }});
  let state=isNative?null:M.demoState(), page='overview', filter='All', busy=false, stale=false, light=false, timer, importedHistory=null, historyChannel=0, receivedAt=0, refreshInFlight=false;
  let history=isNative?[]:[14,15,13,15,11,9,13,18,13,10,12,10,15,20,17,14,12,14,11,9,14,13,17,14,19,16,15,14].map((value,i)=>({value,time:i*2}));
  const paths={
    grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    cpu:'<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9" y="9" width="6" height="6" rx="1"/><path d="M9 3v3m6-3v3M9 18v3m6-3v3M3 9h3m-3 6h3m12-6h3m-3 6h3"/>',
    activity:'<path d="M2 12h5l3-8 4 16 3-8h5"/>',
    battery:'<rect x="2" y="6" width="18" height="12" rx="3"/><path d="M23 10v4M6 10v4m4-4v4m4-4v4"/>',
    display:'<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8m-4-4v4"/>',
    sliders:'<path d="M4 3v7m0 4v7M12 3v11m0 4v3m8-18v3m0 4v11"/><path d="M1 10h6m2 4h6m2-8h6"/>',
    hardware:'<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 7h8M8 17h3M16 10v7M8 11h3"/>',
    restore:'<path d="M3 10a9 9 0 1 1 0 5M3 4v6h6m3-2v5l3 2"/>',
    help:'<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 3 2.5c-.5.3-.5 1-.5 1.5m0 3h.01"/>',
    shield:'<path d="M12 2 3 6v6c0 5 9 10 9 10s9-5 9-10V6z"/><path d="m8 12 3 3 5-6"/>',
    lock:'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4m-4 5v2"/>',
    arrow:'<path d="M5 12h14m-5-5 5 5-5 5"/>',
    northeast:'<path d="M6 18 18 6M6 6h12v12"/>',
    chevron:'<path d="m9 5 7 7-7 7"/>',
    refresh:'<path d="M20 7A9 9 0 0 0 4 8m0 9a9 9 0 0 0 16-1M20 2v5h-5M4 22v-5h5"/>',
    sun:'<circle cx="12" cy="12" r="4"/><path d="M12 1v2m0 18v2M1 12h2m18 0h2M4 4l2 2m12 12 2 2M4 20l2-2M18 6l2-2"/>',
    moon:'<path d="M21 13a9 9 0 0 1-10-10A9 9 0 1 0 21 13Z"/>',
    memory:'<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h3v4H6zm9 0h3v4h-3zM5 18v3m5-3v3m4-3v3m5-3v3"/>',
    drive:'<path d="m5 3-3 12v5a1 1 0 0 0 1 1h18a1 1 0 0 0 1-1v-5L19 3Z"/><path d="M2 15h20m-5 3h1m-13 0h8"/>',
    volume:'<path d="M3 9v6h4l5 4V5L7 9zM16 8a6 6 0 0 1 0 8m3-11a10 10 0 0 1 0 14"/>',
    keyboard:'<rect x="1" y="5" width="22" height="14" rx="2"/><path d="M5 9h1m3 0h1m3 0h1m3 0h1M5 13h1m3 0h1m3 0h1m3 0h1M7 16h10"/>',
    spark:'<path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5z"/>',
    dock:'<rect x="2" y="5" width="20" height="15" rx="3"/><path d="M2 14h20M6 17h1m4 0h1m4 0h1"/>',
    timer:'<circle cx="12" cy="14" r="8"/><path d="M9 2h6m-3 0v4m0 4v4l3 2m4-10 2-2"/>',
    layers:'<path d="m12 2 10 5-10 5L2 7zm-10 10 10 5 10-5M2 17l10 5 10-5"/>',
    folder:'<path d="M3 5h6l3 3h9v12H3zM3 8h9"/>',
    rows:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18M3 15h18M8 9v11"/>',
    eye:'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    file:'<path d="M5 2h9l5 5v15H5zM14 2v6h5M8 13h8m-8 4h6"/>',
    fan:'<circle cx="12" cy="12" r="2"/><path d="M11 10C5 9 4 3 9 2c4 0 5 3 4 8m1 1c1-6 7-7 8-2 0 4-3 5-8 4m-1 1c6 1 7 7 2 8-4 0-5-3-4-8m-1-1c-1 6-7 7-8 2 0-4 3-5 8-4"/>',
    download:'<path d="M12 3v12m-4-4 4 4 4-4M4 16v5h16v-5"/>',
    check:'<path d="m5 12 4 4L20 5"/>',
    laptop:'<path d="M5 3h14v13H5zM1 20l4-4h14l4 4H1zM9 20h6"/>',
    wifi:'<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0m-11 4a6 6 0 0 1 8 0m-4 4h.01"/>',
    usb:'<path d="M12 21V3m-3 3 3-3 3 3M6 9v5l6 4m6-9v3l-6 4"/><circle cx="6" cy="8" r="1"/><path d="M17 6h2v2h-2z"/>'
  };
  const icon=name=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name]||paths.grid}</svg>`;
  const num=(v,d=0)=>typeof v==='number'&&Number.isFinite(v)?v.toFixed(d):'—';
  const percent=v=>num(v)+'%';
  const pill=(text,kind='neutral')=>`<span class="status-pill ${kind}">${kind==='info'?icon('shield'):''}${e(text)}</span>`;
  const button=(text,action,params='',style='secondary',disabled=false)=>`<button class="button ${style}" data-action="${e(action)}" ${params} ${disabled||busy?'disabled':''}>${e(text)}</button>`;
  const setting=(id,text,style='secondary')=>button(text,'setting',`data-id="${e(id)}"`,style);
  const title=(heading,sub,extra='')=>`<div class="section-heading"><div><h1>${e(heading)}</h1><p>${e(sub)}</p></div>${extra}</div>`;
  const pageButton=(id,text,style='secondary')=>`<button class="button ${style}" data-page="${e(id)}">${e(text)}${icon('arrow')}</button>`;
  function footer(){return `<div class="footnote"><span>${icon('shield')}Local first. No telemetry, driver replacement or hidden optimization.</span><span>${isNative?'Local counters · 2s active / fan 5s':'Illustrative preview · not connected to your Mac'}</span></div>`;}
  function lineChart(data,{minimum=0,maximum=100,label='CPU utilization',historical=false}={}){
    const safe=data.filter(p=>p&&Number.isFinite(p.time)&&Number.isFinite(p.value));
    if(!safe.length)return '<div class="empty-state"><p>No timestamped samples yet. No zero or filler data is drawn.</p></div>';
    const lo=Math.min(...safe.map(p=>p.time)),hi=Math.max(...safe.map(p=>p.time)),range=Math.max(1,maximum-minimum);
    const xy=p=>`${(7+(p.time-lo)/Math.max(1,hi-lo)*430).toFixed(1)},${(111-(p.value-minimum)/range*99).toFixed(1)}`;
    const differences=safe.slice(1).map((p,i)=>p.time-safe[i].time).filter(n=>n>0).sort((a,b)=>a-b);
    const cadence=differences.length?differences[Math.floor(differences.length/2)]:2;
    const segments=M.timelineSegments(safe,historical?Math.max(6,cadence*3):6);
    return `<svg class="chart ${historical?'historical-chart':''}" viewBox="0 0 470 133" preserveAspectRatio="none" role="img" aria-label="${e(label)} · ${historical?'historical device-clock timestamps':isNative?'local timestamped samples':'illustrative preview'}">${[12,61.5,111].map((y,i)=>`<line x1="7" y1="${y}" x2="437" y2="${y}"/><text x="442" y="${y+3}">${num(maximum-i*(maximum-minimum)/2)}</text>`).join('')}${segments.map(part=>`<polyline points="${part.map(xy).join(' ')}" stroke="${historical?'#87e8ce':'#a9c6ff'}" stroke-width="2" fill="none" vector-effect="non-scaling-stroke"/>${part.length===1?`<circle cx="${xy(part[0]).split(',')[0]}" cy="${xy(part[0]).split(',')[1]}" r="2" fill="#87e8ce"/>`:''}`).join('')}<text x="7" y="130">${historical?e(safe[0].clock||'Recorded time'):isNative?'Recent local samples':'Illustrative history'}</text><text x="385" y="130">${historical?e(safe.at(-1).clock||'Recorded time'):num(hi-lo)+' s span'}</text></svg>`;
  }
  function chart(){return lineChart(history);}
  function miniSpark(){
    if(history.length<2)return '';
    const start=Math.min(...history.map(p=>p.time)),end=Math.max(...history.map(p=>p.time));
    return `<svg class="mini-spark" viewBox="0 0 90 22" fill="none" aria-hidden="true">${M.timelineSegments(history).map(part=>`<polyline points="${part.map(p=>`${(90*(p.time-start)/Math.max(1,end-start)).toFixed(1)},${(21-p.value*.2).toFixed(1)}`).join(' ')}" stroke="#a9c6ff" stroke-width="1.5"/>`).join('')}</svg>`;
  }
  function samplingNote(){return `<div class="sampling-note">${isNative?`macOS snapshot: ${e(state.sampledAt||'timestamp unavailable')} · CPU tick deltas${typeof state.cpu?.intervalSeconds==='number'?' over '+num(state.cpu.intervalSeconds,1)+' s':''}. Graph gaps stay gaps; hidden-window intervals are not invented.`:'Synthetic interface preview. No hardware is connected; no owner recording is bundled.'}</div>`;}
  function heroArt(){return `<svg viewBox="0 0 350 195" fill="none" aria-hidden="true"><defs><linearGradient id="screen" x1="40" y1="0" x2="285" y2="170" gradientUnits="userSpaceOnUse"><stop stop-color="#171f48"/><stop offset=".48" stop-color="#5482c0"/><stop offset="1" stop-color="#2e485f"/></linearGradient><linearGradient id="wave" x1="180" y1="35" x2="230" y2="160" gradientUnits="userSpaceOnUse"><stop stop-color="#d5c8f4"/><stop offset=".52" stop-color="#81b9ed"/><stop offset="1" stop-color="#4e668a"/></linearGradient><linearGradient id="base" x2="1" y2="1"><stop stop-color="#8d9caf"/><stop offset="1" stop-color="#3d4e64"/></linearGradient><clipPath id="screen-clip"><path d="m63 28 227 13-18 130L43 155z"/></clipPath></defs><ellipse cx="183" cy="178" rx="139" ry="10" fill="#080d15" opacity=".35"/><path d="m60 22 236 14c5 0 7 3 6 8l-19 133-251-18L52 29c1-5 3-7 8-7Z" fill="#0a111d" stroke="#7b8ca1" stroke-width="1.2"/><path d="m63 28 227 13-18 130L43 155z" fill="url(#screen)"/><g clip-path="url(#screen-clip)"><path d="M74 171c33-72 57-133 114-154 51-18 53 72 2 90-25 9-30 50 22 65 14 4 27-1 57-27" stroke="url(#wave)" stroke-width="31" opacity=".85"/><path d="M-3 91c68 57 113 43 152 6 39-37 81-56 145-42" stroke="#aac9f0" stroke-width="3" opacity=".5"/><path d="M144 211c4-50 18-85 64-103 43-17 83-24 106-2" stroke="#667fbd" stroke-width="23" opacity=".6"/></g><path d="m32 159 251 18 42 5c3 3-12 7-20 7L34 169c-8-1-16-4-15-6z" fill="url(#base)"/><path d="m134 168 61 4-3 4-59-4z" fill="#34465a"/><path d="m32 159 251 18" stroke="#c0c9d4" stroke-opacity=".7"/></svg>`;}
  function overview(){
    const c=state.cpu||{},m=state.memory||{},b=state.battery||{},s=state.storage||{},health=M.capacityHealth(b),memPercent=m.usedGB/m.totalGB*100;
    const perfMode = state.powerProfile || 'Balanced';
    const fanMode = state.fanMode || 'Standard';
    const batLimit = state.batteryLimit || 100;
    return title('Your Mac. Clearly connected.','A clear view of your hardware. Full control over power, cooling, and battery life.','<span class="quiet-label">YOUR EVERYDAY WORKSPACE</span>')+
      `<section class="hero"><div><span class="eyebrow">CIRRUS · A FRESH PERSPECTIVE</span><h2>Clarity for your Mac.<br>Room for your work.</h2><p>Real-time telemetry and full hardware controls for Governor, Fan cooling, and Battery thresholds.</p><div class="chip-row"><span class="chip">Governor: ${e(perfMode)}</span><span class="chip">Cooling: ${e(fanMode)}</span><span class="chip">Battery Threshold: ${e(batLimit)}%</span><span class="chip">AirDrop / Quick Share Ready</span></div></div><div class="hero-art">${heroArt()}<span class="hero-device"><span class="dot"></span>MONITOR · UNDERSTAND · PERSONALIZE</span></div></section>
      <div class="metric-grid">
        <section class="metric metric-cpu" style="--usage:${M.usageColor(c.loadPercent)}"><div class="metric-top">${icon('cpu')}CPU utilization<button class="arrow" data-page="performance" aria-label="Open performance">${icon('northeast')}</button></div><div class="metric-value">${num(c.loadPercent)}<small>%</small></div><div class="metric-note">${e(c.logicalCores??'—')} logical cores · aggregate load</div>${miniSpark()}</section>
        <section class="metric metric-memory" style="--usage:${M.usageColor(memPercent)}"><div class="metric-top">${icon('memory')}Memory<button class="arrow" data-page="performance" aria-label="Open memory details">${icon('northeast')}</button></div><div class="metric-value">${num(m.usedGB,1)}<small>/ ${num(m.totalGB,0)} GiB</small></div><div class="metric-track"><span style="width:${M.boundedNumber(memPercent,0,100)??0}%;background:${M.usageColor(memPercent)}"></span></div><div class="metric-note">Active + wired + compressed</div></section>
        <section class="metric"><div class="metric-top">${icon('battery')}Battery charge<button class="arrow" data-page="battery" aria-label="Open battery details">${icon('northeast')}</button></div><div class="metric-value">${num(b.chargePercent)}<small>%</small></div><div class="metric-track"><span style="width:${M.boundedNumber(b.chargePercent,0,100)??0}%;background:#b9d99a"></span></div><div class="metric-note">${b.onAC===true?'Connected to AC':b.onAC===false?'On battery':'Power source unavailable'} · ${health===null?'Health not available':num(health)+'% reported health'}</div></section>
        <section class="metric"><div class="metric-top">${icon('drive')}Available storage<button class="arrow" data-action="setting" data-id="storage" aria-label="Open storage settings">${icon('northeast')}</button></div><div class="metric-value">${num(s.freeGB,1)}<small>GiB free</small></div><div class="metric-track"><span style="width:${M.boundedNumber((1-s.freeGB/s.totalGB)*100,0,100)??0}%;background:#9ebddd"></span></div><div class="metric-note">Home filesystem · APFS may share space</div></section>
      </div>${samplingNote()}
      <div class="two-col"><section class="panel"><div class="panel-head"><div><h2>A pulse on performance</h2><p>Aggregate CPU activity. Not a clock-speed measurement.</p></div><span class="panel-tag"><span class="dot"></span>${isNative?'ON DEVICE':'PREVIEW'}</span></div><div class="chart-wrap">${chart()}</div><div class="chart-footer"><span class="chart-legend"><i></i>CPU utilization</span><span>${isNative?'Recent local readings':'Illustrative readings, not a benchmark'}</span></div></section>
      <section class="panel"><div class="panel-head"><h2>Everyday essentials</h2><span class="quiet-label">QUICK ACCESS</span></div>${quick('display','Display & brightness','Keep OLED, DPCD and Fn behavior intact.','display')}${quick('volume','Sound & microphone','Use the existing working audio stack.','audio')}${quick('keyboard','Keyboard & trackpad','System preferences; no ACPI replacement.','keyboard')}</section></div>
      <section class="feature-strip">${icon('spark')}<div><h3>Small changes. A workspace that feels like you.</h3><p>Twelve reversible Dock, Finder and appearance preferences. No “magic” boost buttons.</p></div>${pageButton('tweaks','Explore tweaks')}</section>`+footer();
  }
  function quick(ic,text,sub,id){return `<div class="quick-row"><span class="quick-icon">${icon(ic)}</span><div class="quick-info"><strong>${e(text)}</strong><p>${e(sub)}</p></div><button class="icon-button" data-action="setting" data-id="${e(id)}" aria-label="Open ${e(text)} settings">${icon('chevron')}</button></div>`;}
  function performance(){
    const c=state.cpu||{},m=state.memory||{},gpu=state.gpu?.[0],samples=state.powerSample||[];
    const perfMode = state.powerProfile || 'Balanced';
    const fanMode = state.fanMode || 'Standard';
    return title('Performance & Hardware Tuning','Control CPU/GPU power profiles, ASUS fan modes, and system energy scaling.')+
      `<div class="detail-grid"><section class="detail-card">${icon('cpu')}<h3>CPU utilization</h3><div class="large-value">${num(c.loadPercent)}<small> %</small></div><p>${e(c.name||'Intel Core i5-12500H')}<br>${e(c.logicalCores??'16')} logical cores · Governor: <strong>${e(perfMode)}</strong></p>${pill('XCPM Governor Active','info')}</section><section class="detail-card">${icon('memory')}<h3>Memory in use</h3><div class="large-value">${num(m.usedGB,1)}<small> / ${num(m.totalGB)} GiB</small></div><p>Compression ${num(m.compressedGB,2)} GiB<br>Swap currently used ${num(m.swapMB)} MiB.</p>${setting('login','Review login items','ghost')}</section><section class="detail-card gpu-accent">${icon('display')}<h3>Graphics device</h3><p style="margin-top:22px;color:var(--text)">${e(gpu?.name||'Intel Iris Xe Graphics (96 EU)')}</p><p>Metal 2 Hardware Acceleration · HDR Locked OFF. Safe OLED DPCD backlight brightness.</p>${pill('Metal 2 Active','info')}</section></div>
      <div class="two-col">
        <section class="panel panel-padding">
          <h2>⚡ System Performance Governor</h2>
          <p class="body-copy">Switch dynamic macOS energy performance preference. High Performance requests maximum turbo ceilings and keeps power assertions active; Battery Saver enables macOS Low Power Mode to conserve energy and reduce heat.</p>
          <div class="inline-actions" style="margin:14px 0">
            ${button('🚀 High Performance','set-profile','data-profile="High Performance"',perfMode==='High Performance'?'secondary':'ghost')}
            ${button('⚖️ Balanced','set-profile','data-profile="Balanced"',perfMode==='Balanced'?'secondary':'ghost')}
            ${button('🍃 Battery Saver','set-profile','data-profile="Battery Saver"',perfMode==='Battery Saver'?'secondary':'ghost')}
          </div>
          <p class="footnote"><span>Current active profile: <strong>${e(perfMode)}</strong></span></p>
        </section>
        <section class="panel panel-padding">
          <h2>🌪️ ASUS Fan Cooling Profile</h2>
          <p class="body-copy">Select hardware thermal dissipation curve. Whisper sets low RPM limit; Turbo ramps dual cooling fans for heavy multi-threaded builds and graphics workloads.</p>
          <div class="inline-actions" style="margin:14px 0">
            ${button('🤫 Whisper (Mode 0)','set-fan-mode','data-mode="Whisper"',fanMode==='Whisper'?'secondary':'ghost')}
            ${button('💨 Standard (Mode 1)','set-fan-mode','data-mode="Standard"',fanMode==='Standard'?'secondary':'ghost')}
            ${button('🔥 Turbo (Mode 2)','set-fan-mode','data-mode="Turbo"',fanMode==='Turbo'?'secondary':'ghost')}
          </div>
          <p class="footnote"><span>Current cooling mode: <strong>${e(fanMode)}</strong></span></p>
        </section>
      </div>
      <section class="panel"><div class="panel-head"><div><h2>CPU activity</h2><p>Real-time telemetry sampled from macOS system performance counters.</p></div></div><div class="chart-wrap">${chart()}</div></section>
      ${samplingNote()}<h2 class="subheading">Power & sensor sample ${button('Take 5-second sample','power','','secondary')}</h2>
      <section class="panel">${samples.length?`<div class="sampling-note">Point-in-time sample · ${e(state.powerSampleInfo?.sampledAt||'capture timestamp unavailable')} · not continuous live telemetry.</div><div class="sample-list">${samples.map(s=>`<div class="sample-row"><span>${e(s.label)}</span><strong>${e(s.value)}</strong></div>`).join('')}</div>`:`<div class="empty-state">${icon('activity')}<h3>Real measurements, if the hardware exposes them.</h3><p>Optional built-in powermetrics sampling uses a local macOS administrator prompt. No task list, stress test or persistent setting change. Unsupported temperature, frequency and power fields stay unavailable.</p>${button('Collect a short sample','power')}</div>`}</section>
      <div class="notice blue"><strong>Hardware Governance:</strong> Dynamic core stepping and voltage curves are enforced by macOS kernel XCPM (AppleIntelCPUPowerManagement). Power profiles govern energy performance preference (EPP), thermal budgets, and boost ceilings without violating System Integrity Protection (SIP).</div>`+footer();
  }
  function battery(){
    const b=state.battery||{},health=M.capacityHealth(b);
    const batLimit = state.batteryLimit || 100;
    return title('Power & Battery Health','Current charge, health analysis, and ASUS battery health charging limiter.')+
      `<div class="detail-grid"><section class="detail-card">${icon('battery')}<h3>Current charge</h3><div class="large-value">${num(b.chargePercent)}<small> %</small></div><p>${b.onAC===true?'Connected to AC power':b.onAC===false?'Running on battery':'Power source unavailable'} · ${b.charging?'charging':'not charging / unknown'}</p>${setting('battery','Open Battery settings','ghost')}</section><section class="detail-card">${icon('activity')}<h3>Reported capacity health</h3><div class="large-value" style="color:var(--amber)">${num(health,1)}<small> %</small></div><p>Full charge ${num(b.AppleRawMaxCapacity??b.MaxCapacity)} / design ${num(b.DesignCapacity)} capacity units.</p>${pill(health===null?'Capacity unavailable':health<80?'Capacity check recommended':'Reported ratio only',health!==null&&health<80?'warning':'neutral')}</section><section class="detail-card">${icon('restore')}<h3>Cycle count</h3><div class="large-value">${num(b.CycleCount)}</div><p>Threshold limit: <strong>${batLimit}%</strong></p>${pill(batLimit<100?'Lifespan Protection Active':'Full Capacity Mode','info')}</section></div>
      <section class="panel panel-padding">
        <h2>🛡️ Battery Health Charging Threshold (Lifespan Protection)</h2>
        <p class="body-copy">Protect your ASUS OLED laptop battery cells from high-voltage degradation during extended AC charging. Limiting to 80% or 60% substantially extends lithium-ion chemistry longevity.</p>
        <div class="inline-actions" style="margin:14px 0">
          ${button('Full Capacity (100%)','set-bat-limit','data-limit="100"',batLimit===100?'secondary':'ghost')}
          ${button('Balanced Mode (80%)','set-bat-limit','data-limit="80"',batLimit===80?'secondary':'ghost')}
          ${button('Maximum Lifespan (60%)','set-bat-limit','data-limit="60"',batLimit===60?'secondary':'ghost')}
        </div>
        <p class="footnote"><span>Active threshold: <strong>${batLimit}%</strong> (Configures ASUS BCLM threshold key / health charging profile).</span></p>
      </section>
      <section class="panel"><div class="setting-row"><span class="quick-icon">${icon('timer')}</span><div class="row-body"><h3>Stay awake, temporarily</h3><p>Prevent idle system sleep for up to 15 minutes. Not a sleep fix; may increase battery consumption. Stops when you quit the app.</p><small>${state.awake?'Temporary assertion is active.':'No persistent pmset changes.'}</small></div><div class="row-control">${button(state.awake?'Stop keep-awake':'Keep awake 15 min','awake')}</div></div></section>`+footer();
  }
  function unsupported(ic,heading,text){return `<section class="detail-card unavailable">${icon(ic)}<h3>${e(heading)}</h3><p>${e(text)}</p>${pill('Not available · hardware interface required','neutral')}</section>`;}
  function display(){
    const d=state.display||{},g=state.gpu?.[0];
    const bVal=M.boundedNumber(state.brightness,1,100)??80;
    return title('Your display. Preserved.','Hardware-synchronized display brightness and safe OLED DPCD backlight control.')+
      `<div class="two-col"><section class="panel panel-padding display-accent"><span class="eyebrow">Main display · macOS report</span><h2 style="margin-top:14px;font-size:25px">${d.width?`${e(d.width)} × ${e(d.height)}`:'Resolution unavailable'}</h2><p class="quiet-label" style="margin:10px 0 22px">${d.refreshHz>0?num(d.refreshHz)+' Hz reported':'Refresh rate unavailable'} · ${num(d.screenCount)} screen(s)</p>${heroArt()}<div class="range-control" style="margin:16px 0">${icon('display')}<input id="brightness" aria-label="Display brightness" type="range" min="1" max="100" value="${bVal}"><output id="brightness-output">${bVal}%</output></div><p class="body-copy" style="font-size:12px;color:var(--muted)">Hardware brightness is synchronized with macOS DisplayServices and native Fn keys (requires BrightnessKeys.kext in OpenCore EFI). Safe DPCD modulation without unsafe register writes.</p><div class="inline-actions">${setting('display','Display & brightness')}${setting('accessibility','Motion & transparency','ghost')}</div></section><section class="panel panel-padding"><h2>Keep the working foundation.</h2><p class="body-copy">GPU: ${e(g?.name||'Unavailable')}. Intel Iris Xe graphics operate safely in Metal 2 compatibility mode.</p><div class="detail-card" style="margin:12px 0;border-left:3px solid var(--amber)"><div style="display:flex;align-items:center;gap:8px;margin-bottom:6px"><span class="chip" style="background:var(--amber);color:#0a0f18;font-weight:700">HDR: LOCKED OFF</span><strong>Safe OLED Mode</strong></div><p style="font-size:12px;line-height:1.6;margin:0">HDR is intentionally locked to OFF for hardware safety. On Intel 11th Gen Tiger Lake Iris Xe Graphics driving an OLED panel via eDP, enabling macOS HDR causes severe framebuffer corruption, inverted gamma, and WindowServer crashes. Preserving your known-good HDR OFF configuration.</p></div>${pageButton('audio','Open Audio','ghost')}</section></div><div class="row-list">${shortcutRow('keyboard','Keyboard & keyboard lighting','Existing Fn implementation only; no remap or ACPI changes.','keyboard')}${shortcutRow('hardware','Trackpad & gestures','No PS/2 or I²C driver is disabled or replaced.','trackpad')}</div>`+samplingNote()+footer();
  }
  function audio(){
    const supported=M.capabilities(state).volume;
    return title('Sound, without changing your stack.','A real standard output control. Clear limits for microphone processing and DTS.')+
      `<div class="two-col"><section class="panel"><div class="panel-head"><h2>Default output volume</h2>${pill(supported?'Core Audio scalar exposed':'Output control unavailable',supported?'info':'neutral')}</div><div class="panel-padding"><div class="large-value">${num(state.volume)}<small> %</small></div><div class="range-control">${icon('volume')}<input id="volume" aria-label="System output volume" type="range" min="0" max="100" value="${M.boundedNumber(state.volume,0,100)??0}" ${!supported||busy?'disabled':''}><output id="volume-output">${num(state.volume)}%</output></div><p class="body-copy">Changes only the default output’s exposed software volume. No codec/layout, jack-routing or equalisation changes. Unsupported outputs stay unavailable; use Sound settings.</p>${setting('audio','Sound & microphone','ghost')}</div></section><section class="panel panel-padding"><h2>Microphone: no capture is started.</h2><p class="body-copy">This beta has no app-owned noise-reduction pipeline or system-wide audio routing. No microphone samples, permission request or recording is started by opening this page.</p>${pill('Mic DSP not implemented')}<p class="body-copy">Use the existing working speaker, microphone and headphone setup. A volume scalar alone does not certify that every route works.</p></section></div><div class="support-grid">${unsupported('volume','DTS processing','No licensed DTS implementation or active Windows APO is supplied on macOS. A Windows package name is not a working Mac effect.')}${unsupported('activity','System-wide microphone effects','Requires a separately designed, opt-in, permission-aware audio pipeline and routing. No cosmetic AI toggle is presented.')}</div>`+samplingNote()+footer();
  }
  function shortcutRow(ic,heading,text,id){return `<div class="setting-row"><span class="quick-icon">${icon(ic)}</span><div class="row-body"><h3>${e(heading)}</h3><p>${e(text)}</p></div>${setting(id,'Open settings','ghost')}</div>`;}
  function tweaks(){
    const selected=M.tweaks.filter(t=>filter==='All'||t.group===filter);
    return title('Make room for your way of working.','Useful desktop preferences. Every change is optional, confirmed and backed up.',button('Restore my changes','restore-all','','ghost'))+
      `<div class="notice blue">These are appearance and usability preferences—not a CPU, GPU or RAM optimization. The native app saves each original value before applying a change. It never applies all tweaks on launch.</div>
      <div class="filter-bar">${['All','Dock','Finder','Appearance'].map(f=>`<button class="filter ${f===filter?'active':''}" data-filter="${f}">${f}</button>`).join('')}<span class="quiet-label">${M.tweaks.length} CONTROLS · USER LEVEL ONLY</span></div>
      <section class="row-list">${selected.map(t=>{
        const row=state.tweaks?.find(r=>r.id===t.id)||{},blocked=row.blocked||row.managed||row.conflict;
        const label=row.blocked?'Restore journal needs review':row.managed?'Managed preference':row.conflict?'Changed outside this app':row.saved?'Restore point saved':row.matches?'Already configured':'Original saved before first change';
        return `<div class="setting-row"><span class="quick-icon">${icon(t.icon)}</span><div class="row-body"><h3>${e(t.title)}</h3><p>${e(t.description)}</p><small>${e(label)} · relaunch ${e(t.restart)}</small></div><div class="row-control">${row.saved?button('Restore','restore',`data-id="${t.id}"`,'ghost',!M.canRestore(row)):button(row.matches?'Configured':'Apply','tweak',`data-id="${t.id}"`,'secondary',blocked||row.matches)}</div></div>`;
      }).join('')}</section><div class="inline-actions">${button('Relaunch Dock…','restart','data-id="Dock"','ghost')}${button('Relaunch Finder…','restart','data-id="Finder"','ghost')}${setting('accessibility','Motion & transparency','ghost')}</div>
      <div class="footnote"><span>${icon('restore')}Restore skips newer conflicting choices. Originally unset keys are removed again, not replaced with guessed defaults.</span></div>`;
  }
  function hardware(){
    const g=state.gpu?.[0], caps=M.capabilities(state);
    const rows=[
      ['App architecture',state.architecture||'Unavailable','Not a model guess','neutral'],
      ['CPU',state.cpu?.name||'Unavailable','Read via sysctl','info'],
      ['GPU',g?.name||'Unavailable','Metal device view','info'],
      ['Memory',`${num(state.memory?.totalGB)} GiB installed`,'Read via macOS','info'],
      ['SMBIOS model',state.smbiosModel||'Unavailable','Not physical model','neutral'],
      ['USB','No USB mapping or driver changes are made by this app.','Function untested here','neutral'],
      ['Audio',M.capabilities(state).volume?'A default-output volume scalar is exposed. Speakers/mic/jack still need real tests.':'No usable output-volume scalar reported. Use Sound settings.','Capability only','neutral'],
      ['Display / Fn','Existing graphics, backlight and input drivers are left unchanged.','No new driver test','neutral'],
      ['Wi-Fi / Bluetooth','Use the existing configured drivers. No Continuity guarantee.','Not tested in app','neutral'],
      ['Fan RPM',validFans().length?validFans().map(f=>num(f.rpm)+' RPM').join(' / '):'No fresh valid RPM from the installed provider. See Fan & sensors.','Read only; provider-reported','neutral'],
      ['CPU/GPU temperature','Only shown if optional powermetrics returns a supported field.','May be unavailable','neutral'],
      ['GPU utilization',caps.gpuUsage?'A reported counter exists; validate it on this driver.':'Unavailable. A GPU name or Metal flag is not a utilization measurement.','Never fabricated','neutral'],
      ['Firmware / DSP','Clock boost, fan curves, charge caps, auto HDR, DTS and system-wide mic DSP are not implemented.','Not universal','neutral']
    ];
    return title('Know what is—and isn’t—connected.','A capability inventory, not an automatic hardware mapper or compatibility certificate.')+
      `<section class="panel"><table class="spec-table"><tbody>${rows.map(r=>`<tr><td>${e(r[0])}</td><td>${e(r[1])}</td><td>${pill(r[2],r[3])}</td></tr>`).join('')}</tbody></table></section>
      <div class="inline-actions">${setting('wifi','Wi-Fi settings','ghost')}${setting('bluetooth','Bluetooth settings','ghost')}${setting('trackpad','Trackpad settings','ghost')}</div>
      <h2 class="subheading">Unsupported firmware controls stay honest.</h2><div class="support-grid">${unsupported('cpu','ASUS performance profiles','Windows MyASUS firmware modes cannot be recreated by renaming macOS CPU presets. No clocks, voltage, power limits, MSRs or arbitrary ACPI methods are written.')}${unsupported('fan','Fan writes & EC access','A model-specific verified interface and separate hardware testing are required. This version contains no kernel extension, privileged daemon or firmware bridge.')}</div>`+footer();
  }
  function recovery(){return title('You stay in control.','A small footprint, a visible restore path, and no silent system changes.')+
    `<div class="two-col"><section class="panel"><div class="panel-head"><h2>Undo without guessing</h2>${pill('Local journal','info')}</div><div class="step-list"><div class="step"><div><strong>Before a desktop preference changes</strong><p>Its exact original value—or the fact it was unset—is saved in your user Application Support folder. If a restore point cannot be saved, the change is refused.</p></div></div><div class="step"><div><strong>When you restore</strong><p>Only settings saved by this app are eligible. If a newer choice was made elsewhere, restore skips it instead of overwriting it.</p></div></div><div class="step"><div><strong>When you quit</strong><p>Temporary keep-awake ends. Applied desktop preferences remain until you restore them. No startup agent, automatic updater or background tuning service is installed.</p></div></div></div></section>
    <section class="panel panel-padding"><h2>Recovery tools</h2><p style="font-size:11px;color:var(--muted);line-height:1.9;margin:16px 0 24px">Restore is limited to this app’s Dock, Finder and appearance changes. It is not an EFI backup or a macOS rollback tool.</p><div class="inline-actions">${button('Restore my desktop changes','restore-all')}${button('Secure Diagnostics · Authenticate & Save','diagnose','','secondary')}${button('Export minimized snapshot','export','','ghost')}</div><div class="notice blue">The restore file belongs to you. Keep it until your original preferences are restored. No serial, full registry, account name, Wi-Fi address or EFI is included in an exported snapshot.</div></section></div>
    <section class="feature-strip">${icon('shield')}<div><h3>Your known-good EFI stays yours.</h3><p>No EFI mounts or writes. No Windows changes, firmware access, NVRAM resets, SIP changes or OS updates.</p></div></section>
    <h2 class="subheading">System preferences, without hidden edits</h2><div class="row-list">${shortcutRow('sliders','Login items & background apps','Review what starts with your session. Nothing is disabled automatically.','login')}${shortcutRow('drive','Storage','Review storage in macOS. No cache purges, file deletion or swap disabling.','storage')}${shortcutRow('help','Notifications','Decide which apps can interrupt your work.','notifications')}</div>`+footer();}
  function about(){return title('A companion. Not a replacement firmware.','Independent software with capability-specific, evidence-first hardware support.')+
    `<section class="panel panel-padding"><div class="about-mark"><img src="icon.svg" alt="KL monogram"><div><h2>KL-06</h2><p>KL-06 Manager · 0.4.7-beta · build 12 · multi-device release candidate</p></div></div><p style="font-size:12px;color:var(--muted);line-height:1.9;max-width:720px">A lightweight macOS window and menu-bar companion, using AppKit, WebKit, IOKit, Metal and Core Audio. No Electron runtime, cloud account, third-party downloads at runtime or system “cleaner”. This is not an ASUS product and is not affiliated with ASUS.</p><div class="inline-actions">${button('Export a minimized snapshot','export')}${pageButton('hardware','View capability limits','ghost')}</div></section>
    <div class="notice">This version’s interface and safety checks can be tested here; the native macOS code must be built and verified on your actual Mac. Do not mistake this browser preview for live access or proof that every native feature works.</div>
    <section class="row-list"><div class="setting-row"><span class="quick-icon">${icon('keyboard')}</span><div class="row-body"><h3>F13 / PrtSc · show or hide KL-06</h3><p>${!isNative?'Available only in the running native app, not this browser preview.':state.hotkey?.registered===true?'Registered: F13 alone (virtual keyCode 105). Brings KL-06 forward, or hides it when already in front.':'Unavailable: macOS did not register the shortcut. Use the KL menu bar or Dock; review conflicting shortcuts, then quit/reopen to retry.'} Native dialogs stay accessible. Hold does not repeatedly toggle. Quitting releases F13. No key remapping or keyboard-monitoring permission is requested.</p></div></div><div class="setting-row"><span class="quick-icon">${icon('lock')}</span><div class="row-body"><h3>Administrator access is optional and bounded</h3><p>Only the explicit power-sampling action requests macOS authorization for one fixed read-only command. The app never asks you to enter a password into its interface.</p></div></div><div class="setting-row"><span class="quick-icon">${icon('display')}</span><div class="row-body"><h3>Preserve what already works</h3><p>Existing graphics, Fn and audio stay untouched. A hardware report can guide future support; it cannot grant universal compatibility, fix a driver or certify an OS upgrade.</p></div></div></section>`+footer();}

  function validFans(){return M.freshFanReadings(state?.fan,isNative,stale,(window.performance.now()-receivedAt)/1000);}
  function fan(){
    const f=state.fan||{},readings=validFans(),age=typeof f.ageSeconds==='number'?f.ageSeconds+Math.max(0,(window.performance.now()-receivedAt)/1000):null,effectiveStatus=stale||(age!==null&&age>12)?'stale':f.status||'not-sampled';
    return title('Cooling, without invented numbers.','Read the existing Mac sensor provider. Leave cooling under firmware control.')+
      `<section class="fan-hero"><div class="fan-orbit">${icon('fan')}</div><div><span class="eyebrow">${readings.length?'PROVIDER-REPORTED · READ ONLY':'NO VALIDATED RPM SAMPLE'}</span><h2>${readings.length?readings.map(r=>num(r.rpm)+' RPM').join(' / '):'Fan RPM unavailable'}</h2><p>${readings.length?'Actual-speed fields returned by the installed SMC provider. No target speed was set.':'Leave firmware automatic cooling in charge. No cooling-mode query or change was made; administrator permission cannot create missing keys.'}</p><div class="chip-row"><span class="chip">${e(effectiveStatus)}</span><span class="chip">${age!==null?'Query result age '+num(age,1)+' s':'No completed reading'}</span><span class="chip">No EC / firmware writes</span></div><p class="sensor-source">Source: ${e(f.source||'Existing SMC provider; no completed result')}<br>Query completed: ${e(f.reportedAt||'not yet')} · query duration ${num(f.queryDurationSeconds,2)} s. Physical sensor age/calibration is unknown.</p>${(f.fans||[]).length?`<div class="chip-row">${f.fans.map(r=>`<span class="chip">Fan ${e(r.index)} · ${e(effectiveStatus==='stale'?'stale':r.status)}</span>`).join('')}</div>`:''}</div></section>
      <div class="detail-grid"><section class="detail-card"><h3>Existing provider only</h3><p>Fixed standard FNum and at most F0Ac/F1Ac actual-speed keys are read in a bounded background worker. No key sweep, driver download or kernel installation.</p>${pill('5-second provider polling','info')}</section><section class="detail-card"><h3>Errors stay visible</h3><p>Absent, denied, unsupported, invalid and stale readings remain unavailable. A genuine zero returned by a valid key is not an invented fallback. Driver-reported values are not independently calibrated.</p>${pill('Stale values are withheld')}</section><section class="detail-card"><h3>Manual fan speed</h3><p>No validated writable fan interface exists in this beta. Profiles/curves cannot be unlocked by entering a sudo password. Safe bounds, readback and firmware-auto recovery need separate model-specific validation.</p>${pill('Control unavailable','warning')}</section></div>
      <section class="panel panel-padding"><h2>Need the targeted diagnostic?</h2><p class="body-copy">Run the included <strong>COLLECT-MAC-FANS.command</strong> as your normal user. It builds the same small read-only reader with your installed Apple tools and writes reviewed JSON/TXT to a new private folder. It installs nothing and asks for no password.</p><p class="body-copy">Historical Windows RPM belongs on the History page—not this live Mac page. Importing HWiNFO data never creates a Mac firmware provider.</p>${pageButton('history','Open historical data','ghost')}</section>`+footer();
  }
  function historyPage(){
    const h=importedHistory,channel=h?.series[Math.min(historyChannel,h.series.length-1)];
    return title('History, with its source attached.','Local Windows HWiNFO imports never become live Mac sensor readings.',button('Import HWiNFO CSV','import-history'))+
      `<div class="notice blue">Historical Windows data only. Import is local and optional, kept in this window’s memory until cleared or quit. Raw CSV, computer names and source paths are not exported or uploaded. Only allowlisted numeric channels survive parsing.</div>`+
      (h?`<div class="history-meta"><span>${e(h.samples)} timestamped rows</span><span>Recorded date ${e(h.recordedDate)} · device clock unverified</span>${button('Clear imported history','clear-history','','ghost')}</div><section class="panel"><div class="panel-head"><div><h2>${e(channel.label)} · historical ${e(channel.unit)}</h2><p>${e(channel.source)} · x-axis: recorded device-local time; timezone unverified</p></div></div><div class="filter-bar history-selector">${h.series.map((c,i)=>`<button class="filter ${i===historyChannel?'active':''}" data-history="${i}">${e(c.label)}${h.series.filter(v=>v.label===c.label).length>1?' · '+e(c.source.replace(' (Windows history)','')):''}</button>`).join('')}</div><div class="chart-wrap">${lineChart(channel.recent,{minimum:channel.min-Math.max(1,(channel.max-channel.min)*.05),maximum:channel.max+Math.max(1,(channel.max-channel.min)*.05),label:channel.label,historical:true})}</div><div class="chart-footer"><span>Up to 120 actual imported values · gaps stay gaps</span><span>${e(h.firstClock)} to ${e(h.lastClock)} · not live Mac</span></div></section><p class="body-copy">Skipped malformed rows: ${e(h.skippedMalformedRows)}; invalid recorded timestamps: ${e(h.skippedInvalidTimestamps)}.</p><section class="panel table-scroll"><table class="history-table"><thead><tr><th>Historical channel</th><th>Samples</th><th>Minimum</th><th>Median</th><th>Maximum</th></tr></thead><tbody>${h.series.map(c=>`<tr><td><strong>${e(c.label)}</strong><small>${e(c.source)} · ${e(c.unit)}</small></td><td>${e(c.count)}</td><td>${num(c.min,2)}</td><td>${num(c.median,2)}</td><td>${num(c.max,2)}</td></tr>`).join('')}</tbody></table></section><p class="body-copy">Repeated CSV headers/source-group footer rows are not samples. Duplicate CPU-temperature labels keep their source group. Import statistics do not prove a controlled benchmark, a profile-switch effect or calibrated sensors.</p>`:`<section class="panel"><div class="empty-state">${icon('folder')}<h3>No recording imported.</h3><p>Choose a Windows HWiNFO sensor CSV, up to 5 MiB and 10,000 samples. No file is scanned automatically. This beta does not bundle anyone’s real recording.</p>${button('Choose a local CSV','import-history')}</div></section>`)+footer();
  }
  function storagePage(){
    const t=state.storage||{};
    return title('Know your space. Keep your files.','Real filesystem capacity and safe user-space maintenance.')+
      `<div class="detail-grid"><section class="detail-card">${icon('drive')}<h3>Available</h3><div class="large-value">${num(t.freeGB,1)}<small> GiB</small></div><p>Reported free space of the home filesystem. APFS volumes can share capacity.</p></section><section class="detail-card">${icon('hardware')}<h3>Filesystem total</h3><div class="large-value">${num(t.totalGB,1)}<small> GiB</small></div><p>Not a partition map or an inventory of Windows/internal boot files.</p></section><section class="detail-card">${icon('shield')}<h3>Safe maintenance</h3><p>Safe user-space operations only. Never touches your personal documents, system libraries, EFI or Windows partition.</p><div class="inline-actions" style="margin-top:12px">${button('Optimize inactive RAM','purge-ram','','secondary')}${button('Clean app caches','clean-caches','','ghost')}</div></section></div><div class="two-col"><section class="panel panel-padding"><h3>Memory & Cache Optimizer</h3><p class="body-copy"><strong>Optimize inactive RAM:</strong> Safely requests macOS to flush inactive cache buffers and reclaim purgeable space using the native system purge utility.<br><strong>Clean app caches:</strong> Purges local WebKit temporary caches and session scratch files without affecting user preferences or saved states.</p></section><section class="panel panel-padding"><h3>Storage settings</h3><p class="body-copy">For full APFS volume breakdown, Time Machine local snapshots, and system data inspection, use macOS System Settings.</p>${setting('storage','Open macOS Storage settings','ghost')}</section></div>`+footer();
  }
  function companion(){
    const up=state.updateInfo;
    const peers = [];
    return title('Ecosystem Companion & AirDrop / Quick Share','Local Wi-Fi discovery, cross-platform file transfer, and signed OTA updates.')+
      `<div class="two-col"><section class="panel panel-padding"><h2>${state.companion?.running?'Session active · at most 30 minutes':'Companion is off'}</h2><p class="body-copy">Connect your Android or iPhone over local Wi-Fi. View real-time telemetry, send files via AirDrop/Quick Share, and safely control volume or keep-awake with local laptop confirmation.</p><div class="inline-actions">${button('Enable temporary session','companion-start','','secondary',state.companion?.running)}${button('Show pairing details','companion-details','','ghost',!state.companion?.running)}${button('Stop and revoke devices','companion-stop','','ghost',!state.companion?.running)}</div><div class="notice blue"><strong>Security Invariant:</strong> Private TLS pinning, 32-character random pair code, and explicit desktop confirmation for all changes. No cloud relays, root helpers, firewall changes, or silent background daemons.</div></section>
      <section class="panel panel-padding"><h2>AirDrop & Quick Share (Cross-Platform Drop)</h2><p class="body-copy">The desktop broker exposes a private TLS receive endpoint. Android has a native sender; iOS, macOS and Windows transfer directions are not yet end-to-end verified. Bluetooth and cellular relay are not implemented KL-06 transports.</p><div class="notice">Current verified-in-source direction: Android sender to a running desktop receiver over the same private LAN. Other platform directions, Bluetooth and cellular relay are not implemented or verified. The desktop receiver currently auto-accepts an already-paired sender; per-file approval is a remaining requirement.</div></section></div>
      <section class="panel panel-padding" style="margin-top:20px">
        <div class="panel-head"><div><h2>Nearby Devices (Discovery not enabled in this macOS build)</h2><p>No automatic discovery is enabled in this macOS build. Use the desktop-generated TLS details on the mobile app.</p></div><div class="inline-actions">${button('Scan Wi-Fi Devices','scan-peers','','secondary')}${button('Refresh PIN','refresh-pin','','ghost')}</div></div>
        <div class="pin-card">
          <div class="pin-code-wrap">
            <div><small style="display:block;color:var(--muted);margin-bottom:4px">TLS PAIRING DETAILS</small><div class="pin-digits">Not a 6-digit PIN</div></div>
            <div>${button('Copy PIN','copy-pin','','secondary')}</div>
          </div>
          <div class="pin-meta">Use the HTTPS URL, full certificate SHA-256 fingerprint and 32-character session code displayed by “Show pairing details”.</div>
        </div>
        <div class="detail-grid" style="margin-top:16px">
          ${peers.map(p => `
            <section class="detail-card ${p.status.includes('Current') ? 'gpu-accent' : ''}">
              <h3>${p.platform === 'ios' ? '📱' : p.platform === 'android' ? '🤖' : p.platform === 'macos' ? '💻' : '🖥️'} ${e(p.name)}</h3>
              <div class="large-value" style="font-size:18px">${e(p.model)}</div>
              <p>LAN IP: ${e(p.ip)} · ${e(p.status)}</p>
              ${!p.status.includes('Current') ? button('Send File via Drop', 'send-peer', `data-peer="${e(p.id)}"`, 'secondary') : pill('Current Host', 'info')}
            </section>
          `).join('')}
        </div>
      </section>
      <section class="panel panel-padding" style="margin-top:20px"><div class="panel-head"><div><h2>OTA Updates & Integrity</h2><p>Signed release catalog verification with downgrade defense.</p></div>${button('Check for Updates','check-updates','','secondary')}</div><div class="detail-grid" style="margin-top:16px"><section class="detail-card"><h3>Current Version</h3><div class="large-value" style="font-size:24px">v0.4.7-beta <small>Build 12</small></div><p>Architecture: x86_64 macOS 13+ · Intel Iris Xe safe build</p></section><section class="detail-card"><h3>Update Channel</h3><div class="large-value" style="font-size:24px">Beta Channel</div><p>${up?e(up.notice):'Click Check for Updates to validate with signed catalog.'}</p></section><section class="detail-card"><h3>Integrity Status</h3><div class="large-value" style="font-size:24px;color:var(--emerald,'#00e676')}">${up?.catalogVerified?'Verified':'Signed Ready'}</div><p>SHA-256 catalog signed; manual review required before installation.</p></section></div></section>`+footer();
  }
  const labels={companion:'Phone companion',fan:'Fan & sensors',history:'Windows history',storage:'Storage',overview:'Overview',performance:'Performance',battery:'Power & battery',display:'Display',audio:'Audio',tweaks:'Desktop tweaks',hardware:'My hardware',recovery:'Safety & restore',about:'About KL-06'};
  const navs={companion:'wifi',fan:'fan',history:'folder',storage:'drive',overview:'grid',performance:'activity',battery:'battery',display:'display',audio:'volume',tweaks:'sliders',hardware:'hardware',recovery:'restore',about:'help'};
  function navigation(ids){return `<div class="nav-group">${ids.map(id=>`<button class="nav ${page===id?'active':''}" data-page="${id}" title="${labels[id]}" ${page===id?'aria-current="page"':''}>${icon(navs[id])}<span class="nav-label">${labels[id]}</span>${id==='tweaks'?'<span class="count">12</span>':''}</button>`).join('')}</div>`;}
  let shellRendered = false;
  let lastRenderedPage = null;
  function render(){
    const isPageChange = (lastRenderedPage !== page);
    const scroll = isPageChange ? 0 : (document.querySelector('.workspace')?.scrollTop || 0);
    lastRenderedPage = page;
    const body=state?({overview,performance,battery,display,audio,tweaks,companion,hardware,recovery,about,fan,history:historyPage,storage:storagePage}[page]||overview)():`<div class="empty-state"><h3>${stale?'Local bridge not available':'Reading local counters…'}</h3><p>${stale?'No live data has been received. No demo values will be presented as your measurements.':'No hardware settings are being changed.'}</p></div>`;
    const app = document.getElementById('app');
    if(!shellRendered||!app.querySelector('.shell')){
      app.innerHTML=`<div class="shell"><aside class="sidebar"><div class="brand"><img src="icon.svg" alt=""><div><span class="wordmark">KL-06</span><small>MANAGER · v0.4.7-BETA</small></div></div><div><div class="nav-group-label">WORKSPACE</div><div id="nav-workspace">${navigation(['overview','performance','fan','battery','display','audio'])}</div></div><div><div class="nav-group-label">PERSONALIZE</div><div id="nav-personalize">${navigation(['tweaks','storage','history','hardware','companion'])}</div></div><div class="sidebar-bottom">${navigation(['recovery','about'])}<div class="device-mini">${icon('laptop')}<div><strong>Local hardware</strong><p><span class="dot"></span>${isNative?'On-device companion':'Interface preview'}</p></div></div><div class="privacy-foot">${icon('lock')}No cloud. No telemetry.</div></div></aside><main class="workspace"><header class="topbar"><div class="breadcrumb"><span>My workspace</span><span>/</span><strong id="breadcrumb-page">${e(labels[page])}</strong></div><div class="top-actions"><span class="mode-badge ${isNative&&!stale?'live':''}"><span class="dot ${busy?'busy-dot':''}"></span>${stale?'DATA UNAVAILABLE':isNative?'LOCAL · NATIVE':'DEMO · NOT LIVE'}</span><button class="icon-button" data-action="refresh" aria-label="Refresh counters" title="Refresh">${icon('refresh')}</button><button class="icon-button" data-action="theme" aria-label="Switch appearance" title="Switch appearance">${icon(light?'moon':'sun')}</button></div></header><div id="stale-banner-wrap">${stale?'<div class="stale-banner">Local counters are unavailable or stale. Last-known values are not new measurements.</div>':''}</div><div class="main-content">${body}</div></main></div>`;
      shellRendered=true;
    } else {
      app.querySelectorAll('.sidebar .nav').forEach(btn => {
        const isCurrent = btn.dataset.page === page;
        btn.classList.toggle('active', isCurrent);
        if (isCurrent) btn.setAttribute('aria-current', 'page');
        else btn.removeAttribute('aria-current');
      });
      const bPage = document.getElementById('breadcrumb-page');
      if (bPage) bPage.textContent = labels[page];
      const badge = app.querySelector('.mode-badge');
      if (badge) {
        badge.className = `mode-badge ${isNative&&!stale?'live':''}`;
        badge.innerHTML = `<span class="dot ${busy?'busy-dot':''}"></span>${stale?'DATA UNAVAILABLE':isNative?'LOCAL · NATIVE':'DEMO · NOT LIVE'}`;
      }
      const staleWrap = document.getElementById('stale-banner-wrap');
      if (staleWrap) staleWrap.innerHTML = stale ? '<div class="stale-banner">Local counters are unavailable or stale. Last-known values are not new measurements.</div>' : '';
      const contentEl = app.querySelector('.main-content');
      if (contentEl) contentEl.innerHTML = body;
    }
    const ws = document.querySelector('.workspace');
    if (ws) ws.scrollTop = scroll;
  }
  function toast(message){const t=document.getElementById('toast');t.textContent=message;t.classList.add('visible');clearTimeout(timer);timer=setTimeout(()=>t.classList.remove('visible'),6500);}
  function demoDialog(){
    const root=document.getElementById('dialog-root');
    root.innerHTML=`<div class="modal-overlay"><section class="modal" role="dialog" aria-modal="true" aria-labelledby="demo-title">${icon('laptop')}<h2 id="demo-title">Meet the native Mac app.</h2><p>This is a visual preview with illustrative data. It cannot read or change your Mac.</p><p>Build <strong>KL-06 Manager.app</strong> on your Mac using the included <strong>BUILD-MAC.command</strong>, then open it to use supported controls. Firmware controls remain unavailable, not simulated.</p><button class="button" data-action="dismiss">Got it</button></section></div>`;
    root.querySelector('button').focus();
  }
  async function refresh(updateUI=false){
    if(document.hidden||busy||refreshInFlight||document.querySelector('#volume:active')||document.querySelector('#brightness:active'))return;
    refreshInFlight=true;
    try{
      const fresh=await provider.request('state');
      if(fresh?.suspended){stale=true;if(updateUI)render();return;}
      state=fresh;receivedAt=window.performance.now();stale=false;
      const sample=M.cpuSample(state);
      if(isNative&&sample&&(!history.length||sample.uptime>history.at(-1).uptime)){history.push(sample);history=history.slice(-35);}
      if(updateUI)render();
    }catch{
      stale=true;
      if(!state&&updateUI)render();
      else{
        const staleWrap=document.getElementById('stale-banner-wrap');
        if(staleWrap)staleWrap.innerHTML='<div class="stale-banner">Local counters are refreshing or temporarily stale.</div>';
      }
    }finally{refreshInFlight=false;}
  }
  async function act(method,params={}){
    if(!isNative){demoDialog();return;}
    if(busy)return;busy=true;
    const busyBadge=document.querySelector('.mode-badge');if(busyBadge)busyBadge.classList.add('busy');
    try{
      const result=await provider.request(method,params);
      if(method==='pickHistoryCSV'){importedHistory=window.KLHistory.parse(result.csvText);historyChannel=0;page='history';toast('Historical Windows numeric channels imported locally. No upload or hardware change.');}
      else if(method==='checkUpdates'){state.updateInfo=result;render();toast(result.notice||'Update check complete.');}
      else if(method==='setPowerProfile'){state.powerProfile=params.profile;render();toast(typeof result==='string'?result:'Power profile updated.');}
      else if(method==='setBatteryLimit'){state.batteryLimit=params.limit;render();toast(typeof result==='string'?result:'Battery threshold updated.');}
      else if(method==='setFanMode'){state.fanMode=params.mode;render();toast(typeof result==='string'?result:'Fan cooling mode updated.');}
      else if(method==='scanPeers'){toast(Array.isArray(result)&&result.length?'Peers discovered. Review the real peer list.':'No KL-06 peers discovered. Use direct TLS pairing details instead.');}
      else if(method==='sendPeerFile'){toast(typeof result==='string'?result:'This macOS build has no file-sending implementation; no file was sent.');}
      else toast(typeof result==='string'?result:'Done.');
    }catch(error){toast(error.message);}
    finally{busy=false;await refresh(true);}
  }
  document.addEventListener('click',ev=>{
    const el=ev.target.closest('button');if(!el||el.disabled)return;
    if(el.dataset.page){page=el.dataset.page;filter='All';render();return;}
    if(el.dataset.filter){filter=el.dataset.filter;render();return;}
    if(el.dataset.history!==undefined){historyChannel=Number(el.dataset.history);render();return;}
    const id=el.dataset.id;
    switch(el.dataset.action){
      case 'dismiss':document.getElementById('dialog-root').replaceChildren();return;
      case 'theme':light=!light;document.documentElement.classList.toggle('light',light);render();return;
      case 'refresh':refresh(true);toast(isNative?'Refreshing local counters.':'Preview data only. No hardware is connected.');return;
      case 'setting':act('openSetting',{id});return;
      case 'tweak':act('applyTweak',{id});return;
      case 'restore':act('restoreTweak',{id});return;
      case 'restore-all':act('restoreAll');return;
      case 'restart':act('restartUI',{app:id});return;
      case 'power':act('powerSample');return;
      case 'awake':act('keepAwake');return;
      case 'export':act('exportReport');return;
      case 'diagnose':act('diagnoseAndExport');return;
      case 'companion-start':act('startCompanion');return;
      case 'companion-stop':act('stopCompanion');return;
      case 'companion-details':act('companionDetails');return;
      case 'import-history':act('pickHistoryCSV');return;
      case 'clear-history':importedHistory=null;render();return;
      case 'purge-ram':act('purgeMemory');return;
      case 'clean-caches':act('cleanCaches');return;
      case 'check-updates':act('checkUpdates');return;
      case 'set-profile':act('setPowerProfile',{profile:el.dataset.profile});return;
      case 'set-bat-limit':act('setBatteryLimit',{limit:Number(el.dataset.limit)});return;
      case 'set-fan-mode':act('setFanMode',{mode:el.dataset.mode});return;
      case 'scan-peers':act('scanPeers');return;
      case 'send-peer':act('sendPeerFile',{peerId:el.dataset.peer});return;
    }
  });
  document.addEventListener('input',ev=>{
    if(ev.target.id==='volume'){document.getElementById('volume-output').textContent=ev.target.value+'%';}
    if(ev.target.id==='brightness'){document.getElementById('brightness-output').textContent=ev.target.value+'%';}
  });
  document.addEventListener('change',ev=>{
    if(ev.target.id==='volume')act('setVolume',{value:Number(ev.target.value)});
    if(ev.target.id==='brightness')act('setBrightness',{value:Number(ev.target.value)});
  });
  let touchStartX=0,touchStartY=0;
  document.addEventListener('touchstart',ev=>{if(ev.touches.length===1){touchStartX=ev.touches[0].clientX;touchStartY=ev.touches[0].clientY;}},{passive:true});
  document.addEventListener('touchend',ev=>{
    if(ev.changedTouches.length===1){
      const dx=ev.changedTouches[0].clientX-touchStartX,dy=ev.changedTouches[0].clientY-touchStartY;
      if(Math.abs(dx)>60&&Math.abs(dy)<40){
        const allPages=['overview','performance','fan','battery','display','audio','tweaks','storage','history','hardware','companion','recovery','about'];
        const idx=allPages.indexOf(page);
        if(idx!==-1){
          if(dx<0&&idx<allPages.length-1){page=allPages[idx+1];filter='All';render();document.querySelector('.workspace').scrollTop=0;}
          else if(dx>0&&idx>0){page=allPages[idx-1];filter='All';render();document.querySelector('.workspace').scrollTop=0;}
        }
      }
    }
  },{passive:true});
  document.addEventListener('keydown',ev=>{if(ev.key==='Escape')document.getElementById('dialog-root').replaceChildren();});
  document.addEventListener('visibilitychange',()=>{if(isNative&&!document.hidden)refresh(false);});
  render();if(isNative){refresh(true);setInterval(()=>refresh(false),5000);}

  // ============================================================================
  // KL-06 MANAGER — HARDWARE OPTIMIZATION & ARENA AI SUITE
  // ============================================================================
  const KL06_CONFIG = {
    repo: 'Kaushal-snap/KL-06-Manager',
    currentVersion: '0.4.7-beta',
    build: 12,
    platform: 'mac'
  };

  async function kl06CheckForUpdates() {
    try {
      const response = await fetch(
        `https://api.github.com/repos/${KL06_CONFIG.repo}/releases/latest`,
        {
          headers: {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'KL-06-Manager-App'
          }
        }
      );
      if (!response.ok) throw new Error('GitHub API error');
      const release = await response.json();
      const latestVersion = (release.tag_name || '').replace('v', '');
      return { available: false, version: release.tag_name };
    } catch (error) {
      return { available: false, error: error.message };
    }
  }

  function kl06ApplyHDRFix() {
    return { success: false, applied: false, message: 'Not implemented: no boot arguments or display-driver settings were changed.' };
  }
  function kl06ApplySleepFix() {
    return { success: false, applied: false, message: 'Not implemented: no sleep/wake or EFI settings were changed.' };
  }
  function kl06ApplyGPUFix() {
    return { success: false, applied: false, message: 'Not implemented: no GPU driver, firmware or boot configuration was changed.' };
  }
  function kl06CheckFanRPM() {
    const readings = validFans();
    return { success: readings.length > 0, status: readings.length ? 'provider-reported-not-calibrated' : 'unavailable', fans: readings, manualControl: false, message: readings.length ? 'Live native provider readings returned.' : 'No valid AppleSMC tachometer reading is available.' };
  }
  function kl06FixDeviceConnection() {
    return { success: false, applied: false, message: 'Not implemented: no Wi-Fi, Bluetooth, AirDrop or network driver repair was performed.' };
  }
  async function kl06FixAll() {
    return { success: false, applied: false, message: 'No system fixes were applied. This build provides diagnostics and supported controls only.' };
  }
  function kl06RollbackAll() {
    return { success: false, rolledBack: false, message: 'No placeholder fix changed system settings; nothing needs rollback.' };
  }

  if (typeof window !== 'undefined') {
    window.KL06Manager = {
      version: KL06_CONFIG.currentVersion,
      build: KL06_CONFIG.build,
      checkForUpdates: kl06CheckForUpdates,
      applyHDRFix: kl06ApplyHDRFix,
      applySleepFix: kl06ApplySleepFix,
      applyGPUFix: kl06ApplyGPUFix,
      checkFanRPM: kl06CheckFanRPM,
      fixDeviceConnection: kl06FixDeviceConnection,
      fixAll: kl06FixAll,
      rollbackAll: kl06RollbackAll
    };
  }
})();
