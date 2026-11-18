'use strict';
(function(root){
 const LIMIT=5*1024*1024, MAX_ROWS=10008, MAX_COLUMNS=512;
 function csv(text){
  if(typeof text!=='string'||text.length>LIMIT||new TextEncoder().encode(text).byteLength>LIMIT)throw new Error('CSV exceeds the 5 MiB decoded UTF-8 input limit.');
  if(text.includes('\0'))throw new Error('Unsupported CSV encoding or null bytes.');
  text=text.replace(/^\uFEFF/,'');let rows=[],row=[],cell='',quoted=false,closed=false;
  const field=()=>{row.push(cell);cell='';closed=false;if(row.length>MAX_COLUMNS)throw new Error('Too many CSV columns.');};
  const record=()=>{field();rows.push(row);row=[];if(rows.length>MAX_ROWS)throw new Error('Too many CSV rows (10,000 samples maximum).');};
  for(let i=0;i<text.length;i++){
   const c=text[i];
   if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++;}else{quoted=false;closed=true;}}else cell+=c;continue;}
   if(c==='"'){if(cell!==''||closed)throw new Error('Malformed CSV quotation.');quoted=true;}
   else if(c===',')field();
   else if(c==='\n'||c==='\r'){if(c==='\r'&&text[i+1]==='\n')i++;record();}
   else if(closed){if(c!==' '&&c!=='\t')throw new Error('Unexpected text after a quoted CSV field.');}
   else cell+=c;
  }
  if(quoted)throw new Error('Unterminated CSV quote.');
  if(cell!==''||row.length||closed)record();return rows;
 }
 function timestamp(date,time){
  // HWiNFO can emit unpadded hours, minutes AND seconds. Treat this as an
  // unverified device-local clock, never claim a UTC acquisition time.
  const d=/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/.exec((date||'').trim());
  const t=/^(\d{1,2}):(\d{1,2}):(\d{1,2})(?:[.,](\d{1,3}))?$/.exec((time||'').trim());
  if(!d||!t)return null;
  const [day,month,year]=d.slice(1).map(Number),[hour,minute,second]=t.slice(1,4).map(Number);
  if(year<1900||year>2200||month<1||month>12||day<1||hour>23||minute>59||second>59)return null;
  const millis=Number((t[4]||'').padEnd(3,'0')||0),value=Date.UTC(year,month-1,day,hour,minute,second,millis),check=new Date(value);
  if(check.getUTCDate()!==day||check.getUTCMonth()!==month-1)return null;
  return {seconds:value/1000,date:`${day}.${month}.${year}`,clock:[hour,minute,second].map(n=>String(n).padStart(2,'0')).join(':')};
 }
 function spec(header,group){
  const h=header.trim();
  if(/^(CPU|System|Chassis|GPU|Fan(?: \d+)?) \[RPM\]$/i.test(h))return {label:h.split(' [')[0]+' fan',unit:'RPM',min:0,max:30000,source:/ASUS NB EC/i.test(group)?'ASUS NB EC (Windows history)':'HWiNFO fan (Windows history)'};
  const known={
   'Average Effective Clock [MHz]':['CPU effective clock','MHz',0,10000],
   'CPU Package [°C]':['CPU package temperature','°C',-40,150],
   'CPU Package Power [W]':['CPU package power','W',0,5000],
   'GPU Core Temperature [°C]':['GPU temperature','°C',-40,150],
   'GPU Clock [MHz]':['GPU clock','MHz',0,10000],
   'Charge Level [%]':['Battery charge','%',0,100],
   'Wear Level [%]':['Battery wear','%',0,100]
  };
  if(!Object.prototype.hasOwnProperty.call(known,h))return null;
  const [label,unit,min,max]=known[h];
  return {label,unit,min,max,source:/\bDTS\b/.test(group)?'CPU DTS (Windows history)':/Enhanced/.test(group)?'CPU Enhanced (Windows history)':'HWiNFO (Windows history)'};
 }
 function parse(text){
  const rows=csv(text);if(rows.length<2)throw new Error('CSV has no sample rows.');
  const head=rows[0];if(head[0]?.trim()!=='Date'||head[1]?.trim()!=='Time')throw new Error('Expected a HWiNFO sensor CSV with Date and Time columns.');
  const final=[...rows].reverse().find(r=>r.some(c=>c.trim()))||[];
  const groups=final.length===head.length&&!timestamp(final[0],final[1])&&final[0]?.trim()!=='Date'?final:[];
  const columns=head.map((h,i)=>{const s=spec(h,groups[i]||'');return s?{...s,index:i,values:[],recent:[]}:null;}).filter(Boolean);
  if(!columns.length)throw new Error('No supported numeric sensor columns found.');
  let samples=0,date=null,first=null,last=null,skipped=0,invalidTimes=0;
  for(const row of rows.slice(1)){
   const stamp=timestamp(row[0],row[1]);
   if(!stamp){if(/^\d/.test(row[0]||''))invalidTimes++;continue;}
   if(row.length!==head.length){skipped++;continue;}
   if(++samples>10000)throw new Error('Too many CSV samples.');
   if(!first){first=stamp;date=stamp.date;}last=stamp;
   for(const c of columns){const raw=(row[c.index]||'').trim();if(!/^-?\d+(?:[.,]\d+)?$/.test(raw))continue;
    const n=Number(raw.replace(',','.'));
    if(Number.isFinite(n)&&n>=c.min&&n<=c.max){c.values.push(n);c.recent.push({time:stamp.seconds,value:n,clock:stamp.clock});if(c.recent.length>120)c.recent.shift();}
   }
  }
  const series=columns.filter(c=>c.values.length).map(c=>{const sorted=[...c.values].sort((a,b)=>a-b),n=sorted.length;return {label:c.label,unit:c.unit,source:c.source,column:c.index,count:n,min:sorted[0],median:n%2?sorted[(n-1)/2]:(sorted[n/2-1]+sorted[n/2])/2,max:sorted[sorted.length-1],recent:c.recent};});
  if(!samples||!series.length)throw new Error('No valid timestamped numeric samples found.');
  return {schema:'KL06_LOCAL_HWINFO_HISTORY_V1',mode:'historical-windows-not-live-mac',recordedDate:date,dateFormat:'day.month.year; device-local clock/timezone unverified',firstClock:first.clock,lastClock:last.clock,samples,skippedMalformedRows:skipped,skippedInvalidTimestamps:invalidTimes,series};
 }
 const api=Object.freeze({parse,csv,timestamp});if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.KLHistory=api;
})(typeof globalThis!=='undefined'?globalThis:this);
