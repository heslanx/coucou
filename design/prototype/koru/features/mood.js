// Mood: Koru shows how the Mac feels (busy, hot, full, tired or asleep) in levels 0..1 that mix.
// Busy hops and sweats, hot flushes with heat waves, full puffs up, tired has heavy lids and the odd yawn, asleep sleeps.
// Ports MochiMood.swift:52-303 (updateMood, updateStress, throwDrop, drawMoodTint, drawMoodExtras), BotEngine.swift:1155
// (the blush at 0.85 × hot), MochiMood.swift:111-118 (the z of a sleeping Mochi) and 1543-1550 (pupils).
(()=>{
const {register,E,G,NOW,rand,clamp,drop,floorPool,bodyW,eyeShapes,sheet,stamp}=Koru;
const SHOWS={idle:1,working:1,thinking:1,searching:1,finished:1}, CALM={idle:1,finished:1};   // MochiMood.swift:52-57, 73
const rnd=(a,b)=>a+(b-a)*rand();
// Mochi's body is 1.14 × 0.88 R; drops are thrown in his units, stretched here to Koru's sides and floor.
const KX=G.rx/1.14, KY=G.ryBot/.88, GRAV=6*KY, FLOOR=1.05*KY;   // gravity R/s² (MochiMood.swift:60)
// Swift hops ±0.28 R, never twice within 0.12 R. Koru's wings reach 1.41 R where Mochi's side ends at 1.14 R, so that hop would
// carry a wing out of the targets' framing (1.667 R to the edge, 1.55 R with the landing squash) and leave stills well off-centre:
// she hops half as far, with the same ratio between the two.
const HOP=.14, HOP_MIN=.06;
const DOUBLE=[[.06,60,E.inOut],[1,90,E.out],[.06,60,E.inOut],[1,120,E.out]];   // MochiMood.swift:206-211
const fresh=()=>({target:{busy:0,hot:0,full:0,tired:0,asleep:false},busy:0,hot:0,full:0,tired:0,sleep:false,
  drops:[],nextDrop:0,hop:{from:0,to:0,start:0,dur:.2,height:0,rest:0,landed:true},look:{x:0,y:0},nextLook:0,nextYawn:0,
  shift:0,lift:0,lean:0,tx:0,ty:0,t:0,mx:1,my:1,side:1});

// The processor at full load (MochiMood.swift:131-203): quick short hops from side to side, leaning into each one,
// squashing on landing; the eyes dart (target) and tremble.
function stress(b,M,n,dt){ const lv=M.busy;
  if(!(lv>.02||Math.abs(M.hop.to)>.005||!M.hop.landed)){ M.shift=M.lift=M.lean=M.tx=M.ty=0; return }
  let h=M.hop;
  if((h.dur>0?Math.min(1,(n-h.start)/h.dur):1)>=1){
    if(!h.landed){ h.landed=true; b.anim('sy',[[.86,60,E.out],[1,140,E.out]]); b.anim('sx',[[1.1,60,E.out],[1,140,E.out]]) }
    if(n>h.start+h.dur+h.rest){ let to=0; if(lv>.3){ do to=rnd(-HOP,HOP); while(Math.abs(to-h.to)<HOP_MIN) }   // never twice the same spot
      h=M.hop={from:h.to,to,start:n,dur:rnd(.22,.4),height:lv>.3?rnd(.07,.18):.05,rest:rnd(.1,.55),landed:false} } }
  const q=h.dur>0?Math.min(1,(n-h.start)/h.dur):1, eased=q<.5?2*q*q:1-Math.pow(-2*q+2,2)/2, amount=Math.min(1,lv*1.4);
  // A tween of ox or oy (a greet's hop, a squash) owns the offset, as Swift's locks do; the hop fades out and back in over
  // about 120 ms rather than vanishing for a frame.
  const fade=1-Math.exp(-dt/.04); M.mx+=((b.tweening('ox')?0:1)-M.mx)*fade; M.my+=((b.tweening('oy')?0:1)-M.my)*fade;
  M.shift=(h.from+(h.to-h.from)*eased)*amount*M.mx;
  M.lift=-Math.sin(Math.PI*q)*h.height*(h.landed?0:1)*amount*M.my;
  // Mochi's tilt turns his whole body; Koru's tilt only turns the head, so the lean goes to the body (m.rot).
  M.lean+=((h.landed?0:(h.to>=h.from?1:-1)*.12*Math.sin(Math.PI*q)*amount)-M.lean)*(1-Math.pow(.0008,dt));
  if(lv>.3&&n>M.nextLook){ const back=rand()<.3; M.look={x:back?-M.look.x*.8:rnd(-.85,.85),y:rnd(-.3,.18)}; M.nextLook=n+rnd(.16,.45) }
  // Tremble: Mochi's whole eye shakes by 0.012 × 0.01 R; Koru's discs sit in the rings, so her pupils shake (reach 0.214 R).
  const tr=Math.min(1,lv*1.3); M.tx=tr>.01?Math.sin(n*63)*.012*tr/.214:0; M.ty=tr>.01?-Math.cos(n*51)*.01*tr/.214:0 }

// A drop of sweat from one side (MochiMood.swift:213-229), in R from Koru's resting centre. The keyframe's drops are
// smaller, plumper and more opaque than Mochi's long, faint ones. They leave from just outside her outline, below her tufts
// (Swift's 0.92-1.05 of Mochi's half-width, at its heights, would start them behind them), and as her wings leave 0.25 R to
// the edge of the targets' framing, they fly out at 0.45 × Swift's speed, in small arcs that land inside the canvas.
// Swift picks a random side; Koru alternates,
// and a second drop of a burst leaves a beat later, so they never bunch up on one side. Size, stretch and tint come in steps,
// one cached sprite each.
const step=(v,k)=>Math.round(v*k)/k;
function throwDrop(b,M,n,later=0){ const sd=M.side=-M.side, small=rand()<.3, ox=b.s.ox+M.shift, oy=b.s.oy+M.lift, y=rnd(-.38,-.12)*KY;
  M.drops.push({x:sd*(bodyW(y)+rnd(.02,.08))+ox,y:y+oy,vx:sd*rnd(.5,1)*KX*.45,vy:-rnd(1.5,2.4)*KY,born:n+later,
    size:step((small?rnd(.09,.13):rnd(.15,.26))*.62,100),stretch:step(small?rnd(.75,.95):rnd(1,1.25),10),tint:step(rand(),3),alpha:rnd(.88,1),wobble:rnd(0,Math.PI*2)});
  if(M.drops.length>28) M.drops.shift() }
// One drop, the round end down, in device px: a glowing blue body, a soft highlight and a sharp glint, as in the keyframe.
const sprite=(R,{size,stretch:L,tint:tn})=>{ const s=R*size, m=R*.07;
  return sheet(`moodDrop${R}:${size}:${L}:${tn}`,[-s*1.2-m,-s*1.1*L-m,s*1.2+m,s*.75+m],x=>{
    x.beginPath(); x.moveTo(0,-s*1.1*L); x.quadraticCurveTo(s*1.15,s*.25,0,s*.75); x.quadraticCurveTo(-s*1.15,s*.25,0,-s*1.1*L);
    const g=x.createLinearGradient(0,-s*L,0,s*.75); g.addColorStop(0,`rgb(${(.72-.2*tn)*255},${(.88-.12*tn)*255},255)`); g.addColorStop(1,`rgb(${(.36-.12*tn)*255},${(.68-.14*tn)*255},250)`);
    x.shadowColor='rgba(110,185,255,.55)'; x.shadowBlur=R*.05; x.fillStyle=g; x.fill(); x.shadowColor='transparent';
    x.fillStyle=`rgba(255,255,255,${.4+.35*tn})`; x.beginPath(); x.ellipse(-s*.28,s*.08*L,s*.12,s*.17*L,0,0,Math.PI*2); x.fill();
    x.fillStyle='rgba(255,255,255,.9)'; x.beginPath(); x.arc(-s*.26,-s*.04*L,s*.08,0,Math.PI*2); x.fill() }) };
// The drops in device px (MochiMood.swift:251-280), fading out before they reach the canvas edges; the wobble squeezes the sprite.
function sweat(x,M,d){ const R=d.R, n=NOW()/1000, bx=d.W/2, by=d.H/2+G.cy*R, edge=R*.12;
  for(const p of M.drops){ const a=n-p.born; if(a<0) continue;
    const px=bx+(p.x+p.vx*a)*R, py=p.y+p.vy*a+GRAV*a*a/2, vy=p.vy+GRAV*a, Y=by+py*R, wob=1+Math.sin(a*22+p.wobble)*.08, m=R*p.size*1.1;
    const al=p.alpha*Math.min(1,a/.06)*clamp((FLOOR-py)/(.25*KY),0,1)*clamp((Math.min(px,d.W-px)-m)/edge,0,1)*clamp((Y-m)/edge,0,1); if(al<=.005) continue;
    x.globalAlpha=al; x.setTransform(1,0,0,1,px,Y); x.rotate(Math.atan2(vy,p.vx)-Math.PI/2); x.scale(1/wob,wob);   // the round end leads, the tip trails
    stamp(x,sprite(R,p)) } }

// The warm flush rising from the base (MochiMood.swift:232-243). Swift's red at 0.42 tints Mochi's pale body but turns grey
// over Koru's teal, so the red is deep at the base and gone by the top of the belly (a short blend leaves no muddy band),
// with a screen pass along the base that makes it glow like heat.
function flush(d,path,a){ const x=d.x, R=d.R, g=x.createLinearGradient(0,d.ryB,0,R*.36);
  g.addColorStop(0,`rgba(236,58,30,${.95*a})`); g.addColorStop(.35,`rgba(240,66,36,${.85*a})`); g.addColorStop(.7,`rgba(246,84,56,${.34*a})`); g.addColorStop(1,'rgba(246,84,56,0)'); x.fillStyle=g; x.fill(path);
  const w=x.createLinearGradient(0,d.ryB,0,d.ryB-R*.32); w.addColorStop(0,`rgba(255,130,50,${.6*a})`); w.addColorStop(1,'rgba(255,110,50,0)');
  x.globalCompositeOperation='screen'; x.fillStyle=w; x.fill(path); x.globalCompositeOperation='source-over' }

// Heat waves (MochiMood.swift:282-301): three glowing wisps rising out of the top of her head between the tufts. Each fades in
// at the bottom and out at the top, and stops 0.14 R short of the canvas top, so a hop never cuts it. As the heat rises they
// grow longer rather than only brighter: a dim orange line on the dark background reads as brown.
function heat(x,d,al){ const R=d.R, t=d.t, base=d.cy-d.ryT*d.sy-R*.03, len=R*.46*(.4+.6*al); x.lineCap=x.lineJoin='round'; x.globalCompositeOperation='lighter';
  for(let i=0;i<3;i++){ const x0=d.cx+(i-1)*R*.24, ph=t*4+i*1.7, rise=(t*.6+i*.33)%1, bot=base-R*.08*rise, top=Math.max(bot-len,R*.14), a=Math.min(1,al*4)*(.55+.45*al)*(.75+.25*Math.sin(rise*Math.PI));
    if(bot-top<R*.1) continue;
    const g=x.createLinearGradient(0,bot,0,top); g.addColorStop(0,'rgba(255,90,30,0)'); g.addColorStop(.3,`rgba(255,112,44,${a})`); g.addColorStop(.75,`rgba(255,92,34,${.75*a})`); g.addColorStop(1,'rgba(255,80,30,0)');
    x.beginPath(); for(let k=0;k<=24;k++){ const f=k/24; x.lineTo(x0+Math.sin(ph-f*5)*R*.045*(.6+.4*f),bot-(bot-top)*f) }   // the sway travels up
    x.strokeStyle=g; for(const [w,al2] of [[.17,.22],[.09,.45],[.042,1]]){ x.globalAlpha=al2; x.lineWidth=R*w; x.stroke() } x.globalAlpha=1 } }   // glow in widening passes: no live blur

// Fear narrows the pupils: Mochi's eye goes 0.8 × 0.9, Koru's round pupil takes the mean.
eyeShapes.tense=(b,e)=>e.pupil(e.pr*(b.cfg.pupil||1)*(1-.15*Math.min(1,b.mood.busy*1.3)));
// Heavy lids for a low battery (Swift's tired eye): a soft lid sagging over the top half, a thin crease, a shade under it.
eyeShapes.drowsy=(b,e)=>{ const {x,R,dr,ink}=e; e.pupil(e.pr); const y0=-dr*.04, lid=new Path2D();
  lid.moveTo(-dr,-dr); lid.lineTo(dr,-dr); lid.lineTo(dr,y0-dr*.1); lid.quadraticCurveTo(0,y0+dr*.16,-dr,y0-dr*.1); lid.closePath();
  x.save(); x.shadowColor='rgba(120,50,0,.35)'; x.shadowBlur=R*.04; x.shadowOffsetY=R*.015;
  const g=x.createLinearGradient(0,-dr,0,y0); g.addColorStop(0,'#4EBBC3'); g.addColorStop(1,'#36A6B2'); x.fillStyle=g; x.fill(lid); x.restore();
  x.strokeStyle=ink; x.lineWidth=R*.022; x.lineCap='round'; x.beginPath(); x.moveTo(dr,y0-dr*.1); x.quadraticCurveTo(0,y0+dr*.16,-dr,y0-dr*.1); x.stroke() };

const set=(b,o)=>{ const T=b.mood.target; for(const k in o) T[k]=o[k] };

register({name:'mood',
  init(b){ b.mood=fresh() },
  // The look: straight ahead and a little down asleep (BotEngine.swift:933), lowered when tired, and under load darting from
  // spot to spot, snapping there faster than a calm look (Swift adds 0.2 × the gap per frame; here through the target, so core's
  // step lands where Swift's two would). A warm Mac blushes her as Swift does (max(blush, 0.85 × hot)).
  target(b,tg,t){ const M=b.mood, s=b.s, dt=clamp(t-M.t,0,.05); M.t=t;
    if(M.sleep){ tg.yaw=0; tg.pitch=-.14 }
    else { if(M.tired>.5) tg.pitch-=.06*M.tired;
      if(!b.mini&&M.busy>.3&&dt>0){ const kLook=1-Math.pow(.0025,dt), k=(1-(1-kLook)*Math.pow(1-.2*Math.min(1,M.busy*1.4),dt*60))/kLook;
        tg.yaw=s.yaw+(M.look.x-s.yaw)*k; tg.pitch=s.pitch+(M.look.y-s.pitch)*k } }
    if(M.hot>.001) tg.blush=.85*M.hot },
  // Nervous blinks under load, sometimes twice (MochiMood.swift:185-195); none while asleep.
  blink(b){ const M=b.mood; if(M.sleep) return 2400; if(b.mini||M.busy<=.3) return null;
    if(!b.tweening('open')){ if(rand()<.3) b.anim('open',DOUBLE); else b.blink() }
    return rnd(1000,2400) },
  // Levels ease towards the target, mood shows only when Koru is not asking for anything (MochiMood.swift:70-127).
  update(b,dt){ const M=b.mood, T=M.target, n=NOW()/1000, k=1-Math.pow(.25,dt), shows=SHOWS[b.state], calm=CALM[b.state];
    M.busy+=((shows?T.busy:0)-M.busy)*k; M.hot+=((shows?T.hot:0)-M.hot)*k; M.full+=((shows?T.full:0)-M.full)*k;
    M.tired+=((calm?T.tired:0)-M.tired)*k; M.sleep=!!(calm&&T.asleep);
    if(b.mini) return;                                     // minis show the flush, the blush and the lids only
    stress(b,M,n,dt);
    // Sweat: bursts at full load, now and then when only warm.
    if(n>M.nextDrop){
      if(M.busy>.4){ throwDrop(b,M,n); if(rand()<.35) throwDrop(b,M,n,rnd(.08,.14)); M.nextDrop=n+rnd(.18,.4) }
      else if(M.hot>.6){ throwDrop(b,M,n); M.nextDrop=n+rnd(.6,1.1) }
      else M.nextDrop=n+.3 }
    M.drops=M.drops.filter(p=>{ const a=n-p.born; return a<=1.6&&p.y+p.vy*a+GRAV*a*a/2<=FLOOR });
    // A z every 1.6 s from above the right of her head, drifting up and right slower than Mochi's, so it fades inside the canvas.
    if(M.sleep){ if(n>M.nextYawn){ b.zz(1); M.nextYawn=n+1.6 } }
    else if(M.tired>.5&&n>M.nextYawn){ if(M.nextYawn>0) b.emote('yawn'); M.nextYawn=n+24+rnd(0,12) } },
  modify(b,m,t){ const M=b.mood;
    if(!b.mini){
      if(M.full>.02){ m.sx*=1+.07*M.full; m.sy*=1-.035*M.full }
      // Faster breathing under load, as MochiMood.swift:7 says (the Swift code itself only hops).
      if(M.busy>.01){ const br=Math.sin(t*5.4)*M.busy; m.sy*=1+br*.025; m.sx*=1-br*.014 }
      m.ox+=M.shift; m.oy+=M.lift; m.rot+=M.lean; m.lookX+=M.tx; m.lookY+=M.ty }
    if(!m.eye) m.eye=M.sleep?'closed':M.tired>.5?'drowsy':!b.mini&&M.busy>.01&&b.cfg.eye==='pill'?'tense':null },
  layers:{
    // The heat glows out of her base, as the state light does in core; the sweat leaves from behind her sides, so it never
    // crosses her face or tufts.
    behind(b,d){ const M=b.mood; if(d.mini) return; const x=d.x, R=d.R, body=d.body;
      if(M.hot>.01){ x.globalAlpha=M.hot; stamp(x,sheet('moodHeat'+R,[-d.rx*1.5,R*.3,d.rx*1.5,R*1.6],g=>drop(g,body,'rgba(255,84,40,.8)',R*.2,0,R*.06),R*.6)); x.globalAlpha=1 }   // below 0.3 R only
      if(M.drops.length) sweat(x,M,d) },
    body(b,d){ if(b.mood.hot>.01) flush(d,d.body,b.mood.hot) },
    // The heat deepens core's blush (the same spot on each ring, clipped to the face) from pink to red.
    face(b,d){ const a=b.mood.hot; if(a<=.01) return; const x=d.x, R=d.R; x.clip(d.face);
      for(const e of d.eyes){ const bx=e.x+e.sd*R*.22, by=e.y+R*.43, g=x.createRadialGradient(bx,by,0,bx,by,R*.2);
        g.addColorStop(0,`rgba(255,64,64,${.55*a})`); g.addColorStop(.55,`rgba(255,64,64,${.25*a})`); g.addColorStop(1,'rgba(255,64,64,0)'); x.fillStyle=g; x.fillRect(bx-R*.2,by-R*.2,R*.4,R*.4) } },
    front(b,d){ const M=b.mood; if(M.hot>.5&&!d.mini) heat(d.x,d,(M.hot-.5)*2) },
    // A warm glow on the floor under a hot Koru.
    floor(b,d){ const a=b.mood.hot; if(a<=.01||d.mini) return;
      floorPool(d.x,d.cx,d.cy+d.ryB*d.sy,d.rx*1.2,.14,[[0,`rgba(255,96,40,${.55*a})`],[.5,`rgba(255,80,40,${.2*a})`],[1,'rgba(255,80,40,0)']]) } },
  // ?mood=busy:1,hot:.6,full:1,tired:1,asleep:1 sets the levels at once, so a still shows them in full; with ?film=moodon they
  // wait for the action, so the film starts from calm.
  capture(b,params){ const v=params.get('mood'); if(!v) return; const M=b.mood, later=params.get('film')==='moodon'; if(later) M.later={};
    for(const kv of v.split(',')){ const [k,a]=kv.split(':'); if(!(k in M.target)) continue; const lv=k==='asleep'?a!=='0':+(a??1);
      if(later) M.later[k]=lv; else { M.target[k]=lv; if(k!=='asleep') M[k]=lv } } },
  // With a calm target, every level, offset and drop is back at rest.
  soak(b,bad){ const M=b.mood, T=M.target; if(T.busy||T.hot||T.full||T.tired||T.asleep) return;
    const left=['busy','hot','full','tired','shift','lift','lean','tx','ty'].filter(k=>Math.abs(M[k])>.01);
    if(left.length||M.drops.length||!M.hop.landed) bad.push('mood:'+left.concat(M.drops.length?['drops']:[],M.hop.landed?[]:['hop'])) },
  actions:{
    moodon(b){ const {target,later}=b.mood; b.mood=Object.assign(fresh(),{target:Object.assign(target,later)}) },   // the mood sets in from calm, with no drops left
    moodoff(b){ set(b,{busy:0,hot:0,full:0,tired:0,asleep:false}) } },  // and fades back to rest
  controls(ui,{main,mini,mini2}){ const all=[main,mini,mini2], on=(k,v)=>{ for(const b of all) set(b,{[k]:v}) }; ui.group('Humor do Mac');
    ui.slider('CPU',0,1,.05,0,v=>on('busy',v)); ui.slider('Calor',0,1,.05,0,v=>on('hot',v));
    ui.slider('Memória',0,1,.05,0,v=>on('full',v)); ui.slider('Bateria fraca',0,1,.05,0,v=>on('tired',v));
    ui.toggle('Bateria acabando','#94A3B8',v=>on('asleep',v)) } });
})();
