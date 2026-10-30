// Life: Koru's Organic Life, the motion doctrine of the Koru project (konclui-project/koru docs/motion-doctrine.md, the numbers of
// spec/motion.json, the scheduler of lib/koru-motion.js) on this rig. A 4 s breath and a 3.6 s moving hold under every state that
// does not breathe on its own (LIFE-01, LIFE-02); follow-through: the head trails the body by 40 ms and the tufts by 80 ms (ANIM-05);
// and, while she idles, one quiet micro-action at a time (PERF-03), each on its own jittered window (LIFE-01), none of them a wave,
// a hop or a pulse (PRODUCT-04). The OS's reduced-motion setting, followed live, stills her: no life, and core's bounce, breath and
// scan held (A11Y-02/03). Live it is on (the Vida toggle); captures stay as they were unless ?life=1 (&seed=<k> picks the jitter,
// &reduce=1 forces reduced motion, &lifetrace=1 prints the scheduler's trace). docs/MOTION.md maps every rule to this prototype.
(()=>{
const {register,params,Clock,NOW,G,clamp,smooth,beakFinish}=Koru;
const D=Math.PI/180, CAPTURE=params.get('life')==='1', TRACE=params.has('lifetrace');

// The doctrine's easing roles (koru-motion.js EASE): quadratic in/out/inOut, travel (quintic out), micro (exponential out) and
// layout, here a critically damped settle normalised to its span (no overshoot). The spec's settle overshoots ~10 %: the idle set
// uses layout or out where it has settle.
const EASE={in:t=>t*t,out:t=>1-(1-t)*(1-t),inOut:t=>t<.5?2*t*t:1-Math.pow(-2*t+2,2)/2,travel:t=>1-Math.pow(1-t,5),
  micro:t=>t>=1?1:1-Math.pow(2,-10*t),layout:t=>(1-(1+7*t)*Math.exp(-7*t))/(1-8*Math.exp(-7))};
// A track as spec/motion.json keys it: [[t, v], [t, v, ease], ...], t a fraction of the clip.
function track(keys,u){ if(u<=keys[0][0]) return keys[0][1];
  for(let i=1;i<keys.length;i++){ const [t,v,e]=keys[i]; if(u<=t){ const [t0,v0]=keys[i-1]; return v0+(v-v0)*EASE[e||'inOut']((u-t0)/(t-t0)) } }
  return keys[keys.length-1][1] }

// The carriers as body squash (1 = rest): spec/motion.json breathe and lifeComposition.movingHold. Sleeping keeps core's own breath
// and dizzy its wobble, so they ease out under those states.
const BREATHE={ms:4000,keys:[[0,1],[.5,1.02,'inOut'],[1,1,'inOut']]}, HOLD={ms:3600,keys:[[0,1],[.27,1.0075,'layout'],[.61,.995,'layout'],[1,1,'layout']]};
const STILL={sleeping:1,dizzy:1};
// The idle catalogue: spec/motion.json's clips with an `every` window, at the spec's durations and windows, in this rig's units
// (sq: body squash; rot: body lean, rad; ox: R; head: head tilt, rad; gaze: 0..1 of a glance; look: pupils, of their reach;
// yaw: head turn; tuft*: core's ear, < 0 perks; flap*: wing swing, rad; lid*: 0..1 closed; btilt: bill turn, rad; open: bill
// parting). side: the action mirrors by a seeded coin, and a glance goes away from where she looks. L / R: viewer-left / right.
// This Koru has no feet, so weight-shift leans the body over each side (2° where the spec has 2.5°), and no pupil scale, so the
// double blink has no warm-up.
const BLINK2=[[0,0],[.15,1,'in'],[.22,1],[.4,0,'out'],[.55,1,'in'],[.62,1],[.85,0,'out'],[1,0]], WINK=[[0,0],[.3,1,'in'],[.58,1],[1,0,'out']];
const FLICK=[[0,0],[.22,.2,'out'],[1,0,'inOut']], PERK=[[0,0],[.25,-.4,'travel'],[.58,-.4],[1,0,'layout']], COUNTER=[[0,0],[.3,.16,'travel'],[.62,.16],[1,0,'layout']];
const SHIFT=a=>[[0,0],[.18,-a,'travel'],[.38,-a],[.5,0,'layout'],[.64,a,'travel'],[.84,a],[1,0,'layout']];
const ACTS={
  glance:{ms:1800,every:[7000,9000],side:1,label:'Olhadela',tracks:{gaze:[[0,0],[.035,1,'out'],[.8,1],[.92,0,'inOut']],head:[[0,0],[.08,D,'travel'],[.8,D],[1,0,'layout']]}},
  peer:{ms:1500,every:[16000,28000],side:1,label:'Espiar',tracks:{yaw:[[0,0],[.16,.075,'travel'],[.68,.075],[1,0,'layout']],look:[[0,0],[.1,.18,'micro'],[.7,.18],[1,0,'layout']],head:[[0,0],[.22,.6*D,'travel'],[1,0,'layout']]}},
  microTilt:{ms:900,every:[12000,20000],side:1,label:'Inclinar',tracks:{rot:[[0,0],[.2,1.5*D,'out'],[1,0,'inOut']]}},
  weightShift:{ms:2400,every:[26000,46000],side:1,label:'Trocar o peso',tracks:{rot:SHIFT(2*D),ox:SHIFT(.012),sq:[[0,1],[.2,.985,'out'],[.5,1,'layout'],[.66,.985,'out'],[1,1,'layout']]}},
  wingFlickL:{ms:700,every:[17000,27000],label:'Asa esq.',tracks:{flapL:FLICK}},
  wingFlickR:{ms:700,every:[10000,15000],label:'Asa dir.',tracks:{flapR:FLICK}},
  tuftTwitchL:{ms:900,every:[36000,60000],label:'Tufo esq.',tracks:{tuftL:PERK,tuftR:COUNTER}},
  tuftTwitchR:{ms:900,every:[28000,48000],label:'Tufo dir.',tracks:{tuftR:PERK,tuftL:COUNTER}},
  beakNibble:{ms:560,every:[15000,25000],label:'Mordiscar',tracks:{open:[[0,0],[.18,.2,'out'],[.34,0,'in'],[.54,.2,'out'],[.72,0,'in'],[1,0]]}},
  billAdjust:{ms:700,every:[36000,60000],label:'Ajeitar o bico',tracks:{btilt:[[0,0],[.2,3*D,'travel'],[.58,-1.5*D,'travel'],[1,0,'layout']],open:[[0,0],[.2,.22,'travel'],[.42,.08,'layout'],[.64,.16,'travel'],[1,0,'layout']]}},
  blinkDouble:{ms:420,every:[20000,40000],label:'Piscada dupla',tracks:{lidL:BLINK2,lidR:BLINK2}},
  blinkL:{ms:480,every:[42000,70000],label:'Piscar esq.',tracks:{lidL:WINK}},
  blinkR:{ms:480,every:[52000,85000],label:'Piscar dir.',tracks:{lidR:WINK}}};
// The spec's windows add up to 0.57 actions a second, more than one at a time can play: they queue back to back, and the glance,
// whose window is about one action and a rest long, locks into step with them. Here every window is CALM times as long (the mix
// and the windows' independence kept), each clock starts at a random point of its window as if she had been idling all along,
// and after each micro-action she rests; one that comes due while she plays or rests is let go and re-armed from its own window,
// so nothing bunches up. About one micro-action every 7 s.
const CALM=2, REST=[2000,4000], win=k=>ACTS[k].every.map(v=>v*CALM);
// Core tweens that move her: while one runs she is not idle.
const MOVES=['oy','ox','sx','sy','roll','tilt','hands','es','ear','blush'];

// A deterministic point inside a jitter window (koru-motion.js hashUnit/jitterDelay), seeded per bot; each name draws its own
// sequence, so no two windows lock into step.
function unit(seed,name,i){ let h=(Number(seed)||1)>>>0; const s=name+':'+i;
  for(let k=0;k<s.length;k++){ h^=s.charCodeAt(k); h=Math.imul(h,16777619)>>>0 }
  h^=h<<13; h^=h>>>17; h^=h<<5; return (h>>>0)/4294967296 }
const jitter=(L,w,name)=>{ const i=L.seq[name]=(L.seq[name]||0)+1; return w[0]+(w[1]-w[0])*unit(L.seed,name,i) };
const soft=(v,a)=>a*Math.tanh(v/a);
// A damped follower p = [x, y, vx, vy] chasing X, Y: it trails a steady motion by 2ζ/ω seconds, and at ζ = .75 overshoots a step
// by 2.8 % (ANIM-05 allows 4 %). Small fixed steps, so a long frame cannot make it ring.
function follow(p,X,Y,w,z,dt){ for(let i=Math.ceil(dt/.002),h=dt/i;i>0;i--){
  p[2]+=(w*w*(X-p[0])-2*z*w*p[2])*h; p[3]+=(w*w*(Y-p[1])-2*z*w*p[3])*h; p[0]+=p[2]*h; p[1]+=p[3]*h } }

// Reduced motion: the OS setting, followed live, or the page's toggle. Captures follow it only with ?life=1 (Chrome's
// --force-prefers-reduced-motion) or ?reduce=1, so stills never depend on the machine.
const mq=window.matchMedia?matchMedia('(prefers-reduced-motion: reduce)'):null;
let osReduce=!!(mq&&mq.matches), forced=params.get('reduce')==='1';
if(mq&&mq.addEventListener) mq.addEventListener('change',e=>{ osReduce=e.matches });
const reduced=()=>forced||osReduce&&(!Clock.virtual||CAPTURE);

const out=()=>({sq:1,rot:0,ox:0,head:0,gaze:0,gs:1,look:0,yaw:0,tuftL:0,tuftR:0,flapL:0,flapR:0,lidL:0,lidR:0,btilt:0,open:0});
function fresh(b){ const on=Clock.virtual?CAPTURE:params.get('life')!=='0';
  const L={on,seed:params.has('seed')?+params.get('seed'):Clock.virtual?1:Math.floor(Math.random()*4294967296),
    lv:on?1:0,bw:1,clock:0,idle:0,last:NOW(),dt:0,calm:false,wasCalm:false,act:null,queued:null,rest:0,seq:{},next:{},
    o:out(),bill:{tilt:0,open:0},f:null,lag:[0,0],trace:[],drops:0,over:0};
  for(const k in ACTS) L.next[k]=unit(L.seed,k,0)*win(k)[1];
  return L }
let pre=null;
function log(L,ev){ L.trace.push(ev+'@'+Math.round(L.clock)); if(!TRACE) return;
  if(!pre){ pre=document.createElement('pre'); pre.id='lifetrace'; document.body.appendChild(pre) } pre.textContent=L.trace.join(' ')+' drops:'+L.drops }
function start(b,L,name){ const A=ACTS[name], g=clamp(b.s.yaw/.62,-1,1)*.8;
  const side=!A.side?1:name==='glance'&&Math.abs(g)>.15?-Math.sign(g):unit(L.seed,name+'/side',L.seq[name]||0)<.5?-1:1;
  if(L.act) L.over++;                                     // never happens: one at a time
  L.act={name,at:L.clock,side,w:1,out:false}; log(L,'+'+name) }
// A micro-action now (the page's buttons, ?film=life-<name>): one playing lets go first.
function play(b,name){ const L=b.life; if(!L.lv) return; if(L.act){ L.act.out=true; L.queued=name } else start(b,L,name) }

// The bill's idle set, drawn while no other feature draws the beak (script order): the closed beak turned round its root and
// parted along a shallow V from the mouth corners (the upper mandible's hook), the lower half dropped over the dark mouth.
function bill(d,tilt,o){ const {x,R,br,beak,full}=d, yc=br*.12, v=br*.22, g=o*R*.1, w=br*.98, root=-br*.92;
  x.translate(0,root); x.rotate(tilt); x.translate(0,-root);
  if(g<.3){ beakFinish(x,beak,R,full,'closed'); return }
  const cut=(p,dy,side)=>{ p.moveTo(-R,yc+dy); p.lineTo(-w,yc+dy); p.lineTo(0,yc+v+dy); p.lineTo(w,yc+dy); p.lineTo(R,yc+dy); p.lineTo(R,side*R); p.lineTo(-R,side*R); p.closePath(); return p };
  const above=cut(new Path2D(),0,-1), below=cut(new Path2D(),0,1), mouth=new Path2D();
  mouth.moveTo(-w,yc); mouth.lineTo(0,yc+v); mouth.lineTo(w,yc); mouth.lineTo(w,yc+g); mouth.lineTo(0,yc+v+g); mouth.lineTo(-w,yc+g); mouth.closePath();
  x.fillStyle='#4A140C'; x.lineJoin='round'; x.strokeStyle='#4A140C'; x.lineWidth=g*.5; x.fill(mouth); x.stroke(mouth);
  x.save(); x.translate(0,g); x.clip(below); beakFinish(x,beak,R,full,'closed'); x.restore();
  x.save(); x.clip(above); beakFinish(x,beak,R,full,'closed'); x.restore() }

register({name:'life',
  init(b){ b.life=fresh(b) },
  // Reduced motion holds core's continuous loops (Bot.update's targets) at rest: the approval bounce, the sleeping breath, the search
  // scan and the dizzy sway. The state still shows by its colour, eyes and badge. Otherwise a peer turns the head a little.
  target(b,tg){ if(reduced()){ const c=b.cfg; if(c.bounce) tg.oy=c.dy||0; if(c.breathe){ tg.sy=c.sq||1; tg.sx=1 } if(c.scan||b.state==='dizzy') tg.yaw=0; return }
    const L=b.life; if(L.lv) tg.yaw+=L.o.yaw*smooth(L.lv) },
  update(b){ const L=b.life, n=NOW(); let gap=n-L.last; L.last=n;
    // The page stops drawing while hidden: the clocks skip that gap, so nothing missed is replayed (PERF-01).
    if(gap>250||gap<0) gap=0; L.dt=gap/1000;
    L.lv=reduced()||b.mini?0:clamp(L.lv+(L.on?gap:-gap)/200,0,1);   // the toggle eases her in and out in 200 ms, reduced motion at once
    if(!L.lv){ L.act=L.queued=null; L.o=out(); L.bill.tilt=L.bill.open=0; return }
    L.clock+=gap; L.bw=clamp(L.bw+(STILL[b.state]?-gap:gap)/300,0,1);
    // The idle clock runs only while she idles: a reaction suspends every window, and a rest follows it.
    if(L.calm) L.idle+=gap;
    if(L.calm&&!L.wasCalm) L.rest=Math.max(L.rest,L.idle+jitter(L,REST,'rest')); L.wasCalm=L.calm;
    let a=L.act;
    if(a){ if(!L.calm) a.out=true; if(a.out) a.w-=gap/150;   // interrupted, it lets go in 150 ms (TIME-03)
      if(a.w<=0||L.clock-a.at>=ACTS[a.name].ms){ log(L,'-'+a.name); L.act=a=null; L.rest=L.idle+jitter(L,REST,'rest') } }
    if(L.queued&&!a){ start(b,L,L.queued); L.queued=null; a=L.act }
    const busy=!!a||!L.calm||L.idle<L.rest;
    const due=Object.keys(ACTS).filter(k=>L.next[k]<=L.idle).sort((p,q)=>L.next[p]-L.next[q]||(p<q?-1:1));
    due.forEach((k,i)=>{ L.next[k]=L.idle+jitter(L,win(k),k); if(busy||i) L.drops++; else { start(b,L,k); a=L.act } });
    const o=L.o=out();
    if(a){ const A=ACTS[a.name], u=Math.min(1,(L.clock-a.at)/A.ms), w=smooth(clamp(a.w,0,1)); o.gs=a.side;
      for(const ch in A.tracks){ const v=track(A.tracks[ch],u); o[ch]=ch==='sq'?1+(v-1)*w:ch==='gaze'?v*w:v*w*a.side } } },
  modify(b,m){ const L=b.life;
    // Idle for the next update: nothing on her eyes or wing, no tween moving her, and no other feature moving her (life runs
    // after them all, so m holds their whole frame).
    L.calm=b.state==='idle'&&!b.eyeOv&&!b.handOwner&&!MOVES.some(p=>b.tweening(p))&&!m.eye&&Math.abs(m.ox)+Math.abs(m.oy)+Math.abs(m.rot)
      +Math.abs(m.headY)+Math.abs(m.headTilt)+Math.abs(m.lookX)+Math.abs(m.lookY)+Math.abs(m.flap)+Math.abs(m.sx-1)+Math.abs(m.sy-1)+Math.abs(m.es-1)<1e-3;
    if(!L.lv){ L.f=null; L.lag=[0,0]; return }
    const s=b.s, o=L.o, k=smooth(L.lv);
    // The carriers multiply, with the volume compensation of core's own breath.
    const q=((track(BREATHE.keys,L.clock%BREATHE.ms/BREATHE.ms)*track(HOLD.keys,L.clock%HOLD.ms/HOLD.ms)-1)*L.bw+o.sq-1)*k;
    m.sy*=1+q; m.sx*=1-q*.57; m.rot+=o.rot*k; m.ox+=o.ox*k;
    // Follow-through. Where the body carries the head (R from the canvas centre): its offset, squash and lean, the head's own
    // drop (s.hy, m.headY) only as the lever. The head's follower trails it by 40 ms, critically damped; the vertical lag lowers
    // or lifts the head, the sideways one tilts it on the neck.
    const syE=s.sy*m.sy, hy=s.hy+m.headY, P=[s.ox+m.ox+Math.sin(m.rot)*(G.ryBot-syE*(hy-.15)),G.cy+s.oy+m.oy+(G.ryBot+.15-hy)*(1-syE)];
    if(!L.f) L.f={h:[P[0],P[1],0,0],t:null};
    const F=L.f; follow(F.h,P[0],P[1],50,1,L.dt);
    const lx=soft(F.h[0]-P[0],.05)*k, ly=soft(F.h[1]-P[1],.03)*k; L.lag=[lx,ly];
    m.headY+=ly/syE; m.headTilt+=lx+o.head*k;
    // The tufts' tips trail the top of the head by 40 ms more, a little under-damped; their lag bends them as core's ear does.
    const T=[P[0]+Math.sin(s.tilt+m.headTilt),P[1]+ly+hy];
    if(!F.t) F.t=[T[0],T[1],0,0]; follow(F.t,T[0],T[1],37.5,.75,L.dt);
    const dx=F.t[0]-T[0], dy=F.t[1]-T[1];
    m.tuftL+=(soft(2.5*(dy-dx),.3)+o.tuftL)*k; m.tuftR+=(soft(2.5*(dy+dx),.3)+o.tuftR)*k;
    m.flapL+=o.flapL*k; m.flapR+=o.flapR*k; m.lidL=Math.max(m.lidL,o.lidL*k); m.lidR=Math.max(m.lidR,o.lidR*k);
    // Pupils, as a fraction of their reach (Bot.eye): a glance goes to 0.6 of it on one side, a peer adds a little.
    const g=clamp(s.yaw/.62,-1,1)*.8+m.lookX;
    m.lookX+=((o.gs*.6-g)*o.gaze+(o.look?clamp(g+o.look,-.95,.95)-g:0))*k;
    L.bill.tilt=o.btilt*k; L.bill.open=o.open*k },
  beak(b,d){ const B=b.life.bill; if(d.mini||Math.abs(B.tilt)<1e-3&&B.open<.004) return false; bill(d,B.tilt,B.open); return true },
  // With ?life=1, ?film=life films her idling and ?film=life-<name> one micro-action.
  actions:CAPTURE?Object.assign({life(){}},...Object.keys(ACTS).map(k=>({['life-'+k]:b=>play(b,k)}))):{},
  soak(b,bad){ const L=b.life; if(!L.lv) return; if(L.over) bad.push('life:overlap'+L.over);
    if(!(Math.abs(L.lag[0])<.01&&Math.abs(L.lag[1])<.01)) bad.push('life:lag'+L.lag.map(v=>v.toFixed(3))) },
  controls(ui,{main}){ ui.group('Vida'); const t=ui.toggle('Vida','#5EEAD4',v=>{ main.life.on=v }); if(main.life.on) t.classList.add('on');
    ui.toggle('Movimento reduzido','#94A3B8',v=>{ forced=v });
    for(const k in ACTS) ui.button(ACTS[k].label,'#5B6472',()=>play(main,k)) }
});
})();
