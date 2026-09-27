// npm install --prefix /tmp/prospector-browser playwright
// NODE_PATH=/tmp/prospector-browser/node_modules node tools/browser-check.cjs [URL]
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
(async () => {
  const browser = await chromium.launch({headless:true,args:['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const errors=[];
  const watch=p=>{p.on('pageerror',e=>errors.push(String(e)));p.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.error(m.text())}});p.on('response',r=>{if(r.status()>=400)errors.push(`${r.status()} ${r.url()}`)})};
  const base=process.argv[2] || 'http://127.0.0.1:8000/build/web/';
  const page=await browser.newPage({viewport:{width:960,height:640}});watch(page);
  const ready=async p=>p.waitForFunction(()=>window.prospector,null,{timeout:120000});
  const state=p=>p.evaluate(()=>window.prospector);
  await page.goto(base+'?prototype&test');await ready(page);
  assert.equal((await state(page)).audio_started,false);
  assert.equal((await state(page)).music_playing,false);
  await page.mouse.click(460,263);
  await page.waitForFunction(()=>window.prospector.mode==='play' && window.prospector.music_playing);
  await page.screenshot({path:'/tmp/prospector-prototype.png'});
  // Start near the gold seam, walking right then forwards to collect using keyboard.
  await page.keyboard.down('d');await page.waitForTimeout(400);await page.keyboard.up('d');
  await page.keyboard.down('w');await page.waitForTimeout(320);await page.keyboard.up('w');
  await page.waitForFunction(()=>window.prospector.gold>0);
  const savedGold=(await state(page)).gold;
  // More than a full circuit: poles, underside, and camera all render while moving.
  await page.keyboard.down('w');await page.waitForTimeout(12000);await page.keyboard.up('w');
  await page.screenshot({path:'/tmp/prospector-circuit.png'});
  await page.keyboard.press('r');await page.waitForTimeout(400);
  await page.keyboard.press('Space');await page.waitForFunction(()=>window.prospector.current===1);
  await page.screenshot({path:'/tmp/prospector-landing.png'});
  await page.keyboard.press('e');await page.waitForTimeout(350);const destination=(await state(page)).selected;
  await page.keyboard.press('Space');await page.waitForFunction(d=>window.prospector.current===d,destination);
  await page.keyboard.press('r');await page.keyboard.press('b');
  await page.waitForFunction(()=>window.prospector.mode==='workshop');
  await page.screenshot({path:'/tmp/prospector-workshop.png'});
  await page.keyboard.press('Escape');
  await page.mouse.click(856,40);await page.waitForFunction(()=>!window.prospector.music_on);
  await page.waitForTimeout(2000);await page.reload();await ready(page);
  assert.equal((await state(page)).music_on,false);assert.equal((await state(page)).gold,savedGold);
  await page.mouse.click(460,263);await page.waitForTimeout(400);assert.equal((await state(page)).music_playing,false);
  // Expand only after prototype input/render checks.
  await page.goto(base+'?test');await ready(page);await page.mouse.click(460,263);await page.waitForTimeout(500);
  await page.screenshot({path:'/tmp/prospector-field.png'});
  console.log('Desktop prototype, save/audio, and expanded field passed.');
  await page.close();
  const phoneContext=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:1,isMobile:true,hasTouch:true});
  const phone=await phoneContext.newPage();watch(phone);await phone.goto(base+'?test');await ready(phone);
  // Godot uses its fixed design viewport, letterboxed to 585x390.
  const point=(x,y)=>({x:129.5+x*390/640,y:y*390/640});
  let p=point(460,263);await phone.touchscreen.tap(p.x,p.y);
  await phone.waitForFunction(()=>window.prospector.mode==='play');
  const cdp=await phoneContext.newCDPSession(phone);
  const right=point(218,580), up=point(115,528);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...right,id:0},{...up,id:1}]});
  await phone.waitForFunction(()=>window.prospector.touches===2);
  await phone.waitForFunction(()=>Math.abs(window.prospector.normal[0])>.1 && Math.abs(window.prospector.normal[2])>.1);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await phone.waitForFunction(()=>window.prospector.touches===0);
  const n=(await state(phone)).normal;assert.ok(Math.abs(n[0])>.1 && Math.abs(n[2])>.1,'Simultaneous diagonal touch actually moves');
  p=point(850,578);await phone.touchscreen.tap(p.x,p.y);
  await phone.waitForFunction(()=>window.prospector.current===1);
  await phone.screenshot({path:'/tmp/prospector-touch.png'});
  assert.deepEqual(errors,[]);
  console.log('PASS: prototype keyboard collection/circuit/hops; workshop; persisted gold/music; gesture audio; nine-stone render; simultaneous touch movement and touch hop.');
  await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
