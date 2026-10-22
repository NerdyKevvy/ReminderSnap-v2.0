#!/usr/bin/env node
// Deterministic marketing layouts around unaltered, genuine app captures.
// Requires sharp. No AI-generated app UI, personal account data or remote assets.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const rawDir = path.join(root, 'Artifacts/StoreMedia/raw');
const outDir = path.join(root, 'AppStore/Media');
const font = 'Helvetica Neue,Arial,PingFang SC,sans-serif';
const escape = s => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&apos;'}[c]));
const stories = {
  'en-US': [
    {title:['A snapshot.','Less busywork.'], body:['Import. Review. Save.','Reminders + Calendar, without the retyping.'], tag:'SCREENSHOTS + PDFs', foot:['Fictional example tasks shown. Always review before saving.']},
    {title:['Mac. iPhone.','iPad, too.'], body:['On-device reading, online or offline.','English · 简体中文'], tag:'LOCAL BY DESIGN', foot:['No screenshot uploads. No AI subscription.']},
    {title:['Your tasks.','Apple’s apps.'], body:['Real deadlines in Reminders.','Optional Calendar blocks for a clearer day.'], tag:'REMINDERS + CALENDAR', foot:['iCloud sync: same Apple Account, both apps enabled.','A connection is required for syncing.']}
  ],
  'zh-Hans': [
    {title:['截个图，','少点手动输入。'], body:['导入、核对，再保存。','提醒事项与日历，无需逐条重填。'], tag:'截图 + PDF', foot:['图中为虚构示例任务。保存前请始终核对识别结果。']},
    {title:['Mac 到 iPhone，','一样顺手。'], body:['也支持 iPad。本地识别，有网没网都能用。','English · 简体中文'], tag:'始终本地处理', foot:['截图不上传，无需 AI 订阅。']},
    {title:['你的任务，','熟悉的 Apple 应用。'], body:['提醒事项保留真实截止时间。','可选的日历时间块，让任务一目了然。'], tag:'提醒事项 + 日历', foot:['iCloud 同步需使用同一 Apple 账户，并开启两款应用的同步。','跨设备同步需要网络连接。']}
  ]
};
const captureCache = new Map();
async function capture(device, language, screen) {
  const key = `${device}-${language}-${screen}`;
  if (captureCache.has(key)) return captureCache.get(key);
  const file = path.join(rawDir, key + (device === 'mac' ? '.jpg' : '.png'));
  let pipe = sharp(file);
  const metadata = await pipe.metadata();
  // Remove the OS title bar / capture indicator, never change the app content.
  if (device === 'mac' && screen !== 'editor') {
    pipe = pipe.extract({left:0,top:64,width:metadata.width,height:metadata.height-64});
  }
  const {data,info} = await pipe.png().toBuffer({resolveWithObject:true});
  const result = {href:'data:image/png;base64,'+data.toString('base64'),w:info.width,h:info.height};
  captureCache.set(key,result);
  return result;
}
function text(lines, x, y, size, {color='#e9edf3',weight=500,line=1.16,spacing=-1.5}={}) {
  return `<text font-family="${font}" font-size="${size}" font-weight="${weight}" fill="${color}" letter-spacing="${spacing}">${lines.map((s,i)=>`<tspan x="${x}" y="${y+i*size*line}">${escape(s)}</tspan>`).join('')}</text>`;
}
let frameID = 0;
function frame(img,x,y,w,{radius=30,stroke=3,shadow=true}={}) {
  const h=w*img.h/img.w, id='screen'+(++frameID);
  return `<defs><clipPath id="${id}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${radius}"/></clipPath></defs>
  <rect x="${x-6}" y="${y-6}" width="${w+12}" height="${h+12}" rx="${radius+5}" fill="#171b22" stroke="url(#metal)" stroke-width="${stroke}" ${shadow?'filter="url(#shadow)"':''}/>
  <image href="${img.href}" x="${x}" y="${y}" width="${w}" height="${h}" clip-path="url(#${id})"/>`;
}
function background(w,h,index) {
  return `<defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#1a1f27"/><stop offset=".46" stop-color="#090c10"/><stop offset="1" stop-color="#030405"/></linearGradient>
    <linearGradient id="metal" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#e9edf5"/><stop offset=".22" stop-color="#697583"/><stop offset=".5" stop-color="#252d38"/><stop offset=".72" stop-color="#a6afb9"/><stop offset="1" stop-color="#434b57"/></linearGradient>
    <radialGradient id="glow"><stop stop-color="#9ca9bb" stop-opacity=".17"/><stop offset="1" stop-color="#9ca9bb" stop-opacity="0"/></radialGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="180%"><feDropShadow dx="0" dy="28" stdDeviation="35" flood-color="#000" flood-opacity=".8"/></filter>
  </defs><rect width="${w}" height="${h}" fill="url(#bg)"/>
  <ellipse cx="${w*.84}" cy="${h*.5}" rx="${w*.7}" ry="${h*.7}" fill="url(#glow)"/>
  <path d="M ${-w*.2} ${h*.9} Q ${w*.8} ${h*.2} ${w*1.15} ${h*.7}" fill="none" stroke="#d2dce9" stroke-opacity=".055" stroke-width="2"/>
  ${text([String(index+1).padStart(2,'0')+' / 03'],w-220,110,28,{color:'#697686',spacing:3})}`;
}
async function render(device,locale,index) {
  const story=stories[locale][index], lang=locale==='zh-Hans'?'zh':'en';
  const isMac=device==='mac', isPad=device==='ipad';
  const w=isMac?2880:isPad?2064:1320, h=isMac?1800:isPad?2752:2868;
  const main=await capture(device,index===1?(lang==='en'?'zh':'en'):lang,index===1?'settings':index===2?'editor':'review');
  const icon=await fs.readFile(path.join(root,'Resources/ReminderSnapIcon.png'));
  const pieces=[background(w,h,index)];
  const x=isMac?140:isPad?126:86, brandY=isMac?114:isPad?112:98, iconSize=isMac?64:isPad?76:58;
  pieces.push(`<image href="data:image/png;base64,${icon.toString('base64')}" x="${x}" y="${brandY-iconSize*.7}" width="${iconSize}" height="${iconSize}"/>`);
  pieces.push(text(['ReminderSnap'],x+iconSize+22,brandY,isMac?39:isPad?48:37,{spacing:1,weight:500}));
  if(isMac) {
    const headlineSize=locale==='zh-Hans'?96:122;
    // Mac metadata revision for guideline 5.2.5. Leave the released iOS assets unchanged.
    const headline=index===2?(locale==='zh-Hans'?['你的任务，','日程更清晰。']:['Your tasks.','Your day.']):story.title;
    pieces.push(text(headline,140,310,headlineSize,{weight:500,line:1.19,spacing:locale==='zh-Hans'?-3:-4}));
    const bodyLines = locale==='en-US' ? [
      ['Import. Review. Save.','Reminders + Calendar,','without the retyping.'],
      ['On-device reading,','online or offline.','English · 简体中文'],
      ['Real deadlines in Reminders.','Optional Calendar blocks,','for a clearer day.']
    ][index] : index===1?['也支持 iPad。','本地识别，有网没网都能用。','English · 简体中文']:story.body;
    pieces.push(text(bodyLines,145,690,locale==='zh-Hans'?39:43,{color:'#a8b3c1',line:1.48,spacing:-.4}));
    pieces.push(`<rect x="140" y="1010" width="700" height="1" fill="#98a6b9" opacity=".2"/>`);
    pieces.push(text([story.tag],145,1090,30,{color:'#bac4d0',weight:500,spacing:3}));
    const foot = locale==='en-US' ? [
      ['Fictional example tasks shown.','Always review before saving.'],
      ['No screenshot uploads.','No AI subscription.'],
      ['Choose iCloud lists and calendars.','Use the same Apple Account and enable','sync for Reminders and Calendar.','A connection is required for syncing.']
    ][index] : [
      ['图中为虚构示例任务。','保存前请核对识别结果。'],
      ['截图不上传，无需 AI 订阅。'],
      ['选择 iCloud 列表与日历。','在各设备使用同一 Apple 账户，','并开启提醒事项和日历的同步。','跨设备同步需要网络连接。']
    ][index];
    pieces.push(text(foot,145,1410,locale==='zh-Hans'?29:28,{color:'#8491a1',line:1.55,spacing:0}));
    if(index===2) {
      pieces.push(frame(await capture('mac',lang,'review'),980,690,1330,{radius:28}));
      pieces.push(frame(main,1630,210,1080,{radius:35}));
    } else {
      pieces.push(frame(main,1000,310,1740,{radius:28}));
      if(index===1) pieces.push(frame(await capture('iphone',lang,'review'),2380,1110,260,{radius:34,stroke:3}));
    }
  } else {
    const titleY=isPad?278:235, headlineSize=isPad?locale==='zh-Hans'&&index===2?104:126:locale==='zh-Hans'&&index===2?80:104;
    pieces.push(text(story.title,x,titleY,headlineSize,{weight:500,line:1.16,spacing:locale==='zh-Hans'?-2:-3.5}));
    const bodyY=isPad?585:515, bodySize=isPad?46:36;
    pieces.push(text(story.body,x,bodyY,bodySize,{color:'#a8b3c1',line:1.43,spacing:-.3}));
    const mainW=isPad?1360:924, mainX=(w-mainW)/2, mainY=isPad?730:675;
    pieces.push(frame(main,mainX,mainY,mainW,{radius:isPad?40:86,stroke:isPad?5:4}));
    if(index===1) {
      pieces.push(frame(await capture('mac',lang,'review'),isPad?1080:622,isPad?1970:2255,isPad?850:600,{radius:18,stroke:2}));
    }
    const footSize=isPad?31:29, footY=isPad?2640:2750;
    pieces.push(text(story.foot,x,footY,footSize,{color:'#91a0b1',line:1.42,spacing:0}));
  }
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${pieces.join('\n')}</svg>`;
  const platform=isMac?'macOS':isPad?'iPad-13':'iPhone-6.9';
  const dir=path.join(outDir,locale,platform);await fs.mkdir(dir,{recursive:true});
  const name=['01-snapshot','02-local-and-bilingual','03-apple-and-icloud'][index]+'.png';
  const file=path.join(dir,name);
  await sharp(Buffer.from(svg)).flatten({background:'#080b0f'}).removeAlpha().png({compressionLevel:9}).toFile(file);
  if(device==='iphone') {
    const medium=path.join(outDir,locale,'iPhone-6.3');await fs.mkdir(medium,{recursive:true});
    await sharp(file).resize(1206,2622).removeAlpha().png({compressionLevel:9}).toFile(path.join(medium,name));
  }
  console.log(path.relative(root,file));
  return {device,locale,index,file};
}
async function main() {
  const requested=process.argv.slice(2), devices=requested.length?requested:['mac','iphone','ipad'];
  const results=[];
  for(const device of devices) for(const locale of ['en-US','zh-Hans']) for(let i=0;i<3;i++) results.push(await render(device,locale,i));
  for(const locale of ['en-US','zh-Hans']) {
    const tiles=[];let rows=0;
    for(const device of devices){
      for(const entry of results.filter(r=>r.locale===locale&&r.device===device)) {
        const data=await sharp(entry.file).resize({width:480,height:740,fit:'contain',background:'#10141a'}).png().toBuffer();
        tiles.push({input:data,left:entry.index*500+10,top:rows*780+30});
      } rows++;
    }
    await sharp({create:{width:1500,height:rows*780,channels:3,background:'#10141a'}}).composite(tiles).png().toFile(path.join(root,'Artifacts/StoreMedia/preview-'+locale+'.png'));
  }
  await fs.writeFile(path.join(root,'Artifacts/StoreMedia/render-manifest.json'),JSON.stringify(results.map(({device,locale,index,file})=>({device,locale,feature:index+1,file:path.relative(root,file)})),null,2)+'\n');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
