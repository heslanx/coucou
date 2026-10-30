// Sounds: Koncluí's set in Koru's sonic identity (docs/SOUND.md), played on the bot's sound events (states, emotes, greet, slap, gulp,
// listening) as the Mac app does. The files are scripts/konclui/sounds.py's output (konclui branch) converted to AAC. Only the live main
// bot plays them: captures run on the virtual clock and stay silent, and the notch minis are quiet as in the app.
// Every file is loaded at start (impl-preload-audio), the volume starts at the app's 0.12 (impl-default-subtle), a replay starts from 0
// (impl-reset-current-time), and nothing sounds while prefers-reduced-motion asks for less (checked live, a11y-reduced-motion-check).
// "Som ambiente" (off by default) plays the state's loop while Koru stays in it: sleeping, thinking, working, searching.
(()=>{
const {register,Clock}=Koru;
const NAMES=['annoyed','approval','approve','attach','blip','close','dizzy','error','finish','greet','greeting','gulp','hover','love','open',
  'peek','pop','proud','question','rate','search','send','slap','sleep','think','tick','wink','work','yawn','owl','sale'];
const LOOPS={sleeping:'sleep-loop',thinking:'think-loop',working:'work-loop',searching:'search-loop'};
const DIR=document.currentScript?new URL('../sounds/',document.currentScript.src).href:'koru/sounds/';
let on=true, ambient=false, volume=.12, audition=null, current=null;   // current: the loop sounding now
const rm=window.matchMedia?matchMedia('(prefers-reduced-motion: reduce)'):null, quiet=()=>!!(rm&&rm.matches);
const pools={};   // two players a sound, so a quick repeat overlaps the first instead of cutting it
if(!Clock.virtual) for(const n of NAMES) pools[n]=[0,1].map(()=>{ const a=new Audio(`${DIR}${n}.m4a`); a.preload='auto'; return a });
function play(name){ if(Clock.virtual||!on||quiet()) return; const pool=pools[name]; if(!pool) return;
  const a=pool.find(p=>p.paused)||pool[0]; a.currentTime=0; a.volume=volume;
  a.play().catch(()=>{}) }   // refused until the page has had a click (browser autoplay rule): that sound is simply skipped

// Loops go through Web Audio: an <audio loop> seeks back to the start with an audible pause, a looping buffer joins sample to sample.
// koru/sounds/loops.js carries the -loop.m4a files as base64 (a file:// page cannot fetch them); they are decoded at start, offline.
// A loop not decoded (no Web Audio, a decoder that refuses AAC) plays through an <audio loop> instead: audible, with that pause.
const LOOP_S=4, PRIMING=2112/48000;   // the loop period; AAC's encoder delay, skipped when the decoder leaves it in
const AC=window.AudioContext||window.webkitAudioContext, bufs={}, els={};
let ctx=null, master=null, voice=null;   // the live context is made on first use (after a click: no autoplay warning); voice: what sounds now
if(!Clock.virtual){ for(const n of Object.values(LOOPS)){ const a=new Audio(`${DIR}${n}.m4a`); a.preload='auto'; a.loop=true; els[n]=a }
  if(AC&&window.OfflineAudioContext){ const dec=new OfflineAudioContext(2,1,48000), s=document.createElement('script'); s.src=DIR+'loops.js';
    s.onload=()=>{ for(const n in window.KoruLoops||{}){ const bin=atob(KoruLoops[n]), u8=new Uint8Array(bin.length);
      for(let i=0;i<bin.length;i++) u8[i]=bin.charCodeAt(i);
      dec.decodeAudioData(u8.buffer).then(b=>{ bufs[n]=b },()=>{}) } };
    document.head.appendChild(s) } }
// One loop at a time, a buffer faded in and out over ~50 ms (a bed cut mid-wave clicks).
function loopTo(name){ if(name===current) return; const now=ctx?ctx.currentTime:0;
  if(voice&&voice.el){ voice.el.pause(); voice.el.currentTime=0 } else if(voice){ voice.g.gain.setTargetAtTime(0,now,.015); voice.src.stop(now+.12) }
  voice=null; current=name; if(!name) return;
  if(!bufs[name]){ const el=els[name]; el.currentTime=0; el.volume=volume; el.play().catch(()=>{}); voice={el}; return }
  if(!ctx){ ctx=new AC(); master=ctx.createGain(); master.gain.value=volume; master.connect(ctx.destination) }
  if(ctx.state!=='running') ctx.resume().catch(()=>{});
  const b=bufs[name], lead=b.duration>LOOP_S+.02?PRIMING:0, src=ctx.createBufferSource(), g=ctx.createGain(), t=ctx.currentTime;
  src.buffer=b; src.loop=true; src.loopStart=lead; src.loopEnd=lead+LOOP_S;
  g.gain.setValueAtTime(0,t); g.gain.setTargetAtTime(1,t,.015); src.connect(g); g.connect(master); src.start(t,lead); voice={src,g} }
const wanted=b=>Clock.virtual||!on||quiet()||document.hidden?null:audition||(ambient?LOOPS[b.state]||null:null);
function hush(){ loopTo(null); for(const n in pools) for(const a of pools[n]) a.pause() }
if(rm&&rm.addEventListener) rm.addEventListener('change',()=>{ if(rm.matches) hush() });
document.addEventListener('visibilitychange',()=>{ if(document.hidden) loopTo(null) });   // a hidden page is quiet; the next frame resumes

register({name:'sounds',
  onSound(b,name){ if(!b.mini) play(name) },
  update(b){ if(!b.mini&&!Clock.virtual) loopTo(wanted(b)) },
  controls(ui){ ui.group('Sons');
    ui.toggle('Som','#3CCFD9',v=>{ on=v; if(!v) hush() }).classList.add('on');
    ui.toggle('Som ambiente','#7C8CF8',v=>{ ambient=v });
    ui.slider('Volume',0,.2,.01,volume,v=>{ volume=v; if(master) master.gain.setTargetAtTime(v,ctx.currentTime,.01); if(voice&&voice.el) voice.el.volume=v });   // the app's range (Settings, 0 to 0.2)
    for(const n of NAMES) ui.button(({owl:'Coruja',sale:'Som de venda'})[n]||n,'#5B6472',()=>play(n));
    ui.group('Loops');   // audition: a click plays the loop until clicked again
    const btns={}; for(const n of Object.values(LOOPS)) btns[n]=ui.button(n,'#7C8CF8',()=>{ audition=audition===n?null:n;
      for(const k in btns) btns[k].classList.toggle('on',k===audition) }) }
});
})();
