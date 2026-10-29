// Mini Korus: the notch minis take their agent's colour, look around and loop their permanent emote (BotEngine.swift doMiniBehaviorLoop).
// Ports BotEngine.swift doMiniBehaviorLoop() 453-524 (happy: hop and squash every 2.2-3.4 s; annoyed: a fast head shake
// every 3-5.5 s; wink: a 0.55 s wink and tilt every 2.2-4.2 s; love: two hearts and a sway every 2.6-4.1 s), setPermanentEmote()
// 765-786 (the emote's eyes stay, wink excepted; the first behaviour 0.8-2.5 s later), the idle pulse of update() 1015-1018,
// the wandering look of update() 937-946 (a new random look every 0.5-2 s, never the pointer),
// and notch-buddy.html Bot bodyColor 609-616 (light = colour + 35 % white, dark = colour + 18 % black, edges shaded).
// Koru keeps her face, eyes and beak; the body, belly and wings take the agent colour (PillCatalog.swift).
(()=>{
const {register,E,NOW,rand,hexRgb,rgba,mix,EMOTES}=Koru;
const WHITE=[255,255,255], BLACK=[0,0,0];
const deep=(c,k)=>c.map(v=>v*v/255*k);                    // a darker, more saturated shade (the colour multiplied by itself)
const AGENTS={claude:'#F5F6F8',codex:'#2DD4BF'};             // PillCatalog.swift: integration_claude, agent_codex
const rnd=(a,b)=>a+(b-a)*rand();

/* ---------------- PERMANENT EMOTE ---------------- */
// One behaviour of the permanent emote; [lock, retry ms, gap ms, gap jitter ms, run] (BotEngine.swift:453-524).
const LOOP={
  // Swift's hop (-0.3 R, sy .82/1.18, sx 1.15) is sized for Mochi's body; Koru's wings (1.41 R of the canvas's 1.667 R) and tufts
  // fill the 48 px canvas, so the hop and the squash are scaled down until no frame leaves it.
  happy:['oy',400,2200,1200,b=>{ b.anim('oy',[[-.24,120,E.out],[.02,200,E.inOut],[0,160,E.back]]);
    b.anim('sy',[[.88,80,E.out],[1.07,130,E.out],[.94,160,E.inOut],[1,200,E.back]]); b.anim('sx',[[1.08,80,E.out],[.94,130,E.out],[1.03,160,E.inOut],[1,200,E.back]]) }],
  annoyed:['yaw',500,3000,2500,b=>b.anim('yaw',[[-.65,50,E.out],[.65,90,E.inOut],[-.5,80,E.inOut],[.4,75,E.inOut],[-.2,70,E.inOut],[0,140,E.out]])],
  wink:[null,0,2200,2000,b=>{ b.override('wink',550); b.anim('tilt',[[.13,100,E.out],[.13,320,E.lin],[0,200,E.inOut]]) }],
  // The 48 px canvas has no room above the head: the hearts rise beside it, slower, and fade before its top.
  love:[null,0,2600,1500,b=>{ b.emit('heart',2).forEach((p,i)=>{ const sd=i?1:-1;
      Object.assign(p,{x:sd*(.6+rand()*.15),y:-.7-rand()*.1,vx:sd*.08,vy:-(.25+rand()*.08),life:1.1+rand()*.2,sz:.14+rand()*.04}) });
    b.anim('tilt',[[-.1,180,E.out],[.1,340,E.inOut],[0,220,E.inOut]]) }]};
function tick(b){ const L=LOOP[b.perm]; if(!b.mini||!L) return; const [lock,retry,gap,jit,run]=L;
  if(lock&&b.tweening(lock)){ b.after('perm',retry,()=>tick(b)); return }
  run(b); b.after('perm',gap+rand()*jit,()=>tick(b)) }
// setPermanentEmote(): its eyes replace a running emote's and stay (minis only, see modify). first: ms to the first behaviour,
// null for none (captures start it with ?act or ?film=perm).
function setPerm(b,e,first=800+rand()*1700){ b.perm=LOOP[e]?e:null; b.permEye=b.perm&&b.perm!=='wink'?EMOTES[b.perm].eye:null;
  if(b.permEye) b.clearOverride(); b.cancel('perm');
  if(b.perm&&first!=null) b.after('perm',first,()=>tick(b)) }

/* ---------------- AGENT COLOUR ---------------- */
// bot.palette (core.js PALETTE) from the agent colour: the prototype's ramp under core's key light, from the lit dome
// (+80 % white) to a shaded base that keeps its saturation (core's teal bounce lights would grey a plain darker shade),
// a paler belly, wings in a deeper, more saturated shade.
// Not expressible, so left out: the soft (blurred) belly edge and the shade at the wing root; core keeps the state light.
const palette=c=>({body:[mix(c,WHITE,.8),mix(c,WHITE,.6),mix(c,WHITE,.32),mix(c,WHITE,.08),mix(mix(c,deep(c,1),.3),BLACK,.16)].map(v=>rgba(v,1)),
  belly:[rgba(mix(c,WHITE,.3),1),rgba(mix(c,WHITE,.18),1),rgba(mix(c,WHITE,.12),.75)],
  wing:[rgba(mix(deep(c,.78),WHITE,.15),1),rgba(deep(c,.5),1)]});
function paint(b,hex){ b.palette=hex?palette(hexRgb(hex)):null }

/* ---------------- WANDERING LOOK ---------------- */
// Not while the state has its own look or scan, sleeps (a mood-asleep mini too) or is dizzy; captures with &lx keep their look.
function wander(b,tg){ const w=b.wander, c=b.cfg; if(!b.mini||!w||b.state==='thinking'||c.scan||b.state==='sleeping'||b.state==='dizzy'||b.mood&&b.mood.sleep) return;
  const n=NOW()/1000; if(n>w.next){ w.x=rnd(-.88,.88); w.y=rnd(-.55,.45); w.next=n+rnd(.5,2) }
  tg.yaw=w.x*.62; tg.pitch=w.y*.5 }
register({name:'minis',
  init(b){ b.palette=null; b.perm=b.permEye=null; b.wander={x:0,y:0,next:0} },
  target:wander,
  // The idle pulse of minis (unique phase per bot through t0), as BotEngine.swift:1015-1018; breathing states keep theirs.
  modify(b,m,t){ if(!b.mini) return; if(b.permEye&&!m.eye) m.eye=b.permEye;
    if(!b.cfg.breathe){ const p=Math.sin(t*2.2); m.sy*=1+p*.04; m.sx*=1-p*.02 } },
  layers:{
    // ?notch=1: on black, as in the notch.
    front(b,d){ if(!b.notch) return; const x=d.x; x.setTransform(1,0,0,1,0,0); x.globalCompositeOperation='destination-over'; x.fillStyle='#000'; x.fillRect(0,0,d.W,d.H) } },
  actions:{perm:tick},
  // ?mini=1 draws as a mini; &color=<hex> or &agent=claude|codex; &perm=happy|annoyed|wink|love; &act=<ms>: one behaviour <ms>
  // before the still (?film=perm runs one at frame 0); &notch=1 on black; &lx=<look x>.
  capture(b,p){ if(p.get('mini')==='1') b.mini=true; if(p.get('notch')==='1'){ b.notch=true; b.bg=false } if(p.has('lx')){ b.look.x=+p.get('lx'); b.wander=null }
    const col=p.get('color')||AGENTS[p.get('agent')]; if(col) paint(b,col);
    if(p.has('perm')) setPerm(b,p.get('perm'),p.has('act')?Math.max(0,2200-(+p.get('act'))):null) },
  // Live: the two notch minis are a Claude Code and a Codex session; the buttons pick their permanent emote.
  controls(ui,{mini,mini2}){ paint(mini,AGENTS.claude); paint(mini2,AGENTS.codex); ui.group('Minis: emote fixo');
    const btns=[], pick=(e,btn)=>{ for(const b of [mini,mini2]) setPerm(b,e); for(const q of btns) q.classList.toggle('on',q===btn) };
    for(const [e,label,c] of [['happy','Feliz','#F7B32B'],['annoyed','Irritada','#FF5A5A'],['wink','Piscadinha','#A78BFA'],['love','Amor','#FF4D6D'],[null,'Sem emote','#9A9FA8']]){
      const btn=ui.button(label,c,()=>pick(e,btn)); btn.title='Emote fixo dos minis'; btns.push(btn) }
    btns[btns.length-1].classList.add('on') }
});
})();
