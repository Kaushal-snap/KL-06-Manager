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
  let state=isNative?null:M.demoState(), page='overview', filter='All', busy=false, stale=false, light=false, timer;
  let history=isNative?[]:[14,15,13,15,11,9,13,18,13,10,12,10,15,20,17,14,12,14,11,9,14,13,17,14,19,16,15,14];
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
  function footer(){return `<div class="footnote"><span>${icon('shield')}Local first. No telemetry, driver replacement or hidden optimization.</span><span>${isNative?'On-device values · refreshes every 2s':'Illustrative preview · not connected to your Mac'}</span></div>`;}
  function chart(){
    const data=history.length?history:[0,0];
    const points=data.map((v,i)=>`${(i/(data.length-1||1)*430+7).toFixed(1)},${(111-v*1.0).toFixed(1)}`).join(' ');
    const end=(data.length>1?437:7);
    return `<svg class="chart" viewBox="0 0 470 133" preserveAspectRatio="none" role="img" aria-label="CPU utilization history${isNative?'':' (illustrative preview)'}"><defs><linearGradient id="chart-fill" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#88b3ff" stop-opacity=".24"/><stop offset="1" stop-color="#88b3ff" stop-opacity="0"/></linearGradient></defs>${[12,61,111].map((y,i)=>`<line x1="7" y1="${y}" x2="437" y2="${y}"/><text x="447" y="${y+3}">${100-i*50}</text>`).join('')}<polygon points="7,112 ${points} ${end},112" fill="url(#chart-fill)"/><polyline points="${points}" stroke="#a9c6ff" stroke-width="2" fill="none" vector-effect="non-scaling-stroke"/><text x="7" y="130">${isNative?'Recent samples':'Illustrative history'}</text><text x="417" y="130">Now</text></svg>`;
  }
  function heroArt(){return `<svg viewBox="0 0 350 195" fill="none" aria-hidden="true"><defs><linearGradient id="screen" x1="40" y1="0" x2="285" y2="170" gradientUnits="userSpaceOnUse"><stop stop-color="#171f48"/><stop offset=".48" stop-color="#5482c0"/><stop offset="1" stop-color="#2e485f"/></linearGradient><linearGradient id="wave" x1="180" y1="35" x2="230" y2="160" gradientUnits="userSpaceOnUse"><stop stop-color="#d5c8f4"/><stop offset=".52" stop-color="#81b9ed"/><stop offset="1" stop-color="#4e668a"/></linearGradient><linearGradient id="base" x2="1" y2="1"><stop stop-color="#8d9caf"/><stop offset="1" stop-color="#3d4e64"/></linearGradient><clipPath id="screen-clip"><path d="m63 28 227 13-18 130L43 155z"/></clipPath></defs><ellipse cx="183" cy="178" rx="139" ry="10" fill="#080d15" opacity=".35"/><path d="m60 22 236 14c5 0 7 3 6 8l-19 133-251-18L52 29c1-5 3-7 8-7Z" fill="#0a111d" stroke="#7b8ca1" stroke-width="1.2"/><path d="m63 28 227 13-18 130L43 155z" fill="url(#screen)"/><g clip-path="url(#screen-clip)"><path d="M74 171c33-72 57-133 114-154 51-18 53 72 2 90-25 9-30 50 22 65 14 4 27-1 57-27" stroke="url(#wave)" stroke-width="31" opacity=".85"/><path d="M-3 91c68 57 113 43 152 6 39-37 81-56 145-42" stroke="#aac9f0" stroke-width="3" opacity=".5"/><path d="M144 211c4-50 18-85 64-103 43-17 83-24 106-2" stroke="#667fbd" stroke-width="23" opacity=".6"/></g><path d="m32 159 251 18 42 5c3 3-12 7-20 7L34 169c-8-1-16-4-15-6z" fill="url(#base)"/><path d="m134 168 61 4-3 4-59-4z" fill="#34465a"/><path d="m32 159 251 18" stroke="#c0c9d4" stroke-opacity=".7"/></svg>`;}
  function overview(){
    const c=state.cpu||{},m=state.memory||{},b=state.battery||{},s=state.storage||{},health=M.capacityHealth(b),memPercent=m.usedGB/m.totalGB*100;
    return title('Good to see you.','A clear view of your hardware. A calmer place to make it yours.','<span class="quiet-label">YOUR EVERYDAY WORKSPACE</span>')+
      `<section class="hero"><div><span class="eyebrow">Your hardware, thoughtfully connected</span><h2>Your hardware.<br>A little more in harmony.</h2><p>Keep an eye on the essentials. Make useful changes. Leave the working foundation alone.</p><div class="chip-row"><span class="chip">Capability-aware</span><span class="chip">Your drivers preserved</span><span class="chip">Local only</span></div></div><div class="hero-art">${heroArt()}<span class="hero-device"><span class="dot"></span>MONITOR · UNDERSTAND · PERSONALIZE</span></div></section>
      <div class="metric-grid">
        <section class="metric metric-cpu" style="--usage:${M.usageColor(c.loadPercent)}"><div class="metric-top">${icon('cpu')}CPU utilization<button class="arrow" data-page="performance" aria-label="Open performance">${icon('northeast')}</button></div><div class="metric-value">${num(c.loadPercent)}<small>%</small></div><div class="metric-note">${e(c.logicalCores??'—')} logical cores · aggregate load</div>${history.length>1?`<svg class="mini-spark" viewBox="0 0 90 22" fill="none" aria-hidden="true"><polyline points="${history.map((v,i)=>`${(90*i/(history.length-1)).toFixed(1)},${(21-v*.2).toFixed(1)}`).join(' ')}" stroke="#a9c6ff" stroke-width="1.5"/></svg>`:''}</section>
        <section class="metric metric-memory" style="--usage:${M.usageColor(memPercent)}"><div class="metric-top">${icon('memory')}Memory<button class="arrow" data-page="performance" aria-label="Open memory details">${icon('northeast')}</button></div><div class="metric-value">${num(m.usedGB,1)}<small>/ ${num(m.totalGB,0)} GB</small></div><div class="metric-track"><span style="width:${M.boundedNumber(memPercent,0,100)??0}%;background:${M.usageColor(memPercent)}"></span></div><div class="metric-note">Active + wired + compressed</div></section>
        <section class="metric"><div class="metric-top">${icon('battery')}Battery charge<button class="arrow" data-page="battery" aria-label="Open battery details">${icon('northeast')}</button></div><div class="metric-value">${num(b.chargePercent)}<small>%</small></div><div class="metric-track"><span style="width:${M.boundedNumber(b.chargePercent,0,100)??0}%;background:#b9d99a"></span></div><div class="metric-note">${b.onAC===true?'Connected to AC':b.onAC===false?'On battery':'Power source unavailable'} · ${health===null?'Health not available':num(health)+'% reported health'}</div></section>
        <section class="metric"><div class="metric-top">${icon('drive')}Available storage<button class="arrow" data-action="setting" data-id="storage" aria-label="Open storage settings">${icon('northeast')}</button></div><div class="metric-value">${num(s.freeGB,1)}<small>GB free</small></div><div class="metric-track"><span style="width:${M.boundedNumber((1-s.freeGB/s.totalGB)*100,0,100)??0}%;background:#9ebddd"></span></div><div class="metric-note">Home filesystem · APFS may share space</div></section>
      </div>
      <div class="two-col"><section class="panel"><div class="panel-head"><div><h2>A pulse on performance</h2><p>Aggregate CPU activity. Not a clock-speed measurement.</p></div><span class="panel-tag"><span class="dot"></span>${isNative?'ON DEVICE':'PREVIEW'}</span></div><div class="chart-wrap">${chart()}</div><div class="chart-footer"><span class="chart-legend"><i></i>CPU utilization</span><span>${isNative?'Recent local readings':'Illustrative readings, not a benchmark'}</span></div></section>
      <section class="panel"><div class="panel-head"><h2>Everyday essentials</h2><span class="quiet-label">QUICK ACCESS</span></div>${quick('display','Display & brightness','Keep OLED, DPCD and Fn behavior intact.','display')}${quick('volume','Sound & microphone','Use the existing working audio stack.','audio')}${quick('keyboard','Keyboard & trackpad','System preferences; no ACPI replacement.','keyboard')}</section></div>
      <section class="feature-strip">${icon('spark')}<div><h3>Small changes. A workspace that feels like you.</h3><p>Nine reversible Dock, Finder and appearance preferences. No “magic” boost buttons.</p></div>${pageButton('tweaks','Explore tweaks')}</section>`+footer();
  }
  function quick(ic,text,sub,id){return `<div class="quick-row"><span class="quick-icon">${icon(ic)}</span><div class="quick-info"><strong>${e(text)}</strong><p>${e(sub)}</p></div><button class="icon-button" data-action="setting" data-id="${e(id)}" aria-label="Open ${e(text)} settings">${icon('chevron')}</button></div>`;}
  function performance(){
    const c=state.cpu||{},m=state.memory||{},gpu=state.gpu?.[0],samples=state.powerSample||[];
    return title('Performance, without the guesswork.','See what macOS exposes. Measure before changing your CPU or GPU configuration.')+
      `<div class="detail-grid"><section class="detail-card">${icon('cpu')}<h3>CPU utilization</h3><div class="large-value">${num(c.loadPercent)}<small> %</small></div><p>${e(c.name||'Unavailable')}<br>${e(c.logicalCores??'—')} logical cores · not CPU power-management certification</p>${pill('Read-only counters','info')}</section><section class="detail-card">${icon('memory')}<h3>Memory in use</h3><div class="large-value">${num(m.usedGB,1)}<small> / ${num(m.totalGB)} GB</small></div><p>Compression ${num(m.compressedGB,2)} GB<br>Swap currently used ${num(m.swapMB)} MB. These alone do not prove memory pressure.</p>${setting('login','Review login items','ghost')}</section><section class="detail-card gpu-accent">${icon('display')}<h3>Graphics device</h3><p style="margin-top:22px;color:var(--text)">${e(gpu?.name||'No Metal device returned')}</p><p>Metal 3 family flag: ${gpu?gpu.metal3Family?'reported supported':'not reported supported':'unavailable'}. A family flag is not a workload test. GPU load is unavailable unless a verified counter is provided.</p>${pill('No GPU driver changes','info')}</section></div>
      <section class="panel"><div class="panel-head"><div><h2>CPU activity</h2><p>Low usage is not proof of low clocks, low watts or working deep sleep.</p></div></div><div class="chart-wrap">${chart()}</div></section>
      <h2 class="subheading">Power & sensor sample ${button('Take 5-second sample','power','','secondary')}</h2>
      <section class="panel">${samples.length?`<div class="sample-list">${samples.map(s=>`<div class="sample-row"><span>${e(s.label)}</span><strong>${e(s.value)}</strong></div>`).join('')}</div>`:`<div class="empty-state">${icon('activity')}<h3>Real measurements, if the hardware exposes them.</h3><p>Optional built-in powermetrics sampling uses a local macOS administrator prompt. No task list, stress test or persistent setting change. Unsupported temperature, frequency and power fields stay unavailable.</p>${button('Collect a short sample','power')}</div>`}</section>
      <div class="notice blue">No automatic CPUFriend profile, CPUID rewrite, boost/undervolt control or kext cleanup is included. Those need exact hardware evidence and a separately tested candidate—not a generic performance preset.</div>`+footer();
  }
  function battery(){
    const b=state.battery||{},health=M.capacityHealth(b);
    return title('Power, with a little perspective.','Current charge and battery capacity are different measurements.')+
      `<div class="detail-grid"><section class="detail-card">${icon('battery')}<h3>Current charge</h3><div class="large-value">${num(b.chargePercent)}<small> %</small></div><p>${b.onAC===true?'Connected to AC power':b.onAC===false?'Running on battery':'Power source unavailable'} · ${b.charging?'charging':'not charging / unknown'}</p>${setting('battery','Open Battery settings','ghost')}</section><section class="detail-card">${icon('activity')}<h3>Reported capacity health</h3><div class="large-value" style="color:var(--amber)">${num(health,1)}<small> %</small></div><p>Full charge ${num(b.AppleRawMaxCapacity??b.MaxCapacity)} / design ${num(b.DesignCapacity)} capacity units. ACPI-reported; confirm the ratio independently.</p>${pill(health===null?'Capacity unavailable':health<80?'Capacity check recommended':'Reported ratio only',health!==null&&health<80?'warning':'neutral')}</section><section class="detail-card">${icon('restore')}<h3>Cycle count</h3><div class="large-value">${num(b.CycleCount)}</div><p>Cycles alone do not establish battery health. Software cannot restore physically lost capacity.</p>${pill('No charge-limit driver','neutral')}</section></div>
      <section class="panel"><div class="setting-row"><span class="quick-icon">${icon('timer')}</span><div class="row-body"><h3>Stay awake, temporarily</h3><p>Prevent idle system sleep for up to 15 minutes. Not a sleep fix; may increase battery consumption. Stops when you quit the app.</p><small>${state.awake?'Temporary assertion is active.':'No persistent pmset changes.'}</small></div><div class="row-control">${button(state.awake?'Stop keep-awake':'Keep awake 15 min','awake')}</div></div></section>
      <div class="notice">On Hackintosh, battery values come through ACPI/SMC reporting. If capacity is low, confirm with native Windows or manufacturer diagnostics before deciding on service. Don’t use full-discharge cycles or a replacement battery kext simply to hide a warning.</div>
      <h2 class="subheading">Firmware features</h2><div class="support-grid">${unsupported('battery','Battery charge limit','Firmware charging thresholds need a verified model-specific firmware interface. No 60/80/100% charge-limit write is implemented.')}${unsupported('fan','Fan curves & thermal modes','No verified model-specific EC/WMI bridge is bundled. Fan speed, cooling profiles and arbitrary EC-register writes are intentionally unavailable.')}</div>`+footer();
  }
  function unsupported(ic,heading,text){return `<section class="detail-card unavailable">${icon(ic)}<h3>${e(heading)}</h3><p>${e(text)}</p>${pill('Not available · hardware interface required','neutral')}</section>`;}
  function display(){
    const d=state.display||{},g=state.gpu?.[0];
    return title('Your display. Your sound.','Use supported controls without replacing your working graphics and audio configuration.')+
      `<div class="two-col"><section class="panel panel-padding display-accent"><span class="eyebrow">Main display</span><h2 style="margin-top:14px;font-size:21px">${d.width?`${e(d.width)} × ${e(d.height)}`:'Resolution unavailable'}</h2><p class="quiet-label" style="margin:10px 0 22px">${d.refreshHz>0?num(d.refreshHz)+' Hz reported':'Refresh rate unavailable'} · ${num(d.screenCount)} screen(s)</p>${heroArt()}<div class="inline-actions">${setting('display','Display & brightness')}${setting('accessibility','Motion & transparency','ghost')}</div></section><section class="panel"><div class="panel-head"><h2>Output volume</h2>${pill('Core Audio','info')}</div><div class="panel-padding"><div class="large-value">${num(state.volume)}<small> %</small></div><div class="range-control">${icon('volume')}<input id="volume" aria-label="System output volume" type="range" min="0" max="100" value="${M.boundedNumber(state.volume,0,100)??0}" ${typeof state.volume!=='number'||busy?'disabled':''}><output id="volume-output">${num(state.volume)}%</output></div><p style="font-size:10px;color:var(--muted);line-height:1.8">Changes the default output’s exposed software volume. Unsupported outputs open Sound settings instead. It does not change your codec layout.</p>${setting('audio','Sound & microphone','ghost')}</div><div class="quick-row"><span class="quick-icon">${icon('keyboard')}</span><div class="quick-info"><strong>Keep the keys that already work.</strong><p>Use your existing brightness/Fn keys. Keyboard lighting and custom DPCD brightness are not rewritten by this app.</p></div></div></section></div>
      <div class="notice blue">GPU: ${e(g?.name||'Unavailable')}. Your existing graphics, backlight and Fn implementation remains outside this utility. No fake “Metal 3 unlock”, HDR switch or guessed backlight register is provided. Keep the existing known-good panel configuration.</div>
      <div class="row-list">${shortcutRow('keyboard','Keyboard & keyboard lighting','Use macOS preferences and the existing Fn implementation.','keyboard')}${shortcutRow('hardware','Trackpad & gestures','No PS/2 or I²C driver is disabled or replaced.','trackpad')}</div>`+footer();
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
      ['Memory',`${num(state.memory?.totalGB)} GB installed`,'Read via macOS','info'],
      ['SMBIOS model',state.smbiosModel||'Unavailable','Not physical model','neutral'],
      ['USB','No USB mapping or driver changes are made by this app.','Function untested here','neutral'],
      ['Audio',M.capabilities(state).volume?'A default-output volume scalar is exposed. Speakers/mic/jack still need real tests.':'No usable output-volume scalar reported. Use Sound settings.','Capability only','neutral'],
      ['Display / Fn','Existing graphics, backlight and input drivers are left unchanged.','No new driver test','neutral'],
      ['Wi-Fi / Bluetooth','Use the existing configured drivers. No Continuity guarantee.','Not tested in app','neutral'],
      ['CPU/GPU temperature','Only shown if optional powermetrics returns a supported field.','May be unavailable','neutral'],
      ['GPU utilization',caps.gpuUsage?'A reported counter exists; validate it on this driver.':'Unavailable. A GPU name or Metal flag is not a utilization measurement.','Never fabricated','neutral'],
      ['Firmware / DSP','Clock boost, fan curves, charge caps, auto HDR, DTS and system-wide mic DSP are not implemented.','Not universal','neutral']
    ];
    return title('Know what is—and isn’t—connected.','A capability inventory, not an automatic hardware mapper or compatibility certificate.')+
      `<section class="panel"><table class="spec-table"><tbody>${rows.map(r=>`<tr><td>${e(r[0])}</td><td>${e(r[1])}</td><td>${pill(r[2],r[3])}</td></tr>`).join('')}</tbody></table></section>
      <div class="inline-actions">${setting('wifi','Wi-Fi settings','ghost')}${setting('bluetooth','Bluetooth settings','ghost')}${setting('trackpad','Trackpad settings','ghost')}</div>
      <h2 class="subheading">Unsupported firmware controls stay honest.</h2><div class="support-grid">${unsupported('cpu','ASUS performance profiles','Windows MyASUS firmware modes cannot be recreated by renaming macOS CPU presets. No clocks, voltage, power limits, MSRs or arbitrary ACPI methods are written.')}${unsupported('fan','Direct fan & EC access','A model-specific verified interface and separate hardware testing are required. This version contains no kernel extension, privileged daemon or firmware bridge.')}</div>`+footer();
  }
  function recovery(){return title('You stay in control.','A small footprint, a visible restore path, and no silent system changes.')+
    `<div class="two-col"><section class="panel"><div class="panel-head"><h2>Undo without guessing</h2>${pill('Local journal','info')}</div><div class="step-list"><div class="step"><div><strong>Before a desktop preference changes</strong><p>Its exact original value—or the fact it was unset—is saved in your user Application Support folder. If a restore point cannot be saved, the change is refused.</p></div></div><div class="step"><div><strong>When you restore</strong><p>Only settings saved by this app are eligible. If a newer choice was made elsewhere, restore skips it instead of overwriting it.</p></div></div><div class="step"><div><strong>When you quit</strong><p>Temporary keep-awake ends. Applied desktop preferences remain until you restore them. No startup agent, automatic updater or background tuning service is installed.</p></div></div></div></section>
    <section class="panel panel-padding"><h2>Recovery tools</h2><p style="font-size:11px;color:var(--muted);line-height:1.9;margin:16px 0 24px">Restore is limited to this app’s Dock, Finder and appearance changes. It is not an EFI backup or a macOS rollback tool.</p><div class="inline-actions">${button('Restore my desktop changes','restore-all')}${button('Export minimized snapshot','export','','ghost')}</div><div class="notice blue">The restore file belongs to you. Keep it until your original preferences are restored. No serial, full registry, account name, Wi-Fi address or EFI is included in an exported snapshot.</div></section></div>
    <section class="feature-strip">${icon('shield')}<div><h3>Your known-good EFI stays yours.</h3><p>No EFI mounts or writes. No Windows changes, firmware access, NVRAM resets, SIP changes or OS updates.</p></div></section>
    <h2 class="subheading">System preferences, without hidden edits</h2><div class="row-list">${shortcutRow('sliders','Login items & background apps','Review what starts with your session. Nothing is disabled automatically.','login')}${shortcutRow('drive','Storage','Review storage in macOS. No cache purges, file deletion or swap disabling.','storage')}${shortcutRow('help','Notifications','Decide which apps can interrupt your work.','notifications')}</div>`+footer();}
  function about(){return title('A companion. Not a replacement firmware.','Independent software with capability-specific, evidence-first hardware support.')+
    `<section class="panel panel-padding"><div class="about-mark"><img src="icon.svg" alt="KL monogram"><div><h2>KL-06</h2><p>Local control center · 0.2.1 · source-built preview</p></div></div><p style="font-size:12px;color:var(--muted);line-height:1.9;max-width:720px">A lightweight macOS window and menu-bar companion, using AppKit, WebKit, IOKit, Metal and Core Audio. No Electron runtime, cloud account, third-party downloads at runtime or system “cleaner”. This is not an ASUS product and is not affiliated with ASUS.</p><div class="inline-actions">${button('Export a minimized snapshot','export')}${pageButton('hardware','View capability limits','ghost')}</div></section>
    <div class="notice">This version’s interface and safety checks can be tested here; the native macOS code must be built and verified on your actual Mac. Do not mistake this browser preview for live access or proof that every native feature works.</div>
    <section class="row-list"><div class="setting-row"><span class="quick-icon">${icon('keyboard')}</span><div class="row-body"><h3>F13 / PrtSc · show or hide KL-06</h3><p>${!isNative?'Available only in the running native app, not this browser preview.':state.hotkey?.registered===true?'Registered: F13 alone (virtual keyCode 105). Brings KL-06 forward, or hides it when already in front.':'Unavailable: macOS did not register the shortcut. Use the KL menu bar or Dock; review conflicting shortcuts, then quit/reopen to retry.'} Native dialogs stay accessible. Hold does not repeatedly toggle. Quitting releases F13. No key remapping or keyboard-monitoring permission is requested.</p></div></div><div class="setting-row"><span class="quick-icon">${icon('lock')}</span><div class="row-body"><h3>Administrator access is optional and bounded</h3><p>Only the explicit power-sampling action requests macOS authorization for one fixed read-only command. The app never asks you to enter a password into its interface.</p></div></div><div class="setting-row"><span class="quick-icon">${icon('display')}</span><div class="row-body"><h3>Preserve what already works</h3><p>Existing graphics, Fn and audio stay untouched. A hardware report can guide future support; it cannot grant universal compatibility, fix a driver or certify an OS upgrade.</p></div></div></section>`+footer();}
  const labels={overview:'Overview',performance:'Performance',battery:'Power & battery',display:'Display & sound',tweaks:'Desktop tweaks',hardware:'My hardware',recovery:'Safety & restore',about:'About KL-06'};
  const navs={overview:'grid',performance:'activity',battery:'battery',display:'display',tweaks:'sliders',hardware:'hardware',recovery:'restore',about:'help'};
  function navigation(ids){return `<div class="nav-group">${ids.map(id=>`<button class="nav ${page===id?'active':''}" data-page="${id}" title="${labels[id]}" ${page===id?'aria-current="page"':''}>${icon(navs[id])}<span class="nav-label">${labels[id]}</span>${id==='tweaks'?'<span class="count">9</span>':''}</button>`).join('')}</div>`;}
  function render(){
    const scroll=document.querySelector('.workspace')?.scrollTop||0;
    const body=state?({overview,performance,battery,display,tweaks,hardware,recovery,about}[page]||overview)():`<div class="empty-state"><h3>${stale?'Local bridge not available':'Reading local counters…'}</h3><p>${stale?'No live data has been received. No demo values will be presented as your measurements.':'No hardware settings are being changed.'}</p></div>`;
    document.getElementById('app').innerHTML=`<div class="shell"><aside class="sidebar"><div class="brand"><img src="icon.svg" alt=""><div><span class="wordmark">KL-06</span><small>YOUR LOCAL COMPANION</small></div></div><div><div class="nav-group-label">WORKSPACE</div>${navigation(['overview','performance','battery','display'])}</div><div><div class="nav-group-label">PERSONALIZE</div>${navigation(['tweaks','hardware'])}</div><div class="sidebar-bottom">${navigation(['recovery','about'])}<div class="device-mini">${icon('laptop')}<div><strong>Local hardware</strong><p><span class="dot"></span>${isNative?'On-device companion':'Interface preview'}</p></div></div><div class="privacy-foot">${icon('lock')}No cloud. No telemetry.</div></div></aside><main class="workspace"><header class="topbar"><div class="breadcrumb"><span>My workspace</span><span>/</span><strong>${e(labels[page])}</strong></div><div class="top-actions"><span class="mode-badge ${isNative&&!stale?'live':''}"><span class="dot ${busy?'busy-dot':''}"></span>${stale?'DATA UNAVAILABLE':isNative?'LOCAL · NATIVE':'DEMO · NOT LIVE'}</span><button class="icon-button" data-action="refresh" aria-label="Refresh counters" title="Refresh">${icon('refresh')}</button><button class="icon-button" data-action="theme" aria-label="Switch appearance" title="Switch appearance">${icon(light?'moon':'sun')}</button></div></header>${stale?'<div class="stale-banner">Local counters are unavailable or stale. Last-known values are not new measurements.</div>':''}<div class="main-content">${body}</div></main></div>`;
    document.querySelector('.workspace').scrollTop=scroll;
  }
  function toast(message){const t=document.getElementById('toast');t.textContent=message;t.classList.add('visible');clearTimeout(timer);timer=setTimeout(()=>t.classList.remove('visible'),6500);}
  function demoDialog(){
    const root=document.getElementById('dialog-root');
    root.innerHTML=`<div class="modal-overlay"><section class="modal" role="dialog" aria-modal="true" aria-labelledby="demo-title">${icon('laptop')}<h2 id="demo-title">Meet the native Mac app.</h2><p>This is a visual preview with illustrative data. It cannot read or change your Mac.</p><p>Build <strong>KL-06.app</strong> on your Mac using the included <strong>BUILD-MAC.command</strong>, then open it to use supported controls. Firmware controls remain unavailable, not simulated.</p><button class="button" data-action="dismiss">Got it</button></section></div>`;
    root.querySelector('button').focus();
  }
  async function refresh(){
    if(document.hidden||busy||document.querySelector('#volume:active'))return;
    try{state=await provider.request('state');stale=false;const n=M.boundedNumber(state.cpu?.loadPercent,0,100);if(isNative&&n!==null){history.push(n);history=history.slice(-35);}render();}
    catch{stale=true;render();}
  }
  async function act(method,params={}){
    if(!isNative){demoDialog();return;}
    if(busy)return;busy=true;render();
    try{const result=await provider.request(method,params);toast(typeof result==='string'?result:'Done.');}
    catch(error){toast(error.message);}
    finally{busy=false;await refresh();}
  }
  document.addEventListener('click',ev=>{
    const el=ev.target.closest('button');if(!el||el.disabled)return;
    if(el.dataset.page){page=el.dataset.page;filter='All';render();document.querySelector('.workspace').scrollTop=0;return;}
    if(el.dataset.filter){filter=el.dataset.filter;render();return;}
    const id=el.dataset.id;
    switch(el.dataset.action){
      case 'dismiss':document.getElementById('dialog-root').replaceChildren();return;
      case 'theme':light=!light;document.documentElement.classList.toggle('light',light);render();return;
      case 'refresh':refresh();toast(isNative?'Refreshing local counters.':'Preview data only. No hardware is connected.');return;
      case 'setting':act('openSetting',{id});return;
      case 'tweak':act('applyTweak',{id});return;
      case 'restore':act('restoreTweak',{id});return;
      case 'restore-all':act('restoreAll');return;
      case 'restart':act('restartUI',{app:id});return;
      case 'power':act('powerSample');return;
      case 'awake':act('keepAwake');return;
      case 'export':act('exportReport');return;
    }
  });
  document.addEventListener('input',ev=>{if(ev.target.id==='volume'){document.getElementById('volume-output').textContent=ev.target.value+'%';}});
  document.addEventListener('change',ev=>{if(ev.target.id==='volume')act('setVolume',{value:Number(ev.target.value)});});
  document.addEventListener('keydown',ev=>{if(ev.key==='Escape')document.getElementById('dialog-root').replaceChildren();});
  document.addEventListener('visibilitychange',()=>{if(isNative&&!document.hidden)refresh();});
  render();if(isNative){refresh();setInterval(refresh,2000);}
})();
