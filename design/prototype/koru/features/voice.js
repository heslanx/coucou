// Voice mode: Koru listens, thinks and speaks, the attentive pose of BotEngine.swift enterListening and the voice sub-states.
// Ports BotEngine.swift 634-662 (enterListening), 664-725 (voice compact enter/exit and the sub-state transitions),
// 727-760 (exitListening), 855-864 (the listening emote), 954-998 (waiting sway, mic level, sub-state look and bounce),
// 1053 (slower blinks while listening), BotCanvasView.swift:93-101 (mic smoothing) and IslandTypes.swift:41 (BotVoiceSubState).
// Live: Ouvir opens the attentive listening pose (a follow-up turn, or a mini, takes the calm compact pose);
// Pensar and Falar take the compact pose, after a nod when Koru was listening; Parar ends the session.
(()=>{
const {register,E,NOW,rand,Clock,EMOTES,eyeShapes,K,rgba,beakFinish}=Koru;
const OWN=['lTilt','vTilt','vEs','talk'];
// Speech for the mic slider: syllables at 4.2 Hz inside words at 0.84 Hz, so the eyes pulse as with a real voice.
const speech=t=>.25+.75*(.5+.5*Math.sin(t*26.4))*(.5+.5*Math.sin(t*5.3+1.3));
// Speaking: Swift pulls oy 25 % a frame toward a 3.5 Hz sine and the rest pull brings it back, so the bob lags the sine by
// LAG; the beak opens on the same clock, widest as the body rises.
const HZ=3.5, LAG=Math.atan2(2*Math.PI*HZ,-60*Math.log(.75)-Math.log(.0008)), phase=()=>NOW()/1000*2*Math.PI*HZ;

EMOTES.listening={label:'Ouvindo',eye:'wide',c:'#22D3EE',
  run(b,d){ b.anim('tilt',[[-.07,180,E.out],[-.07,d-400,E.lin],[0,240,E.inOut]]); b.anim('es',[[1.12,200,E.out],[1,500,E.inOut]]) }};

// The wide eyes of the session. Swift shrinks Mochi's eye to 0.86 (thinking) and 0.72 (speaking); Koru's eye is the disc,
// so the shrink is drawn as the lower lid rising over the pupil, the "squint" and "joy squint" Swift's comments name.
eyeShapes.voice=(b,{x,dr,px,py,pr,pupil})=>{ pupil(pr*1.08); const q=Math.min(1,Math.max(0,-b.s.vEs)/.28); if(q<.01) return;
  // At full squint the lid crowns just over the pupil's centre, narrower than the pupil, so what shows of it is a crescent.
  const top=dr*1.02+(py-pr*.1-dr*1.02)*q, r=dr*1.1+(pr*1.35-dr*1.1)*q, lid=new Path2D(); lid.arc(px*q,top+r,r,0,Math.PI*2);
  const g=x.createLinearGradient(0,-dr,0,dr); g.addColorStop(0,rgba(K.eyeIn,1)); g.addColorStop(1,rgba(K.eyeEdge,1));
  x.fillStyle=g; x.fill(lid);
  // The crease shows the lid below the pupil only in the speaking squint: under the half-raised lid of thinking it read as a frown.
  const k=Math.min(1,Math.max(0,(q-.6)/.3)); if(k<.01) return;
  x.strokeStyle=`rgba(196,96,24,${.2*k})`; x.lineWidth=dr*.03; x.lineCap='round'; x.beginPath(); x.arc(px*q,top+r,r,Math.PI*1.27,Math.PI*1.73); x.stroke() };

function enterListening(b){ const V=b.voice; if(V.listen) return; V.listen=true; V.words=false; b.sound('blip');   // FlowDictation.swift:313
  b.interruptGreet(); b.clearOverride();                   // the wide eyes replace a running emote, as Swift's permanent emote does
  b.anim('oy',[[-.2,130,E.out],[0,280,E.back]]); b.squash();
  V.wing=b.raise('voice',280,'cup');                       // the near wing rises to the head (listenHandRaise, 280 ms)
  b.anim('lTilt',[[-.1*b.handSide,200,E.out]]);            // the head leans its raised-wing side up, as Swift's -0.10 with the right hand
  b.blinkIn(2500+rand()*1000) }
// hadCommand: a nod and happy eyes for 1 s; without one, a shrug.
function exitListening(b,had){ const V=b.voice; if(!V.listen) return; V.listen=false; V.words=false;
  b.anim('lTilt',[[0,250,E.inOut]]); b.lower('voice',200); V.wing=false; V.fade=true;   // the waves die down with the wing
  if(had){ b.anim('oy',[[-.08,110,E.out],[0,200,E.back]]); b.emote('happy',1000) }
  else { b.anim('sy',[[.93,180,E.out],[1,350,E.back]]) }
  b.blinkIn(1500+rand()*2000) }
// One calm pose for the whole exchange: wide eyes eased in and a slight tilt, no jump, no wing.
function enterCompact(b){ const V=b.voice; if(V.on) return; V.on=true; V.sub='none'; b.clearOverride();
  b.anim('vEs',[[.06,260,E.inOut]]); b.anim('vTilt',[[-.06,260,E.inOut]]) }
function exitCompact(b){ const V=b.voice; if(!V.on) return; V.on=false; V.sub='none'; b.cancel('voiceBlink');
  b.anim('vEs',[[0,260,E.inOut]]); b.anim('vTilt',[[0,260,E.inOut]]); b.anim('talk',[[0,200,E.inOut]]) }
// The one-shot of each sub-state (BotEngine.swift _applyVoiceSubStateTransition).
function sub(b,n){ const V=b.voice; if(!V.on||V.sub===n) return; V.sub=n;
  if(n==='listening'){ b.anim('vEs',[[.06,220,E.inOut]]); b.blinkIn(2000+rand()*800) }
  if(n==='thinking'){ b.anim('vEs',[[-.14,280,E.inOut]]); b.blinkIn(3500+rand()*1000) }
  if(n==='speaking'){ b.anim('vEs',[[-.28,200,E.inOut]]); b.after('voiceBlink',120,()=>b.blink()) }   // a blink right away marks it
  b.anim('talk',[[n==='speaking'?1:0,n==='speaking'?160:200,n==='speaking'?E.out:E.inOut]]) }

const listen=b=>{ if(b.mini||b.voice.on){ enterCompact(b); sub(b,'listening') } else enterListening(b) };
const begin=(b,n)=>{ enterCompact(b); exitListening(b,true); sub(b,n) };   // the nod's happy eyes come after the compact pose clears emotes
const stop=b=>{ exitListening(b,false); exitCompact(b) };

// The open beak while speaking, as in the keyframe: core's beak with its lower half dropped by the gap into a cup (the lower
// beak), a dark mouth and a tongue inside it, and the closed beak's upper part, cut along a V, over it as the upper beak with
// its hook. The opening comes in 16 steps, so the finish of each one is drawn once (Koru.beakFinish with a key).
const vCut=(br,dy)=>{ const p=new Path2D(), w=br*1.3; p.moveTo(-w,dy-br*.2); p.quadraticCurveTo(-br*.35,dy+br*.55,0,dy+br*.8); p.quadraticCurveTo(br*.35,dy+br*.55,w,dy-br*.2); return p };
const side=(br,dy,below)=>{ const p=vCut(br,dy), w=br*1.3, e=below?br*4:-br*2; p.lineTo(w,e); p.lineTo(-w,e); p.closePath(); return p };
// The lower half of the closed beak dropped by g, its tip rounding off into a cup as it opens, added to path p.
function cup(p,br,tip,g,o){ const kx=br*(.3+.55*o), ky=tip*(.86+.14*o)+g;
  p.moveTo(br*.98,br*.12); p.bezierCurveTo(br*.88,br*.6+g,kx,ky,0,tip+g); p.bezierCurveTo(-kx,ky,-br*.88,br*.6+g,-br*.98,br*.12); p.closePath(); return p }
function openBeak(b,d,o){ const {x,R,br,tip,beak,full}=d, g=o*R*.1, deep=g+o*br*.35, yc=br*.12, rim=R*.025;
  const sil=cup(new Path2D(beak),br,tip,g,o); beakFinish(x,sil,R,full,'voice'+o);
  // The mouth stays a rim's width inside the beak, so the lower beak's edge shows around it.
  const inside=new Path2D(); inside.addPath(sil,new DOMMatrix().translate(0,yc).scale(1-rim/(br*.98),1-rim/(tip+g-yc)).translate(0,-yc));
  x.save(); x.clip(inside); x.clip(side(br,0,true)); x.clip(side(br,deep,false));
  const mg=x.createLinearGradient(0,br*.3,0,br*.8+deep); mg.addColorStop(0,'#6E1A10'); mg.addColorStop(1,'#B8392A'); x.fillStyle=mg; x.fill(sil);
  const tg=x.createRadialGradient(0,br*.8+deep*.9,0,0,br*.8+deep*.9,br*.5); tg.addColorStop(0,'#EC7A70'); tg.addColorStop(1,'#B9443B');
  x.fillStyle=tg; x.beginPath(); x.ellipse(0,br*.8+deep,br*.5,deep*.42,0,0,Math.PI*2); x.fill(); x.restore();   // tongue
  x.save(); x.clip(side(br,0,false)); beakFinish(x,beak,R,full,'closed'); x.restore();
  x.save(); x.clip(beak); x.strokeStyle=`rgba(196,96,24,${Math.min(1,o*3)})`; x.lineWidth=R*.012; x.stroke(vCut(br,0)); x.restore() }   // the hook's lip

// Sound coming in: two soft waves of light beside the cupped wing's upper flank, as loud as the mic. They add light (no dark
// edge): a wide faint glow under a light teal stroke.
function soundArcs(b,d){ const a=Math.min(1,b.voice.lvl*2.8)*Math.min(1,b.s.hands); if(a<.02){ if(!b.voice.wing) b.voice.fade=false; return } const {x,R,cx,cy,sx,sy}=d, sd=b.handSide;
  x.translate(cx+sd*R*1.0*sx,cy-R*.45*sy); x.scale(-sd,1); x.lineCap='round'; x.globalCompositeOperation='lighter';
  for(let i=0;i<2;i++){ const r=R*(.3+.16*i), al=a*(1-.25*i);
    for(const [c,w,k,bl] of [['rgb(40,200,225)',.09,.22,R*.05],['rgb(140,228,240)',.036,.7,0]]){
      x.globalAlpha=al*k; x.strokeStyle=c; x.lineWidth=R*w; x.shadowColor=bl?c:'transparent'; x.shadowBlur=bl; x.beginPath(); x.arc(0,0,r,Math.PI*.92,Math.PI*1.36); x.stroke() } } }

register({name:'voice',
  init(b){ b.voice={listen:false,on:false,sub:'none',mic:0,lvl:0,pulse:0,bob:0,words:false,wing:false}; for(const v of OWN) b.set(v,0) },
  // Swift's per-frame targets: a waiting sway looking up while no word came, a glance up-right while thinking, the body
  // swelling with the mic.
  target(b,tg,t){ const V=b.voice; if(!V.listen&&!V.on) return;
    if(V.listen&&!V.words){ tg.yaw+=Math.sin(t*1.1)*.06; tg.pitch+=.12 }
    if(V.on&&V.sub==='thinking'){ tg.yaw+=.12; tg.pitch+=.1 }
    if(V.listen||V.sub==='listening') tg.sy=Math.max(tg.sy,1+V.lvl*.04);
    if(V.listen) tg.sx=Math.min(tg.sx,1-V.lvl*.02) },
  update(b,dt,t){ const V=b.voice, hear=V.listen||V.on&&V.sub==='listening';
    if(!V.listen&&!V.on&&V.lvl<.001&&V.pulse<.001&&Math.abs(V.bob)<1e-4){ V.lvl=V.pulse=V.bob=0; return }
    V.lvl+=((V.listen||V.on?V.mic*speech(t):0)-V.lvl)*(1-Math.pow(.88,dt*60));   // BotCanvasView: 12 % a frame
    if(V.listen&&V.lvl>.15) V.words=true;                  // a voice means words in the transcript
    V.pulse+=((hear&&V.lvl>.01?V.lvl:0)-V.pulse)*(1-Math.pow(.0008,dt));
    // Swift pulls oy 25 % of the way to a ±0.018 R sine each frame, then its rest pull brings it back: ±0.009 R at 60 fps.
    V.bob=(V.bob+((V.on&&V.sub==='speaking'?Math.sin(phase())*.018:0)-V.bob)*(1-Math.pow(.75,dt*60)))*Math.pow(.0008,dt) },
  // Listening blinks slower (BotEngine.swift:1053).
  blink(b){ if(!b.voice.listen) return null; b.blink(); return 3000+rand()*1500 },
  modify(b,m){ const V=b.voice, s=b.s;
    if((V.listen||V.on)&&!m.eye){ m.eye='voice'; if(!b.eyeOv) m.es*=1.04 }   // the 1.04 core gives 'wide' discs
    m.headTilt+=s.lTilt+s.vTilt;
    const k=Math.min(1,Math.abs(s.lTilt)/.1); m.lookX+=b.handSide*.5*k; m.lookY+=.35*k;   // listening, the pupils turn up to the sound
    m.es*=1+Math.max(0,s.vEs)+V.pulse*(V.listen?.15:.16);
    if(!b.tweening('oy')) m.oy+=V.bob },
  beak(b,d){ const a=b.s.talk; if(a<.01||d.mini) return false; const o=Math.round(a*(.5-.5*Math.sin(phase()-LAG))*16)/16; if(o<=0) return false;
    openBeak(b,d,o); return true },
  layers:{front(b,d){ if(!d.mini&&(b.voice.wing||b.voice.fade)) soundArcs(b,d) }},
  // A session runs its course, so ?soak and ?film end at rest.
  actions:{listen(b){ exitCompact(b); enterListening(b); b.after('voiceListen',1600,()=>exitListening(b,true)) },
    speak(b){ begin(b,'speaking'); b.after('voiceSpeak',1800,()=>exitCompact(b)) }},
  soak(b,bad){ const V=b.voice; if(V.listen||V.on||V.wing) bad.push('voice:'+(V.listen?'listen':V.sub));
    for(const v of OWN) if(Math.abs(b.s[v])>.01) bad.push(v+':'+b.s[v].toFixed(2));
    if(V.pulse>.01||Math.abs(V.bob)>.001) bad.push('voice:pulse') },
  // ?voice=listening|thinking|speaking[&compact=1][&mic=.7][&lx=<look x>]: the session starts 0.6 s in and holds for the still.
  capture(b,p){ const v=p.get('voice'); if(p.has('mic')) b.voice.mic=+p.get('mic'); if(p.has('lx')) b.look.x=+p.get('lx'); if(!v) return;
    const go=()=>{ if(v==='listening'&&!p.has('compact')) enterListening(b); else begin(b,v) };
    if(Clock.virtual) b.after('voiceShot',600,go); else go() },   // stills wait until Koru has turned to the look; ?bench has no clock to wait on
  controls(ui,{main,mini,mini2}){ const both=fn=>()=>{ for(const b of [main,mini]) fn(b) }; ui.group('Voz');
    ui.button('Ouvir','#22D3EE',both(listen)); ui.button('Pensar (voz)','#8C50FF',both(b=>begin(b,'thinking')));
    ui.button('Falar','#2EE6C0',both(b=>begin(b,'speaking'))); ui.button('Parar','#94A3B8',both(stop));
    ui.slider('Microfone',0,1,.05,0,v=>{ for(const b of [main,mini,mini2]) b.voice.mic=v }) }
});
})();
