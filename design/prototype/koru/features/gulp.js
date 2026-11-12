// Gulp: Koru's beak opens, swallows a file and chews (BotEngine.swift gulp, UploadSequenceEngine.swift).
// Ports BotEngine.swift gulp() 396-419 (the mouth slot opens to 0.42, shuts after 0.46 s, then 0.8 s of chewing; sy .78/1.18/1
// and sx 1.28/.92/1 over 80/130/220 ms out/out/back; a blink), its slot spring 1074-1080 (ω = 2π/0.25, ζ = 0.6, never below 0)
// and drawEyes() 1519-1522 (cup eyes while the slot is open, happy ones while chewing; the cup of 1648-1660). The suck action
// ports the drop of UploadSequenceEngine.swift (mouth .42 locked, .50 from the drop, the suck 2.03-2.33 s, shut by 2.42 s, the
// squeeze, two chews of 0.14 s, content eyes to 2.98 s), with the file and green motes of UploadCanvasView.swift drawFile() 415-470.
// Koru never becomes a box: her beak is the slot.
(()=>{
const {register,E,NOW,clamp,lerp,smooth,drop,inner,eyeShapes,sheet,stamp,beakPath,beakFinish}=Koru;
const OPEN=.42, MAX=.50, W=2*Math.PI/.25, Z=.6;           // slot levels (BotEngine.swift 400, UploadSequenceEngine.swift 23-24)
const CHEW=.14, CHEWS=5, BITE=.065;                         // a chew lasts 0.14 s, five fit in gulp()'s 0.8 s; Koru's beak parts a little on each
// The drop of UploadSequenceEngine.swift in its own seconds (t_ref); the suck starts at the lock, 0.4 s before the drop.
const T={locked:1.55,drop:1.95,suckIn:2.03,suckOut:2.33,shut:2.42,chew:2.60,chewEnd:2.88,eyes:2.98};
const seg=(t,a,b)=>clamp((t-a)/(b-a),0,1), eIn=t=>t*t*t;
let held=null;                                             // ?hold=<ms> stops the suck's clock, for stills and the bench
const tref=g=>T.locked+(held??NOW()-g.at)/1000;

// UploadSequenceEngine.swift computeFrame() and usSqueezeX/Y: [sx, sy] squeezed by the drop, stretched by the suck,
// squashed as the mouth shuts, then a bob with each chew.
function squeeze(t){
  if(t<T.drop) return [1,1];
  if(t<T.suckIn){ const k=E.out(seg(t,T.drop,T.suckIn)); return [lerp(1,1.06,k),lerp(1,.92,k)] }
  if(t<T.suckOut){ const k=E.inOut(seg(t,T.suckIn,T.suckOut)); return [lerp(1.06,.97,k),lerp(.92,1.06,k)] }
  const t1=T.suckOut+.07, t2=T.suckOut+.2;
  if(t<=t1){ const k=E.out(seg(t,T.suckOut,t1)); return [lerp(.97,1.14,k),lerp(1.06,.82,k)] }
  if(t<=t2){ const k=E.out(seg(t,t1,t2)); return [lerp(1.14,.95,k),lerp(.82,1.1,k)] }
  if(t<T.chew){ const k=E.inOut(seg(t,t2,T.chew)); return [lerp(.95,1,k),lerp(1.1,1,k)] }
  if(t<T.chewEnd){ const c=Math.sin(Math.PI*((t-T.chew)%CHEW)/CHEW); return [1+.03*c,1-.05*c] }
  return [1,1] }
// 0..1 through each chew: gulp() chews from the moment it shuts, the suck from 2.60 s.
function chew(g){ if(g.kind==='gulp'&&g.chewAt!=null){ const e=(NOW()-g.chewAt)/1000; return e<CHEW*CHEWS?Math.sin(Math.PI*(e%CHEW)/CHEW):0 }
  if(g.kind==='suck'){ const t=tref(g); if(t>=T.chew&&t<T.chewEnd) return Math.sin(Math.PI*((t-T.chew)%CHEW)/CHEW) } return 0 }
const opening=g=>Math.max(g.h,BITE*chew(g));             // the slot, or the small parting of a chew

// [suck 0..1, alpha] while the file shows: gulp() sucks it in over the suck's 0.3 s, ending as the beak shuts.
function file(g){ if(g.kind==='gulp'){ const e=(NOW()-g.at)/1000; return e<.46?[seg(e,.16,.46),smooth(seg(e,0,.08))]:null }
  if(g.kind!=='suck') return null; const t=tref(g); return t<T.suckOut?[seg(t,T.suckIn,T.suckOut),1]:null }

function gulp(b){ const g=b.gulp; g.kind='gulp'; g.at=NOW(); g.to=OPEN; g.chewAt=null; b.sound('gulp');
  b.anim('sy',[[.78,80,E.out],[1.18,130,E.out],[1,220,E.back]]); b.anim('sx',[[1.28,80,E.out],[.92,130,E.out],[1,220,E.back]]); b.blink();
  b.after('gulp',460,()=>{ g.to=0; g.chewAt=NOW(); b.after('gulp',800,()=>{ g.kind=null; g.chewAt=null }) }) }
function suck(b){ const g=b.gulp; g.kind='suck'; g.at=NOW(); g.to=OPEN; g.chewAt=null; b.sound('gulp');
  b.after('gulp',(T.eyes-T.locked)*1000,()=>{ g.kind=null; g.to=0 }) }

// A symmetric path from its right half: cubic segments [c1x,c1y,c2x,c2y,x,y] from (0,y0) down to the centre line.
function sym(y0,segs){ const p=new Path2D(); p.moveTo(0,y0); for(const s of segs) p.bezierCurveTo(...s);
  for(let i=segs.length-1;i>=0;i--){ const s=segs[i], [px,py]=i?segs[i-1].slice(4):[0,y0]; p.bezierCurveTo(-s[2],s[3],-s[0],s[1],-px,py) }
  p.closePath(); return p }
// The open beak in the beak's own frame (d.br, d.tip: the closed teardrop), k = slot / 0.42. The upper mandible is core's beak,
// a little wider, with its tip drawn up into a hook; the lower one hinges at the mouth corners and drops, the mouth shows
// between. The opening comes in steps of MAX/32, so the finish of each step is drawn once and cached.
const Q=32/MAX, step=o=>Math.round(o*Q)/Q;
function beakShape(d,o){ const {br,tip,R}=d, k=o/OPEN, k1=clamp(k,0,1), ty=lerp(tip,br*1.25,k1), gap=R*.18*k, f=1+.18*k1, cw=br*.98*f, yc=br*.12;
  const c1=Math.min(br*.6,ty*.8), th=br*.36*smooth(clamp(k/.2,0,1)), fl=br*.06*k1, lip=[cw*.92,c1+gap*.6,cw*.65,ty*.85+gap,0,ty+gap];
  const upper=new Path2D(); upper.addPath(beakPath(br,ty),new DOMMatrix().scale(f,1));
  const lower=sym(yc-br*.3,[[cw*.95+fl,yc-br*.3,cw+fl,yc-br*.12,cw+fl,yc],[cw*.95+fl,c1+gap*.6+th*.8,cw*.7,ty*.85+gap+th,0,ty+gap+th]]);
  const mouth=sym(yc,[[cw/3,yc,cw*2/3,yc,cw,yc],lip]);    // its top edge lies under the upper mandible
  const L=R*20, above=new Path2D(); above.moveTo(-L,-L); above.lineTo(L,-L); above.lineTo(L,yc); above.lineTo(cw,yc); above.bezierCurveTo(...lip);   // all above the lower lip
  above.bezierCurveTo(-lip[2],lip[3],-lip[0],lip[1],-cw,yc); above.lineTo(-L,yc); above.closePath();
  return {o,ty,gap,cw,upper,lower,mouth,above} }
function drawBeak(x,d,s){ const {R,br,full}=d, {o,ty,gap,cw}=s, bot=ty+gap, LB=[-cw*1.4,-br*.5,cw*1.4,bot+br*.36+R*.1], key=o+':'+R;
  if(full) stamp(x,sheet('gulpLowShadow'+key,LB,g=>drop(g,s.lower,'rgba(4,45,52,.4)',R*.03,R*.012,R*.02)));
  const lg=x.createLinearGradient(0,0,0,bot+br*.4); lg.addColorStop(0,'#F7A43C'); lg.addColorStop(1,'#D06A1C'); x.fillStyle=lg; x.fill(s.lower);
  const mg=x.createLinearGradient(0,ty,0,bot); mg.addColorStop(0,'#24070A'); mg.addColorStop(1,'#6B1D1D'); x.fillStyle=mg; x.fill(s.mouth);
  if(full){ stamp(x,sheet('gulpMouth'+key,LB,g=>{ g.clip(s.mouth); drop(g,s.upper,'rgba(12,0,2,.7)',R*.03,0,R*.018) }));   // the upper mandible's shade in the mouth
    stamp(x,sheet('gulpLow'+key,LB,g=>inner(g,s.lower,'rgba(150,60,8,.4)',R*.03,0,-R*.02,[-cw*1.3,0,cw*1.3,bot+br*.5]),R*.1)) }
  beakFinish(x,s.upper,R,full,'gulp'+o) }

// The file of UploadCanvasView.swift drawDoc()/drawFile(), in canvas pixels: u = R per 34 pt of the file's width.
const DOC={w:.42,h:.52,rest:[.66,-1.3]};                 // its size in R and where it waits (the cursor), from the body centre
function docAt(x,w,h,u){ const x0=-w/2, y0=-h/2, f=8*u*Math.min(w/(34*u),h/(42*u)), r=2*u, p=new Path2D();
  p.moveTo(x0+r,y0); p.lineTo(x0+w-f,y0); p.lineTo(x0+w,y0+f); p.lineTo(x0+w,y0+h-r); p.quadraticCurveTo(x0+w,y0+h,x0+w-r,y0+h);
  p.lineTo(x0+r,y0+h); p.quadraticCurveTo(x0,y0+h,x0,y0+h-r); p.lineTo(x0,y0+r); p.quadraticCurveTo(x0,y0,x0+r,y0); p.closePath();
  x.save(); x.shadowColor='rgba(0,0,0,.45)'; x.shadowBlur=8*u; x.shadowOffsetY=3*u;
  const pg=x.createLinearGradient(x0,y0,x0+w,y0+h); pg.addColorStop(0,'#FBFBFC'); pg.addColorStop(1,'#E4E5EA'); x.fillStyle=pg; x.fill(p); x.restore();
  x.fillStyle='#D5D6DB'; x.beginPath(); x.moveTo(x0+w-f,y0); x.lineTo(x0+w-f,y0+f); x.lineTo(x0+w,y0+f); x.fill();
  x.fillStyle='#3B82F5'; x.beginPath(); x.roundRect(x0+w*.18,y0+h*.58,w*.64,h*.16,2*u); x.fill() }
// s = suck 0..1; m = where it sinks to, in canvas pixels. Swift's file runs down into the slot (down in inOut, across in out,
// shrinking); Koru's beak faces us, so the file goes into her mouth whole and opaque, tilting, and sinks behind the lower lip
// (the caller clips it there); only its last sliver fades.
// Four green motes follow it in, and are gone where onFace(x,y) says they reach the face (green on orange reads as a stain).
function drawFile(x,d,s,m,a,onFace){ const R=d.R, W0=DOC.w*R, H0=DOC.h*R, u=W0/34, cx=d.W/2+DOC.rest[0]*R, cy=d.H/2+(Koru.G.cy+DOC.rest[1])*R;
  const q=E.out(s), sc=lerp(1,.45,E.inOut(s));
  x.save(); x.globalAlpha=a*(s>0?1-smooth(seg(s,.88,1)):.92); x.translate(lerp(cx,m.x,q),lerp(cy,m.y,E.inOut(s))); x.rotate(-.14*q); x.scale(sc,sc);
  docAt(x,W0,H0*lerp(1,1.08,q),u); x.restore();
  for(let i=0;i<4;i++){ const an=i/4*Math.PI*2+.6, k=clamp((s-i*.08)/.7,0,1); if(k<=0||k>=1) continue;
    const kk=Math.pow(k,.7), px=lerp(cx+Math.cos(an)*24*u,m.x,kk), py=lerp(cy+Math.sin(an)*24*u,m.y,kk)-Math.sin(Math.PI*k)*6*u; if(onFace(px,py)) continue;
    x.fillStyle=`rgba(52,212,153,${(1-k)*a})`; x.beginPath(); x.arc(px,py,2.2*u*(1-k*.5),0,Math.PI*2); x.fill() } }

// BotEngine.swift 1648-1660: a flat top and a round bottom, at the pupil's place and about its size, with its catchlight;
// on Koru the two converge a little on the beak and their tops slope down outward, as in the keyframe.
eyeShapes.cup=(b,{x,R,sd,pr,px,py,far,ink})=>{ const w=pr*2.1, hh=w*.78, cr=w/2, f=w*.22;
  x.save(); x.translate(px-sd*pr*.3,py); x.rotate(sd*.12); x.scale(1-far*.07,1); x.fillStyle=ink; x.beginPath(); x.moveTo(-w/2,-hh/2+f); x.quadraticCurveTo(-w/2,-hh/2,-w/2+f,-hh/2); x.lineTo(w/2-f,-hh/2); x.quadraticCurveTo(w/2,-hh/2,w/2,-hh/2+f); x.lineTo(w/2,hh/2-cr);
  x.quadraticCurveTo(w/2,hh/2,w/2-cr,hh/2); x.lineTo(-w/2+cr,hh/2); x.quadraticCurveTo(-w/2,hh/2,-w/2,hh/2-cr); x.closePath(); x.fill();
  x.shadowColor='rgba(255,245,235,.8)'; x.shadowBlur=R*.012; x.fillStyle='rgb(252,243,237)'; x.beginPath(); x.arc(w*.24,-hh*.2,pr*.24,0,Math.PI*2); x.fill(); x.restore() };

register({name:'gulp',
  // h is the slot, moved by its spring here, not by core's smoothing.
  init(b){ b.gulp={kind:null,at:0,to:0,h:0,v:0,chewAt:null} },
  update(b,dt){ const g=b.gulp, t=g.kind==='suck'?tref(g):0;
    if(g.kind==='suck'&&t>=T.suckOut){ g.h=MAX*(1-eIn(seg(t,T.suckOut,T.shut))); g.v=0 }   // the shut is a curve, not the spring
    else { if(g.kind==='suck') g.to=t<T.drop?OPEN:MAX;
      for(let i=Math.ceil(dt*240),h=dt/i;i>0;i--){ g.v+=(W*W*(g.to-g.h)-2*Z*W*g.v)*h; g.h=Math.max(0,g.h+g.v*h) } } },
  modify(b,m){ const g=b.gulp; if(!g.kind) return;
    let look=false; const f=file(g);
    let eye=null;
    if(g.kind==='gulp'){ const c=chew(g); m.sx*=1+.03*c; m.sy*=1-.05*c;
      if(g.chewAt!=null) eye='happy'; else if(g.to>.05||g.h>.1){ eye='cup'; look=true } }
    else { const t=tref(g), [sx,sy]=squeeze(t); m.sx*=sx; m.sy*=sy;
      if(t<T.suckOut){ eye='cup'; look=true } else if(t<T.eyes) eye='happy' }
    if(!m.eye) m.eye=eye;
    // Swift looks at the cursor until the file is in; Koru's eyes follow the file from where it waits down into her beak.
    if(look){ const s=b.s, k=f?E.inOut(f[0]):0; m.lookX+=lerp(.2,0,k)-clamp(s.yaw/.62,-1,1)*.8; m.lookY+=lerp(.35,-1.1,k)-clamp(s.pitch/.5,-1,1)*.85 } },
  beak(b,d){ const g=b.gulp; if(!g.kind&&g.h<.004) return false; const o=step(opening(g)); if(o<=0) return false;
    drawBeak(d.x,d,beakShape(d,o)); return true },
  // The file is held in the beak, over hats and glasses: it goes into the mouth behind the upper mandible (or the closed beak)
  // and sinks behind the lower lip, so both are clipped out of it.
  layers:{headTop(b,d){ const g=b.gulp, f=g.kind&&!d.mini?file(g):null; if(!f) return;
    const x=d.x, o=step(opening(g)), s=beakShape(d,o), at=new DOMMatrix().translate(d.beakAt.x,d.beakAt.y), H=x.getTransform();
    const out=new Path2D(); out.rect(-d.W*4,-d.H*4,d.W*8,d.H*8); out.addPath(o<=0?d.beak:s.upper,at);
    const m=H.multiply(at).transformPoint({x:0,y:s.ty+s.gap});   // at the lower lip: the dark mouth shows above it, its bottom is behind the lip
    x.clip(out,'evenodd'); x.setTransform(H.multiply(at)); x.clip(s.above); x.setTransform(1,0,0,1,0,0);
    drawFile(x,d,f[0],m,f[1],(px,py)=>{ x.setTransform(H); const on=x.isPointInPath(d.face,px,py); x.setTransform(1,0,0,1,0,0); return on }) }},
  actions:{gulp,suck},
  soak(b,bad){ const g=b.gulp; if(g.kind||g.h>.01||g.to>0) bad.push('gulp:'+(g.kind||'')+g.h.toFixed(2)) },
  // ?shot=<state>&gulp=<ms> (or &suck=<ms>): the still is <ms> after the action starts; &hold=<ms> stops the suck's clock there;
  // &lx=<look x>.
  capture(b,p){ if(p.has('hold')) held=+p.get('hold'); if(p.has('lx')) b.look.x=+p.get('lx');
    for(const [k,fn] of [['gulp',gulp],['suck',suck]]) if(p.has(k)){ const at=2200-(+p.get(k)); if(at<=0) fn(b); else b.after('gulpShot',at,()=>fn(b)) } },
  controls(ui,bots){ ui.group('Engolir'); ui.button('Engolir arquivo','#34D499',()=>gulp(bots.main)) }
});
})();
