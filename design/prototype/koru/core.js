// Koru engine: the Mochi motion engine (states, tweens, badges, particles) drawing the Koncluí owl.
// Loaded as a classic script (file:// pages cannot load ES modules); everything is exported on window.Koru.
// Features live in koru/features/*.js and plug in through Koru.register() (see FEATURES below).
// Porting to SwiftUI: drop()/inner() map to GraphicsContext shadows inside drawLayer (the OFF trick is not needed there);
// cached sheets to pre-rendered Images; soft-light, destination-in/out and screen to blendMode in a drawLayer; the grain
// pattern to a tiled noise Image. Sizes here are device pixels (R already includes the screen scale).
(()=>{
const params=new URLSearchParams(location.search);
const SHOT=params.get('shot'), GRID=params.has('grid'), FILM=params.has('film'), SOAK=params.has('soak'), BENCH=params.has('bench');

/* ---------------- CLOCK ---------------- */
// Live: real time. Capture: virtual time and a seeded random, so a screenshot is the same every run.
const Clock={virtual:!!(SHOT||GRID||FILM||SOAK||BENCH),t:0,timers:[],
  now(){return this.virtual?this.t:performance.now()},
  later(fn,ms){ if(!this.virtual) return setTimeout(fn,ms); const h={at:this.t+ms,fn}; this.timers.push(h); return h },
  cancel(h){ if(h==null) return; if(!this.virtual) clearTimeout(h); else this.timers=this.timers.filter(x=>x!==h) },
  // As setTimeout: due timers fire in time order (ties in the order they were set), each seeing its own time.
  advance(ms){ const end=this.t+ms;
    for(;;){ let h=null; for(const x of this.timers) if(x.at<=end&&(!h||x.at<h.at)) h=x; if(!h) break;
      this.timers.splice(this.timers.indexOf(h),1); this.t=Math.max(this.t,h.at); h.fn() }
    this.t=end }};
let seed=7; const reseed=v=>{ seed=v };
const rand=Clock.virtual?()=>{seed|=0;seed=seed+0x6D2B79F5|0;let t=Math.imul(seed^seed>>>15,1|seed);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}:Math.random;
const NOW=()=>Clock.now();

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)), lerp=(a,b,t)=>a+(b-a)*t, smooth=t=>t*t*(3-2*t);
const E={out:t=>1-Math.pow(1-t,3),inOut:t=>t<.5?4*t*t*t:1-Math.pow(-2*t+2,3)/2,back:t=>{const c1=1.7,c3=c1+1;return 1+c3*Math.pow(t-1,3)+c1*Math.pow(t-1,2)},lin:t=>t};
const hexRgb=h=>{h=h.replace('#','');return[parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)]};
const rgba=(c,a)=>`rgba(${c[0]|0},${c[1]|0},${c[2]|0},${a})`;
const mix=(a,b,t)=>[lerp(a[0],b[0],t),lerp(a[1],b[1],t),lerp(a[2],b[2],t)];

/* ---------------- KORU ---------------- */
// Palette and geometry, in units of R (R = 0.3 × canvas width × the Bot's frame, as for Mochi), from the body centre.
const K={eyeIn:hexRgb('#F8FAFA'),eyeEdge:hexRgb('#DAE2E4'),ink:'#164149'};   // white eye discs (owner's choice), dark ink pupils
// The colours a feature may swap as a whole through bot.palette (mini Korus take their agent's colour this way):
// body = the key-light gradient from the lit dome to the shaded base, belly = top to bottom, wing = upper edge to tip.
const PALETTE={body:['#6CCAD5','#3EA5B1','#2A94A2','#167E8A','#0E6470'],belly:['#3FAAB2','#268C98','rgba(38,140,152,.6)'],wing:['#124F5C','#09343E']};
const G={rx:1.21,ryTop:1.04,ryBot:1.02,cy:.088,nTop:2.0,nBot:3.5,
  eyeSp:.518,eyeY:-.117,ring:.558,disc:.386,pupil:.152,face:.27};

// hy, ear, tilt, tint and go are targets, eased every frame (a tween on one of them wins while it runs). sound: what
// BotEngine.swift's state table plays when the state starts (emotes carry theirs too).
const STATES={
  idle:{label:'Parada',col:'#1EAAC8',tint:.2,eye:'pill',badge:null,go:.6},
  working:{label:'Trabalhando',col:'#1796E5',hy:.054,sq:.955,dy:.03,tint:.85,eye:'pill',badge:['dots',['#3D8CFF','#2F6CF5']],bo:[-.083,-.11],fold:1,look:[.05,-1.6],converge:1,pupil:1.12,go:1,sound:'work'},
  thinking:{label:'Pensando',col:'#8C50FF',hy:.022,sq:.932,dy:.03,tint:.85,eye:'pill',badge:['dots',['#9A4DFF','#7C3AED']],bo:[.125,.058],bsc:.9,brot:-.09,dot:'#F0D8FF',fold:1,look:[1.25,.95],go:1,sound:'think'},
  searching:{label:'Procurando',col:'#4A80F2',hy:0,sq:.967,dy:.03,tint:.85,eye:'pill',badge:['dots',['#4F5BFF','#3A3DF0']],bo:[-.05,.058],scan:1,go:1,sound:'search'},
  approval:{label:'Aprovação',col:'#FFAA1E',hy:.076,sq:.935,dy:.03,tint:.95,eye:'wide',badge:['bang',['#FFC23A','#F07F00']],bo:[0,.11],fold:1,look:[.75,-.05],bounce:1,go:.75,sound:'approval'},
  question:{label:'Pergunta',col:'#28C8FF',hy:-.04,dy:.03,tint:.9,eye:'pill',badge:['q',['#22D0FF','#0A9CF0']],bo:[-.05,-.015],tilt:.26,look:[1.1,.85],go:.5,sound:'question'},
  error:{label:'Erro',col:'#FF3C46',hy:.05,dy:.03,tint:.95,eye:'flat',badge:['dot',['#FF5A5A','#E8303C']],bo:[-.058,-.067],ear:1.4,go:.5,sound:'error'},
  finished:{label:'Terminou',col:'#2EE6C0',hy:.06,dy:.03,tint:.85,eye:'happy',badge:['ring',['#22F79E','#18D888']],bo:[.17,-.04],aura:'spark',go:.5,sound:'finish'},
  sleeping:{label:'Dormindo',col:'#1EAAC8',hy:.06,dy:.03,tint:.1,eye:'closed',badge:null,breathe:1,zz:1,ear:.45,go:.32,sound:'sleep'},
  dizzy:{label:'Tonta',col:'#FF5AAA',hy:.01,dy:.03,tint:.95,eye:'spiral',badge:null,aura:'wobble',tilt:.17,go:1,sound:'dizzy'},
  ratelimit:{label:'Limite',col:'#FB923C',tint:.85,eye:'tired',badge:['dot',['#FFA552','#F07C1E']],sweat:1,go:.9,sound:'rate'}
};
const EMOTES={love:{label:'Amor',eye:'heart',c:'#FF4D6D',sound:'love'},surprised:{label:'Surpresa',eye:'dot',c:'#FFFFFF'},proud:{label:'Orgulho',eye:'star',c:'#F7B32B',sound:'proud'},wink:{label:'Piscadinha',eye:'wink',c:'#A78BFA',sound:'wink'},yawn:{label:'Bocejo',eye:'tired',c:'#94A3B8',sound:'yawn'},happy:{eye:'happy'},annoyed:{eye:'line',ms:800,sound:'annoyed'}};

function rr(x,X,Y,W,H,R){R=Math.max(0,Math.min(R,W/2,H/2));x.beginPath();x.moveTo(X+R,Y);x.arcTo(X+W,Y,X+W,Y+H,R);x.arcTo(X+W,Y+H,X,Y+H,R);x.arcTo(X,Y+H,X,Y,R);x.arcTo(X,Y,X+W,Y,R);x.closePath()}
function heart(x,s){x.beginPath();x.moveTo(0,s*.38);x.bezierCurveTo(-s*1.05,-s*.15,-s*.5,-s*.95,0,-s*.38);x.bezierCurveTo(s*.5,-s*.95,s*1.05,-s*.15,0,s*.38);x.closePath()}
function star(x,ro,ri,n=5){x.beginPath();for(let i=0;i<n*2;i++){const r=i%2?ri:ro,a=-Math.PI/2+i*Math.PI/n;x.lineTo(Math.cos(a)*r,Math.sin(a)*r)}x.closePath()}
// A pool of light on the floor: a radial gradient of radius r (px) at cx,y, flattened to sy; stops [[offset,css colour],...].
function floorPool(x,cx,y,r,sy,stops){ x.save(); x.translate(cx,y); x.scale(1,sy); const g=x.createRadialGradient(0,0,0,0,0,r);
  for(const [o,c] of stops) g.addColorStop(o,c); x.fillStyle=g; x.beginPath(); x.arc(0,0,r,0,Math.PI*2); x.fill(); x.restore() }

// Soft light and shadow without ctx.filter: the shape is drawn far off-canvas and only its
// blurred shadow lands in place. Works in every browser and maps to GraphicsContext shadows in Swift.
const OFF=20000;
function shifted(x,path){ const p=new Path2D(); p.addPath(path,new DOMMatrix().translate(-OFF,0).multiply(x.getTransform())); return p }
function drop(x,path,color,blur,dx=0,dy=0){ const p=shifted(x,path); x.save(); x.setTransform(1,0,0,1,0,0);
  x.shadowColor=color; x.shadowBlur=blur; x.shadowOffsetX=OFF+dx; x.shadowOffsetY=dy; x.fillStyle='#000'; x.fill(p); x.restore() }
// Inner light/shade along the edges of a shape. The outside is rasterised into a scratch mask first,
// so overlapping sub-shapes (rings, brows, tufts) act as one union with no seams.
const scratch=document.createElement('canvas');
// box: the shape's bounds [x0,y0,x1,y1] in the current user space. Only that rectangle (plus the blur reach)
// is rasterised and blurred, which keeps the cost proportional to the shape, not to the canvas.
function deviceRect(x,box,pad){ const W=x.canvas.width, H=x.canvas.height; if(!box) return [0,0,W,H];
  const T=x.getTransform(); let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;
  for(const [u,v] of [[box[0],box[1]],[box[2],box[1]],[box[0],box[3]],[box[2],box[3]]]){ const q=T.transformPoint({x:u,y:v}); x0=Math.min(x0,q.x); y0=Math.min(y0,q.y); x1=Math.max(x1,q.x); y1=Math.max(y1,q.y) }
  x0=Math.max(0,Math.floor(x0-pad)); y0=Math.max(0,Math.floor(y0-pad)); x1=Math.min(W,Math.ceil(x1+pad)); y1=Math.min(H,Math.ceil(y1+pad));
  return [x0,y0,Math.max(1,x1-x0),Math.max(1,y1-y0)] }
function inner(x,path,color,blur,dx=0,dy=0,box=null){ const W=x.canvas.width, H=x.canvas.height;
  if(scratch.width!==W||scratch.height!==H){ scratch.width=W; scratch.height=H }
  const [bx,by,bw,bh]=deviceRect(x,box,blur*2+Math.abs(dx)+Math.abs(dy)+2);
  const g=scratch.getContext('2d'); g.setTransform(1,0,0,1,0,0); g.globalCompositeOperation='source-over'; g.fillStyle='#000'; g.fillRect(bx,by,bw,bh);
  g.setTransform(x.getTransform()); g.globalCompositeOperation='destination-out'; g.fill(path); g.globalCompositeOperation='source-over';
  x.save(); x.clip(path); x.setTransform(1,0,0,1,0,0);
  x.shadowColor=color; x.shadowBlur=blur; x.shadowOffsetX=OFF+dx; x.shadowOffsetY=dy; x.drawImage(scratch,bx,by,bw,bh,bx-OFF,by,bw,bh); x.restore() }

// Shading that depends only on a shape is drawn once into a sheet (cached per key) and stamped through the current transform,
// so a frame redraws none of its blurs; box is the sheet's extent in the shape's space. It is drawn in a larger room (box plus
// pad, within clip) because inner() needs the outside of a shape out to its blur, then cropped. Masks are drawn white, tinted when stamped.
const sheets=new Map();
// The cache keeps the most recently used 160 sheets (up to ~100 MB at the live size).
function sheet(key,box,draw,pad=0,clip=null){ let s=sheets.get(key);
  if(s){ sheets.delete(key); sheets.set(key,s) }
  else { const room=[box[0]-pad,box[1]-pad,box[2]+pad,box[3]+pad].map((v,i)=>!clip?v:i<2?Math.max(v,clip[i]):Math.min(v,clip[i]));
    const r0=Math.floor(room[0]), q0=Math.floor(room[1]), big=document.createElement('canvas'); big.width=Math.ceil(room[2])-r0; big.height=Math.ceil(room[3])-q0;
    const g=big.getContext('2d'); g.translate(-r0,-q0); draw(g);
    const x0=Math.floor(box[0]), y0=Math.floor(box[1]), c=document.createElement('canvas'); c.width=Math.max(1,Math.ceil(box[2])-x0); c.height=Math.max(1,Math.ceil(box[3])-y0);
    c.getContext('2d').drawImage(big,r0-x0,q0-y0); s={c,x0,y0}; sheets.set(key,s); if(sheets.size>160) sheets.delete(sheets.keys().next().value) }
  return s }
const stamp=(x,s)=>x.drawImage(s.c,s.x0,s.y0);
const tinted=document.createElement('canvas');
function stampTint(x,s,color){ const w=s.c.width, h=s.c.height; if(tinted.width<w||tinted.height<h){ tinted.width=Math.max(tinted.width,w); tinted.height=Math.max(tinted.height,h) }
  const g=tinted.getContext('2d'); g.globalCompositeOperation='copy'; g.drawImage(s.c,0,0); g.globalCompositeOperation='source-in'; g.fillStyle=color; g.fillRect(0,0,w,h);
  x.drawImage(tinted,0,0,w,h,s.x0,s.y0,w,h) }

// Shapes are point lists in R units. Every path winds clockwise, so shapes merge into one fill.
function toPath(pts,R){ let area=0; for(let i=0;i<pts.length;i++){ const [a1,b1]=pts[i], [a2,b2]=pts[(i+1)%pts.length]; area+=a1*b2-a2*b1 }
  if(area<0) pts=pts.slice().reverse();
  const p=new Path2D(); pts.forEach(([u,v],i)=>i?p.lineTo(u*R,v*R):p.moveTo(u*R,v*R)); p.closePath(); return p }
// Quadratic outline [[x0,y0],[cx,cy,x1,y1] or [x,y],...].
function outline(segs,R){ const pts=[]; let [px,py]=segs[0]; pts.push([px,py]);
  for(const sg of segs.slice(1)){ if(sg.length===2){ px=sg[0]; py=sg[1]; pts.push([px,py]); continue }
    const [qx,qy,ex,ey]=sg; for(let i=1;i<=10;i++){ const t=i/10, u=1-t; pts.push([u*u*px+2*u*t*qx+t*t*ex,u*u*py+2*u*t*qy+t*t*ey]) } px=ex; py=ey }
  return toPath(pts,R) }
// Rounded blob: Chaikin corner cutting on a control polygon, so no tip stays sharp.
function blob(pts,R,n=4){ for(let k=0;k<n;k++){ const o=[]; for(let i=0;i<pts.length;i++){ const [a,b]=pts[i], [c,d]=pts[(i+1)%pts.length]; o.push([.75*a+.25*c,.75*b+.25*d],[.25*a+.75*c,.25*b+.75*d]) } pts=o } return toPath(pts,R) }
// Velvet grain: 1 px monochrome noise, laid with soft-light.
let grain=null;
function grainPattern(x){ if(!grain){ const c=document.createElement('canvas'); c.width=c.height=128; const g=c.getContext('2d'), d=g.createImageData(128,128);
    let q=7; const noise=()=>(q=Math.imul(q,48271)%2147483647)/2147483647;   // its own seed: the scene's random draws stay the same whatever is drawn
    for(let i=0;i<d.data.length;i+=4){ const v=128+(noise()-.5)*90; d.data[i]=d.data[i+1]=d.data[i+2]=v; d.data[i+3]=255 } g.putImageData(d,0,0); grain=c }
  const p=x.createPattern(grain,'repeat'); p.setTransform(x.getTransform().inverse().scale(1.6,1.6)); return p }
// Tapered crescent along a circle (centre 0,cy, radius r) from angle a0 to a1, th thick in the middle.
function crescent(x,cy,r,a0,a1,th){ x.beginPath(); const n=24;
  for(let i=0;i<=n;i++){ const a=a0+(a1-a0)*i/n; x.lineTo(Math.cos(a)*r,cy+Math.sin(a)*r) }
  for(let i=n;i>=0;i--){ const a=a0+(a1-a0)*i/n, k=r-th*Math.pow(Math.sin(Math.PI*i/n),.8); x.lineTo(Math.cos(a)*k,cy+Math.sin(a)*k) }
  x.closePath(); x.fill() }
// Eye ring (side sd), in R units: a circle pulled in on its lower inner side so the two rings part under
// the beak; k scales the outer side for the head turn.
function ringPts(cxr,cyr,r,k,sd,pull,up=.15){ const li=sd<0?Math.PI/4:Math.PI*3/4, ui=sd<0?-Math.PI/4:-Math.PI*3/4, pts=[];
  for(let i=0;i<72;i++){ const a=i/72*Math.PI*2, rr=r-pull*Math.pow(Math.max(0,Math.cos(a-li)),2)*Math.max(0,Math.sin(a))-up*Math.pow(Math.max(0,Math.cos(a-ui)),2)*Math.max(0,-Math.sin(a)); let u=Math.cos(a)*rr; const v=Math.sin(a)*rr;
    if(u*sd>0) u*=k; pts.push([cxr+u,cyr+v]) }
  return pts }
// Velvet grain through a vertical fade (device y top..bottom), laid with soft-light inside a path.
const scratch2=document.createElement('canvas');
function grainOn(x,path,top,bottom,alpha,box=null){ const W=x.canvas.width, H=x.canvas.height;
  if(scratch2.width!==W||scratch2.height!==H){ scratch2.width=W; scratch2.height=H }
  const [bx,by,bw,bh]=deviceRect(x,box,2);
  const g=scratch2.getContext('2d'); g.setTransform(1,0,0,1,0,0); g.globalCompositeOperation='source-over'; g.clearRect(bx,by,bw,bh);
  g.fillStyle=grainPattern(g); g.fillRect(bx,by,bw,bh); g.globalCompositeOperation='destination-in';
  const m=g.createLinearGradient(0,top,0,bottom); m.addColorStop(0,'#000'); m.addColorStop(.5,'rgba(0,0,0,.35)'); m.addColorStop(1,'rgba(0,0,0,.2)'); g.fillStyle=m; g.fillRect(bx,by,bw,bh);
  g.globalCompositeOperation='source-over';
  x.save(); x.clip(path); x.setTransform(1,0,0,1,0,0); x.globalCompositeOperation='soft-light'; x.globalAlpha=alpha; x.drawImage(scratch2,bx,by,bw,bh,bx,by,bw,bh); x.restore() }
// The same velvet grain as a sheet in a shape's space (opaque at y0, faint from y1), laid inside a path; box limits it to a part.
// x0,x1 (optional): the grain also fades out towards the middle, gone inside |x| < x0, full beyond x1.
function grainSheet(key,box,y0,y1,x0=0,x1=0){ return sheet('grain'+key,box,g=>{ g.save(); g.setTransform(1,0,0,1,0,0); g.fillStyle=grainPattern(g); g.fillRect(0,0,g.canvas.width,g.canvas.height); g.restore();
  const m=g.createLinearGradient(0,y0,0,y1); m.addColorStop(0,'#000'); m.addColorStop(.5,'rgba(0,0,0,.35)'); m.addColorStop(1,'rgba(0,0,0,.2)');
  g.globalCompositeOperation='destination-in'; g.fillStyle=m; g.fillRect(box[0]-1,box[1]-1,box[2]-box[0]+2,box[3]-box[1]+2);
  if(x1){ const h=g.createLinearGradient(-x1,0,x1,0), a=(x1-x0)/(2*x1); h.addColorStop(0,'#000'); h.addColorStop(a,'rgba(0,0,0,0)'); h.addColorStop(1-a,'rgba(0,0,0,0)'); h.addColorStop(1,'#000');
    g.fillStyle=h; g.fillRect(box[0]-1,box[1]-1,box[2]-box[0]+2,box[3]-box[1]+2) } }) }
function grainStamp(x,path,s,alpha,box){ const u0=Math.max(s.x0,Math.floor(box?box[0]:-1e9)), v0=Math.max(s.y0,Math.floor(box?box[1]:-1e9)),
    u1=Math.min(s.x0+s.c.width,Math.ceil(box?box[2]:1e9)), v1=Math.min(s.y0+s.c.height,Math.ceil(box?box[3]:1e9)); if(u1<=u0||v1<=v0) return;
  x.save(); x.clip(path); x.globalCompositeOperation='soft-light'; x.globalAlpha*=alpha; x.drawImage(s.c,u0-s.x0,v0-s.y0,u1-u0,v1-v0,u0,v0,u1-u0,v1-v0); x.restore() }
// Eyelid (inside an eye disc of radius dr, 0..1 closed): its edge bows down in the middle like a real lid.
function lidEdge(x,dr,lid){ const y=-dr+2*dr*lid, bow=dr*.28*Math.sin(Math.PI*lid); x.moveTo(-dr,y-bow*.6); x.quadraticCurveTo(0,y+bow,dr,y-bow*.6) }
function lidPath(x,dr,lid){ x.beginPath(); x.moveTo(-dr,-dr); x.lineTo(dr,-dr); const y=-dr+2*dr*lid, bow=dr*.28*Math.sin(Math.PI*lid);
  x.lineTo(dr,y-bow*.6); x.quadraticCurveTo(0,y+bow,-dr,y-bow*.6); x.closePath() }
// Badge glyphs as paths, so they look the same on every platform and port to SwiftUI unchanged.
function glyph(x,kind,R){ x.fillStyle=x.strokeStyle='#fff'; x.lineCap='round'; x.lineJoin='round';
  if(kind==='bang'){ x.lineWidth=R*.075; x.beginPath(); x.moveTo(0,-R*.115); x.lineTo(0,R*.02); x.stroke(); x.beginPath(); x.arc(0,R*.1,R*.042,0,Math.PI*2); x.fill() }
  else { x.lineWidth=R*.068; x.beginPath(); x.arc(0,-R*.05,R*.08,Math.PI*1.08,Math.PI*2.3); x.quadraticCurveTo(0,-R*.005,0,R*.03); x.stroke(); x.beginPath(); x.arc(0,R*.105,R*.042,0,Math.PI*2); x.fill() } }
const mirror=(segs,sd)=>segs.map(sg=>sg.map((v,i)=>i%2?v:v*sd));
// The beak, in its own space (origin at d.beakAt): a teardrop br wide each side, its tip at tip below the centre.
function beakPath(br,tip){ const p=new Path2D(); p.moveTo(0,-br*.92); p.bezierCurveTo(br*.75,-br*.95,br*1.08,-br*.35,br*.98,br*.12);
  p.bezierCurveTo(br*.88,br*.6,br*.3,tip*.85,0,tip); p.bezierCurveTo(-br*.3,tip*.85,-br*.88,br*.6,-br*.98,br*.12);
  p.bezierCurveTo(-br*1.08,-br*.35,-br*.75,-br*.95,0,-br*.92); p.closePath(); return p }
// Its matte orange finish lit from the right, for any beak-shaped path (an open beak too): contact shadow, fill, inner shade, sheen.
// key caches the shadow and shading of a path that only changes with it (a quantised opening, say); without it they are drawn live.
function beakFinish(x,path,R,full,key){ const br=R*.125, tip=R*.18, IB=[-br*1.7,-br*1.1,br*1.7,tip+R*.3], KB=[IB[0]-R*.1,IB[1]-R*.1,IB[2]+R*.1,IB[3]+R*.1];   // room for an open beak
  const shadow=g=>drop(g,path,'rgba(4,45,52,.4)',R*.03,R*.012,R*.02);
  const shade=g=>{ inner(g,path,'rgba(160,70,8,.35)',R*.035,0,-R*.02,IB);
    const hs=new Path2D(); hs.ellipse(R*.035,-R*.06,R*.05,R*.03,.35,0,Math.PI*2); g.save(); g.clip(path); drop(g,hs,'rgba(255,236,200,.45)',R*.03); g.restore() };
  if(full) key!=null?stamp(x,sheet('beakShadow'+key+':'+R,KB,shadow)):shadow(x);
  const bkg=x.createLinearGradient(0,-br,0,tip); bkg.addColorStop(0,'#FDB247'); bkg.addColorStop(1,'#E57D21'); x.fillStyle=bkg; x.fill(path);
  if(full) key!=null?stamp(x,sheet('beak'+key+':'+R,KB,shade,R*.1)):shade(x) }

// Body: an ellipse dome on top, a flatter superellipse underneath.
// Cached per size: callers and features treat the returned path as read-only.
const bodyCache=new Map();
function bodyPath(R,rx){ const key=R+':'+rx; if(bodyCache.has(key)) return bodyCache.get(key); const p=new Path2D();
  for(let i=0;i<=120;i++){ const a=i/120*Math.PI*2, ca=Math.cos(a), sa=Math.sin(a), top=sa<0;
    const n=top?G.nTop:G.nBot, ry=R*(top?G.ryTop:G.ryBot);
    const px=rx*Math.sign(ca)*Math.pow(Math.abs(ca),2/n), py=ry*Math.sign(sa)*Math.pow(Math.abs(sa),2/n);
    i?p.lineTo(px,py):p.moveTo(px,py) }
  p.closePath(); bodyCache.set(key,p); return p }
// Half-width of that outline at height y (R units from the body centre), for shapes that hug the body.
const bodyW=y=>{ const top=y<0, n=top?G.nTop:G.nBot; return G.rx*Math.pow(Math.max(0,1-Math.pow(Math.abs(y/(top?G.ryTop:G.ryBot)),n)),1/n) };

// Left-side shapes (x < 0); the right side is the mirror. f = face offset in R for turning the head.
const browSegs=(f,far=0)=>[[0+f,-.24],[-.08+f*.8,-.80+.06*far,-.75+f*.5,-.92+.14*far],[-.72+f*.6,-.50],[-.36+f,-.42]];   // the far brow drops with its tuft
const TUFT=[[-1.10,-1.16],[-1.14,-1.07],[-1.13,-.92],[-1.05,-.80],[-1.20,-.79],[-1.16,-.70],[-1.04,-.62],[-.86,-.50],[-.63,-.56],[-.55,-.76],[-.58,-.86],[-.66,-.90],[-.80,-.965],[-.95,-1.04]];
// e lowers the tip (sad, asleep) or raises it when negative (surprised).
const tuftPts=(f,e,far=0)=>TUFT.map(([u,v])=>{ const bx=-.6, by=-.8, w=clamp(Math.hypot(u-bx,v-by)/.45,0,1), a=-.5*e*w, c=Math.cos(a), sn=Math.sin(a);
  v+=far*(.05+.12*clamp((u+1.0)/.45,0,1)+.04*clamp((v+.75)/.25,0,1)); u-=.03*far*clamp((-u-.9)/.25,0,1);
  return [bx+(u-bx)*c-(v-by)*sn+f, by+(u-bx)*sn+(v-by)*c] });
// Wing: two feathers, a rounded upper one leaning out and a lower lobe below a soft notch. Its path is cached per size.
const WING=[[-1.27,-.10],[-1.18,-.07],[-1.09,.0],[-1.02,.13],[-.98,.33],[-.99,.48],[-1.06,.555],[-1.15,.54],[-1.26,.42],[-1.36,.27],[-1.41,.18],[-1.37,.10],[-1.31,.135],[-1.32,.02],[-1.31,-.06]];
const wingCache=new Map(), wingPath=R=>{ if(!wingCache.has(R)) wingCache.set(R,blob(WING,R,3)); return wingCache.get(R) };

/* ---------------- FEATURES ---------------- */
// A feature is a plain object registered with Koru.register(): name, actions {name: fn(bot)} (for ?film=<name>), and hooks. Every member
// is optional:
//   init(bot)                     once per Bot
//   target(bot,tg,t)              every update, before smoothing: may change this frame's targets
//                                 (yaw, pitch, tilt, oy, sx, sy, hy, ear, tint, go, and the feature's own values)
//   update(bot,dt,t)              every update, after tweens and smoothing; every update runs before the first modify
//   modify(bot,m,t)               every update; adds to the modifiers m (MODS below), read by draw(); m.eye: the first to set it wins
//   blink(bot)                    a blink is due (live, awake): blink or not, and return the ms to the next one; null leaves it to core
//   layers:{floor,behind,body,wings,headBack,face,headFront,headTop,front}(bot,d)   draw hooks, see draw(); wings runs after
//                                 the wings are drawn, in the body's space, with d.wings their outline (to recolour them)
//   beak(bot,d)                   return true when it drew the beak itself; the first one that does wins (script order)
//   onState(bot,prev,next)  onClick(bot) (return true when handled)  onSound(bot,name) (a sound event)
//   capture(bot,params)           captures set the feature up from the URL (?shot, ?film and ?grid on a virtual clock; ?bench live)
//   controls(ui,bots)             live page controls
//   soak(bot,bad)                 after ?soak's random actions and rest: push a string to bad for anything still not at rest
// The Bot API for features (the rest of a Bot is internal):
//   values   bot.s (read), bot.set(p,v) (also starts a feature's own value), bot.anim(p,keys,after), bot.stop(p), bot.tweening(p)
//   timers   bot.after(key,ms,fn) (one pending timer per key), bot.cancel(key)
//   eyes     bot.override(eye,ms), bot.clearOverride(), bot.eyeOv (read: the eye shown over the state's), bot.blink(), bot.blinkIn(ms)
//   wing     bot.raise(owner,ms,pose) ('wave' or 'cup'), bot.lower(owner,ms) (only the owner that raised it lowers it), bot.handSide (read)
//   actions  bot.setState(name), bot.emote(name,ms), bot.greet(), bot.interruptGreet() (a greeting in progress lets go), bot.click(),
//            bot.squash(), bot.roll(ms,turns), bot.emit(type,n) (returns the new particles), bot.zz(n) (sleepy z beside the head),
//            bot.sound(name) (a sound event)
//   other    bot.look {x,y}, bot.mini, bot.state and bot.cfg (its STATES entry, read), bot.palette (PALETTE's shape: recolours body,
//            belly and wings), bot.physDx/physDy and physVx/physVy (the lag spring for things hanging off the head, -1..1);
//            page options a capture() may set: bot.bg (dark backdrop), bot.mini
// Also on Koru: G (geometry), K (eye and ink colours), STATES, EMOTES, Clock, params, NOW, rand, the easing and colour helpers;
// drawing helpers drop/inner (soft shadow and inner light), grainOn (velvet grain), sheet/stamp (cache shading that depends only on
// a shape: draw it once, stamp it every frame), floorPool, bodyW, beakPath/beakFinish (the beak's shape and finish), rr.
// Registries open to features: Koru.EMOTES (with run(bot,ms)), Koru.eyeShapes[name](bot,e),
// Koru.particles[type](x,sz,p), Koru.actions[name](bot) (for ?film=<name>).
const features=[], eyeShapes={}, particles={}, actions={};
// A sleepy z (a feature may draw its own in its place).
particles.z=(x,sz)=>{ const w=sz*.5; x.strokeStyle='rgb(206,236,246)'; x.shadowColor='rgba(120,215,240,.8)'; x.shadowBlur=sz*.6; x.lineWidth=sz*.28; x.lineCap=x.lineJoin='round';
  x.beginPath(); x.moveTo(-w,-w); x.lineTo(w,-w); x.lineTo(-w,w); x.lineTo(w,w); x.stroke() };
const MODS=()=>({ox:0,oy:0,sx:1,sy:1,rot:0,headY:0,headTilt:0,es:1,eye:null,lookX:0,lookY:0,flap:0});   // flap: resting wings swing out (radians)
function register(f){ features.push(f); for(const b of Bot.all) f.init&&f.init(b); for(const k in f.actions||{}) actions[k]=f.actions[k]; return f }
const each=(name,...a)=>{ for(const f of features) if(f[name]) f[name](...a) };

class Bot{
  // px: canvas size in CSS px. frame: Koru's size in it (1 = the target framing; less leaves room for hats, hops and squash).
  constructor(canvas,{mini=false,px,frame=1,bg=false}){
    this.c=canvas; this.x=canvas.getContext('2d'); this.mini=mini; this.frame=frame; this.bg=bg; this.m=MODS(); this.timers={};
    this.greetTok=0; this.waveStart=this.waveUntil=0; this.handOwner=null; this.handSide=-1; this.handPose='wave';
    this.physDx=0; this.physDy=0; this.physVx=0; this.physVy=0; this.prevYaw=0; this.prevOy=0; this.prevRoll=0;
    this.s={yaw:0,pitch:0,roll:0,auraA:0,tilt:0,open:1,sx:1,sy:1,oy:0,ox:0,tint:0,hands:0,blush:0,es:1,badgeS:0,ear:0,go:.3,hy:0};
    this.tg={...this.s}; this.tw=[]; this.lock={};
    this.col=hexRgb(STATES.idle.col); this.colT=this.col.slice();
    this.state='idle'; this.cfg=STATES.idle; this.eyeOv=null; this.ovUntil=0; this.badge=null; this.badgeCol='#fff'; this._bk='none'; this._bt=0;
    this.parts=[]; this.nextBlink=NOW()+1500+rand()*2000; this.look={x:0,y:0}; this.t0=NOW()-(Clock.virtual?0:rand()*5000); this.lastAmb=0; this.last=NOW();
    const dpr=Clock.virtual?1:Math.min(2,window.devicePixelRatio||1); canvas.width=canvas.height=px*dpr;
    Bot.all.push(this); for(const f of features) f.init&&f.init(this);
  }
  anim(p,keys,after){ this.tw=this.tw.filter(t=>t.p!==p); this.tw.push({p,keys,i:0,from:this.s[p],t0:NOW(),after}); this.lock[p]=1 }
  // stop(p) drops the tween on p (and its after-callback) where it is; set(p,v) also jumps p and its target to v.
  stop(p){ this.tw=this.tw.filter(t=>t.p!==p); delete this.lock[p] }
  set(p,v){ this.stop(p); this.s[p]=this.tg[p]=v }
  tweening(p){ return !!this.lock[p] }
  setState(n,force){ if(!STATES[n])return; if(this.state===n&&!force)return; const prev=this.state; this.state=n; const c=this.cfg=STATES[n];
    this.colT=hexRgb(c.col); this.setBadge(this.badgeFor(n));
    if(n==='finished'){ this.roll(950,1); this.after('sparks',500,()=>this.emit('spark',5)) }   // BotEngine.swift:322-326
    else if(n==='error'){ this.anim('ox',[[.08,50,E.out],[-.08,70,E.inOut],[.05,70,E.inOut],[0,90,E.out]]) }
    else if(n==='approval'){ this.anim('oy',[[-.2,150,E.out],[0,300,E.back]]) }
    else if(n==='dizzy'){ this.roll(1300,2) }                                                  // BotEngine.swift:339-340
    else if(n==='question'){ this.blink() }
    else if(n==='ratelimit'){ this.emit('sweat',1) }
    else if(prev!=='idle'||n!=='idle') this.blink();
    if(c.sound) this.sound(c.sound);
    each('onState',this,prev,n);
  }
  setBadge(b){ const key=b?b[0]+b[1].join():'none'; if(key===this._bk)return; this._bk=key; const tok=++this._bt;
    this.anim('badgeS',[[0,90,E.inOut]]); Clock.later(()=>{ if(tok!==this._bt)return; this.badge=b?b[0]:null; this.badgeCol=b?b[1]:null; if(b) this.anim('badgeS',[[1,280,E.back]]) },100) }
  // One pending timer per key: a newer call replaces the older one, so fast clicks never stack stale callbacks.
  after(key,ms,fn){ this.cancel(key); this.timers[key]=Clock.later(()=>{ delete this.timers[key]; fn() },ms) }
  cancel(key){ Clock.cancel(this.timers[key]); delete this.timers[key] }
  // Eyes shown over the state's for ms (an emote's); a newer one replaces it, and a pending yawn no longer closes it.
  override(eye,ms){ this.cancel('yawn'); this.eyeOv=eye; this.ovUntil=NOW()+ms }
  clearOverride(){ this.cancel('yawn'); this.eyeOv=null }
  blink(){ if(this.lock.open)return; this.anim('open',[[.06,70,E.inOut],[1,130,E.out]]) }   // BotEngine.swift:374-380
  blinkIn(ms){ this.nextBlink=NOW()+ms }
  // A sound event (a file name of Koncluí's set); the sounds feature plays it, captures stay silent.
  sound(name){ each('onSound',this,name) }
  // BotEngine.swift doRoll() 526-533: Koru turns over whole (turns, eased in and out) and squashes on landing.
  roll(ms,turns){ this.set('roll',this.s.roll%1); this.anim('roll',[[this.s.roll+turns,ms,E.inOut]],()=>{ this.set('roll',0); this.squash() }) }   // a roll during a roll goes on forward
  squash(){ this.physVy+=.6; this.anim('sy',[[.78,70,E.out],[1.1,130,E.out],[1,170,E.inOut]]); this.anim('sx',[[1.16,70,E.out],[.95,130,E.out],[1,170,E.inOut]]) }   // BotEngine.swift:382-394
  // The near wing (the side facing us) rises for one owner at a time; only that owner lowers it, so a greeting
  // ending never drops the wing listening raised. raise() returns false while another owner holds it.
  // pose: 'wave' swings it up over the shoulder and turns it over; 'cup' holds it beside the head, as a hand to the ear.
  // A wing already up in the other pose comes down first (150 ms) and rises again in the new one, so it never jumps.
  raise(owner,ms=280,pose='wave'){ if(this.handOwner&&this.handOwner!==owner) return false; this.handOwner=owner;
    const up=()=>{ if(this.s.hands<.05) this.handSide=this.s.yaw>0?-1:1; this.handPose=pose; this.anim('hands',[[1,ms,E.out]]) };
    if(this.handPose!==pose&&this.s.hands>.05) this.anim('hands',[[0,150,E.inOut]],up); else up(); return true }
  lower(owner,ms=200){ if(this.handOwner!==owner) return false; this.handOwner=null; this.anim('hands',[[0,ms,E.inOut]]); return true }
  // The greeting of BotEngine.swift greet() 567-623: happy eyes for 2 s and a hop; at 0.25 s the near wing rises with a small
  // squash, waves from 0.45 to 1.55 s while the head sways (1001-1005), blinks at 0.55 and 1.5 s, and folds at 1.55 s.
  greet(){ const tok=++this.greetTok, now=NOW(), at=(ms,fn)=>this.after('greet'+ms,ms,()=>{ if(tok===this.greetTok) fn() }); this.sound('greet');
    if(now>=this.waveStart&&now<this.waveUntil) this.waveUntil=now+1550;   // already waving: the wave goes on, longer
    else { this.waveStart=now+450; this.waveUntil=now+1550 } this.physVx+=.2;
    this.override('happy',2050); this.anim('oy',[[-.06,220,E.out],[0,220,E.back]]);
    at(250,()=>{ if(!this.raise('greet')){ this.waveUntil=0; return }
      this.anim('sy',[[.95,100,E.out],[1,260,E.back]]); this.anim('sx',[[1.04,100,E.out],[1,260,E.back]]) });
    at(550,()=>this.blink()); at(1500,()=>this.blink());
    at(1550,()=>{ this.waveUntil=0; this.lower('greet') }) }
  interruptGreet(){ if(this.handOwner!=='greet'&&NOW()>=this.waveUntil) return; this.greetTok++; this.waveUntil=Math.min(this.waveUntil,NOW()+150); this.lower('greet',150) }   // the wave fades out as the wing comes down
  // An update waiting: a blue arrow badge while idle or asleep (BotEngine.swift setUpdateHint()).
  setUpdateHint(on){ if(on===!!this.updateHint) return; this.updateHint=on; this.setBadge(this.badgeFor(this.state)); if(on) this.blink() }
  badgeFor(n){ return this.updateHint&&(n==='idle'||n==='sleeping')?['arrow',['#5B9BFF','#3B82F6']]:STATES[n].badge }
  emote(n,d){ const em=EMOTES[n]; if(!em)return; d=d??em.ms??1800; const hold=k=>Math.max(0,d-k); this.override(em.eye,d); if(em.sound) this.sound(em.sound);
    if(n==='love'){ this.anim('blush',[[1,300,E.out],[1,hold(600),E.lin],[0,300,E.inOut]]); this.emit('heart',4); this.anim('oy',[[-.1,160,E.out],[0,300,E.back]]) }
    if(n==='surprised'){ this.anim('oy',[[-.3,140,E.out],[0,380,E.back]]); this.anim('es',[[1.25,120,E.out],[1,500,E.inOut]]); this.anim('ear',[[-.35,120,E.out],[0,500,E.inOut]]) }
    if(n==='proud'){ this.squash(); this.emit('star',5); this.anim('tilt',[[-.14,220,E.out],[-.14,hold(500),E.lin],[0,280,E.inOut]]); this.anim('blush',[[.7,250,E.out],[.7,hold(500),E.lin],[0,300,E.inOut]]) }   // BotEngine.swift:813-826
    if(n==='wink'){ this.anim('tilt',[[.12,160,E.out],[.12,hold(400),E.lin],[0,240,E.inOut]]) }
    if(n==='yawn'){ this.anim('sy',[[1.12,500,E.inOut],[1,500,E.inOut]]); this.anim('sx',[[.94,500,E.inOut],[1,500,E.inOut]]); this.after('yawn',700,()=>{ this.eyeOv='closed'; this.zz(2) }) }   // BotEngine.swift:832-843
    if(n==='happy'){ this.anim('blush',[[.6,200,E.out],[0,600,E.inOut]]) }
    if(em.run) em.run(this,d);
  }
  click(){ for(const f of features) if(f.onClick&&f.onClick(this)) return; this.squash(); this.emote('happy',900) }
  // z drift up and to the side of the head, slower than the other particles.
  zz(n){ for(const p of this.emit('z',n)) Object.assign(p,{x:.3+rand()*.25,y:-.85,vx:.1+rand()*.1,vy:-(.18+rand()*.06),life:1.6}) }
  emit(type,n){ const ps=[]; for(let i=0;i<n;i++) ps.push({type,x:(rand()-.5)*.9,y:-.85-rand()*.2,vx:(rand()-.5)*.35,vy:-(.45+rand()*.35),age:-i*.14,life:1.3+rand()*.5,rot:rand()*6,sz:.13+rand()*.07});
    this.parts.push(...ps); return ps }
  update(){
    const n=NOW(), dt=Math.min(.05,(n-this.last)/1000); this.last=n; const s=this.s, tg=this.tg, c=this.cfg, t=(n-this.t0)/1000;
    // An after-callback may start or drop tweens: ones dropped meanwhile are skipped, and a finished one is removed by identity.
    for(const tw of [...this.tw]){ if(!this.tw.includes(tw)) continue; const k=tw.keys[tw.i]; const p=k[1]>0?clamp((n-tw.t0)/k[1],0,1):1; s[tw.p]=tw.from+(k[0]-tw.from)*k[2](p);
      if(p>=1){ tw.from=k[0]; tw.i++; tw.t0=n; if(tw.i>=tw.keys.length){ this.tw.splice(this.tw.indexOf(tw),1); delete this.lock[tw.p]; tg[tw.p]=k[0]; if(tw.after) tw.after() } } }
    let ty=this.look.x*.62, tp=this.look.y*.5;
    if(c.look){ ty=ty*.3+c.look[0]*.62*.7; tp=tp*.3+c.look[1]*.5*.7 }
    if(c.scan){ ty=Math.sin(t*2.6)*.6; tp=-.06 }
    if(this.state==='sleeping'){ ty=.2; tp=-.14 }          // Swift looks ahead (0); the sleeping target has her turned a little
    if(this.state==='dizzy') ty=Math.sin(t*9)*.25;          // BotEngine.swift:934
    tg.yaw=ty; tg.pitch=tp; tg.tilt=c.tilt||0; tg.hy=c.hy||0; tg.ear=c.ear||0; tg.tint=c.tint; tg.go=c.go; tg.auraA=c.aura?1:0;
    tg.oy=(c.dy||0)+(c.bounce?-Math.abs(Math.sin(t*5.2))*.07:0);   // BotEngine.swift:1007
    const br=c.breathe?Math.sin(t*1.8)*(this.mini?.07:.035):0; tg.sy=(c.sq||1)*(1+br); tg.sx=1-br*.57;   // BotEngine.swift:1012
    if(n>=this.waveStart&&n<this.waveUntil) tg.tilt=this.handSide*(-.06+Math.sin(2*Math.PI*1.2*(n-this.waveStart)/1000)*.07);   // BotEngine.swift:1001-1005
    for(const f of features) if(f.target) f.target(this,tg,t);
    const kLook=1-Math.pow(.0025,dt), kGen=1-Math.pow(.0008,dt);
    for(const k in tg){ if(this.lock[k])continue; s[k]+=(tg[k]-s[k])*((k==='yaw'||k==='pitch')?kLook:kGen) }
    this.col=mix(this.col,this.colT,1-Math.pow(.002,dt));
    if(n>this.nextBlink){ let gap=null;   // captures skip blinks, so stills never catch one mid-way
      if(this.state!=='sleeping'&&this.state!=='dizzy'&&!Clock.virtual){ for(const f of features) if(f.blink&&(gap=f.blink(this))!=null) break;
        if(gap==null){ this.blink(); if(rand()<.22) this.after('blink2',230,()=>this.blink()) } }
      this.nextBlink=n+(gap??2200+rand()*3200) }   // BotEngine.swift:1054
    if(this.eyeOv&&n>this.ovUntil) this.eyeOv=null;
    if(n-this.lastAmb>1300){ this.lastAmb=n; if(c.zz) this.zz(1); if(!this.mini&&c.sweat&&rand()<.5) this.emit('sweat',1) }   // BotEngine.swift:1063-1068 (z on minis too)
    for(const p of this.parts) p.age+=dt; this.parts=this.parts.filter(p=>p.age<p.life);
    if(dt>0){ const yawVel=(s.yaw-this.prevYaw)/dt, oyVel=(s.oy-this.prevOy)/dt, rollVel=(s.roll-this.prevRoll)*Math.PI*2/dt; this.prevYaw=s.yaw; this.prevOy=s.oy; this.prevRoll=s.roll;
      const tDx=clamp(-yawVel*.35-s.tilt*2+rollVel*.18,-1,1), tDy=clamp(oyVel*.5,-1,1);   // a roll flings what hangs off the head (BotEngine.swift:1093-1097)
      this.physVx+=(60*(tDx-this.physDx)-9*this.physVx)*dt; this.physVy+=(60*(tDy-this.physDy)-9*this.physVy)*dt;
      this.physDx+=this.physVx*dt; this.physDy+=this.physVy*dt }
    this.m=MODS(); for(const f of features) if(f.update) f.update(this,dt,t);
    for(const f of features) if(f.modify) f.modify(this,this.m,t);
  }
  // Draw hooks run inside save/restore, in the transform of the place they are named after.
  layer(name,d){ for(const f of features){ const L=f.layers&&f.layers[name]; if(L){ this.x.save(); try{ L(this,d) } finally { this.x.restore() } } } }
  draw(){
    const x=this.x, W=this.c.width, H=this.c.height, s=this.s, m=this.m, t=NOW()/1000, full=!this.mini, P=this.palette||PALETTE;
    x.clearRect(0,0,W,H);
    if(this.bg){ x.fillStyle='#101115'; x.fillRect(0,0,W,H); x.save(); x.globalCompositeOperation='soft-light'; x.globalAlpha=.07; x.fillStyle=grainPattern(x); x.fillRect(0,0,W,H); x.restore() }
    const R=W*.3*this.frame, rx=R*G.rx, ryB=R*G.ryBot, ryT=R*G.ryTop;
    const cx=W/2+(s.ox+m.ox)*R, cy=H/2+(G.cy+s.oy+m.oy)*R;
    const sxE=s.sx*m.sx, syE=s.sy*m.sy;
    const col=this.col, glowA=s.go, tint=s.tint;
    const cool=clamp((col[2]-col[0])/255+.3,0,1);          // blue-ish states also tint the lower body
    const yawN=clamp(s.yaw/.62,-1,1), pitN=clamp(s.pitch/.5,-1,1);
    const f=Math.sin(s.yaw)*G.face, fx=f*R;                // head turn, in R and in px
    // floor glow: a saturated band where the body meets the floor, and a wider pool
    const lit=1+.9*Math.max(0,tint-.3);                     // a lit state (tint > .3) glows harder than idle
    const upright=(1+Math.cos(s.roll*Math.PI*2))/2;           // the light from below fades while a roll turns her over
    for(const [k,sk,r0,a0] of [[1.0,.09,1.15,.7],[1.02,.16,1.4,.35]]){ const a=a0*glowA*lit, r=r0*(1+.2*(lit-1));
      floorPool(x,cx,cy+ryB*syE*k,rx*r,sk,[[0,rgba(mix(col,[255,255,255],.1),clamp(a,0,1))],[.4,rgba(col,clamp(.5*a,0,1))],[.75,rgba(col,.12*a)],[1,rgba(col,0)]]) }
    // The head transform from the body's space (draw hooks: d.head), and where the beak sits in it (d.beakAt, px). The head
    // turns rigidly: the body's squash is undone around the turn, so a tilted head is never sheared (no stretched tuft).
    const head=new DOMMatrix().translate(0,(s.hy+m.headY)*R-R*.15).scale(1/sxE,1/syE).rotate((s.tilt+m.headTilt)*180/Math.PI).scale(sxE,syE).translate(0,R*.15);
    // d: what draw hooks get. Coordinates in R units are from the body centre, as everywhere above.
    const d={x,R,W,H,s,m,t,full,mini:this.mini,cx,cy,rx,ryB,ryT,col,tint,yawN,pitN,f,fx,sx:sxE,sy:syE,head,beakAt:{x:fx*1.08,y:R*.096}};
    this.layer('floor',d);

    // Squash keeps the base on the floor. Full size, the body sits on whole pixels, so its cached shading lines up with its edge.
    const by=cy+ryB*(1-syE); x.save(); full?x.translate(Math.round(cx),Math.round(by)):x.translate(cx,by);
    if(s.roll) x.rotate(s.roll*Math.PI*2);                 // a roll turns everything on the body round its centre
    if(m.rot){ x.translate(0,ryB); x.rotate(m.rot); x.translate(0,-ryB) }
    x.scale(sxE,syE);
    const body=d.body=bodyPath(R,rx), BB=[-rx,-ryT,rx,ryB];                // BB: body bounds for the shading helpers
    const SB=[-rx-2,-ryT-2,rx+2,ryB+2], HB=[-rx-R*.6,-ryT-R*.6,rx+R*.6,ryB+R*.6];   // sheet boxes: the body, and its halo
    const C1=[-R/.6,-R/.6-G.cy*R,R/.6,R/.6-G.cy*R];                 // the canvas at frame 1, which limits the body's widest shading
    if(full){ // bloom: the state colour from below only (its mask fades out above the belly), then a faint cyan halo all round
      if(tint>.3) stampTint(x,sheet('bloom'+R,HB,g=>{ drop(g,body,'#fff',R*.24,0,R*.07); g.globalCompositeOperation='destination-out';
        const fade=g.createLinearGradient(0,R*.3,0,-R*.15); fade.addColorStop(0,'rgba(0,0,0,0)'); fade.addColorStop(1,'#000'); g.fillStyle=fade; g.fillRect(HB[0],HB[1],HB[2]-HB[0],R*.3-HB[1]) }),rgba(col,Math.min(1,1.15*(tint-.3))*upright));
      stamp(x,sheet('halo'+R,HB,g=>{ drop(g,body,'rgba(40,170,200,.12)',R*.08,0,R*.05); drop(g,body,'rgba(30,150,180,.14)',R*.2,0,R*.11) })) }
    // wings: the far one (the side the head turns to) folds back behind the body; the near one rises and waves
    const wings=[], now=NOW(), wt=(now-this.waveStart)/1000, side=this.handSide, wingLine=d.wings=new Path2D();
    // BotEngine.swift:1235-1257: the wave eases in over 0.18 s from its start (and out over its last 0.15 s here)
    const wave=now>=this.waveStart&&now<this.waveUntil?Math.min(E.out(Math.min(1,wt/.18)),clamp((this.waveUntil-now)/150,0,1)):0;
    for(const sd of[-1,1]){ const far=clamp(sd*yawN,0,1); let lift=sd===side?s.hands:0; if(sd===side&&wave) lift+=Math.sin(wt*13)*.17*wave*Math.min(1,s.hands); wings.push({sd,far,lift,base:sd===side?s.hands:0,cup:sd===side&&this.handPose==='cup',sway:sd!==side&&wave?Math.sin(6*wt)*.07*wave:0}) }   // the other wing sways (BotEngine.swift:1261-1263)
    // The wing's transform in the body's space; shapes are drawn for the left side.
    const wingM=({sd,far,lift,cup,sway},over)=>{ const D=180/Math.PI;
      let M=new DOMMatrix().scale(-sd,1).translate(0,R*.15*far).translate(-R*1.42,0).scale(1-.25*far,1).translate(R*1.42,0);
      if(m.flap||sway) M=M.translate(-R*1.05,-R*.05).rotate((m.flap+sway)*D).translate(R*1.05,R*.05);
      const L=Math.min(clamp(lift,0,1.3),1);
      if(cup) return M.translate(-R*1.1,-R*.05).translate(R*.07*L,-R*.47*L).rotate(-.2*L*D).scale(1,1+.12*L).translate(R*1.1,R*.05);   // up beside the head, its top flaring out
      // Raising: the wing swings up from its root and turns over (over: 1 before, -1 after); it never goes edge-on. Raised high
      // at the shoulder, waving between ~50° and upright; pulled in while it sweeps through the horizontal, so it never leaves the canvas.
      const k=Math.cos(Math.PI*smooth(clamp(lift/.45,0,1)));
      return M.translate(-R*1.1,-R*.05).translate(-R*.06*L+R*.2*(1-Math.abs(k))+R*1.2*L*(1-L),-R*.2*L)
        .rotate(lift*2.78*D).scale(over*Math.max(.3,over*k),1).translate(R*1.1,R*.05) };
    const at=(M,u,v)=>M.transformPoint({x:u*R,y:v*R}), dir=(p,q)=>Math.atan2(q.y-p.y,q.x-p.x);
    // Raised (turned over), the wing is also flipped top to bottom about its centre, so the feather tips point up; the wave then
    // turns it round the shoulder at its base, so the shoulder stays put and the tips swing.
    const wingT=(w,over)=>{ let M=wingM(w,over);
      if(over<0&&!w.cup){ const M0=wingM({...w,lift:w.base},over), c=at(M0,-1.2,.23), e=at(M0,-1.11,.55), sh={x:e.x,y:2*c.y-e.y};   // sh: the flipped wing's base
        const turn=dir(at(M,-1.1,-.05),at(M,-1.1,.55))-dir(sh,at(M0,-1.1,.55));
        M=new DOMMatrix().translate(sh.x,sh.y).rotate(turn*180/Math.PI).translate(-sh.x,-sh.y).translate(c.x,c.y).scale(1,-1).translate(-c.x,-c.y).multiply(M0) }
      x.transform(M.a,M.b,M.c,M.d,M.e,M.f); return M };
    // While it turns over, its two faces cross-fade; otherwise one is drawn.
    const drawWing=(w,front)=>{ const wing=wingPath(R), k=Math.cos(Math.PI*smooth(clamp(w.lift/.45,0,1))), v=w.cup?0:smooth(clamp((.25-k)/.5,0,1));
      for(const over of [1,-1]){ const a=over>0?1-v:v; if(a<.01) continue; x.save(); x.globalAlpha*=a;
        const mx=-w.sd*over, my=over, WB=[-R*1.45,-R*.16,-R*.94,R*.6];   // mx, my: how the wing's x and y map to the screen's (light from the top right)
        if(full&&front){ x.save(); x.clip(body); wingT(w,over); stamp(x,sheet('wingShadow'+R+mx+my,[WB[0]-R*.3,WB[1]-R*.3,WB[2]+R*.3,WB[3]+R*.3],g=>drop(g,wing,'rgba(1,22,27,.45)',R*.12,R*.02*mx,R*.035*my))); x.restore() }
        wingLine.addPath(wing,wingT(w,over));
        const wg=x.createLinearGradient(-R*1.3,-R*.1,-R*1.0,R*.56); wg.addColorStop(0,P.wing[0]); wg.addColorStop(1,P.wing[1]);
        x.fillStyle=wg; x.fill(wing);
        if(full) stamp(x,sheet('wing'+R+mx+my,[WB[0]-2,WB[1]-2,WB[2]+2,WB[3]+2],g=>{ inner(g,wing,'rgba(80,200,220,.6)',R*.025,R*.008*mx,R*.018*my,WB); inner(g,wing,'rgba(0,20,25,.35)',R*.06,-R*.03*mx,0,WB) },R*.2));
        x.restore() } };
    this.layer('behind',d);
    // A wing goes behind the body as it folds back (the front copy fades) or rises (past lift .6 the front copy goes in one frame).
    for(const w of wings) if(w.far>.35||(w.lift>.02&&!w.cup)) drawWing(w,false);
    // body: key light from the top right
    { const kx=R*.18+fx*.2, ky=-R*.92;                    // an elliptical gradient: fill in a stretched space
      x.save(); x.translate(kx,ky); x.scale(1.5,1);
      const bg=x.createRadialGradient(0,0,0,0,0,R*1.45); bg.addColorStop(0,P.body[0]); bg.addColorStop(.12,P.body[1]); bg.addColorStop(.3,P.body[2]); bg.addColorStop(.56,P.body[3]); bg.addColorStop(1,P.body[4]);
      const bp=new Path2D(); bp.addPath(body,new DOMMatrix().scale(1/1.5,1).translate(-kx,-ky)); x.fillStyle=bg; x.fill(bp); x.restore() }
    if(full){ grainStamp(x,body,grainSheet('body'+R,SB,-ryT,R*.2),.62);   // velvet grain, mostly on the dome
      stamp(x,sheet('shade'+R,SB,g=>inner(g,body,'rgba(4,48,56,.38)',R*.4,0,-R*.12,BB),R,C1));   // sides and base turn away; the top stays lit
      x.save(); x.clip(body); const vs=x.createRadialGradient(fx,-R*.45,0,fx,-R*.45,R*.38); vs.addColorStop(0,'rgba(0,62,72,.22)'); vs.addColorStop(1,'rgba(0,62,72,0)'); x.fillStyle=vs; x.fillRect(-R,-R*1.1,R*2,R*1.3); x.restore() }
    // belly, fading into the body at the bottom
    x.save(); x.clip(body);
    const belly=d.belly=new Path2D(); belly.ellipse(fx*.75,R*.94,R*.532,R*.52,0,0,Math.PI*2);
    const blg=x.createLinearGradient(0,R*.42,0,ryB); blg.addColorStop(0,P.belly[0]); blg.addColorStop(.75,P.belly[1]); blg.addColorStop(1,P.belly[2]);
    x.fillStyle=blg; x.fill(belly);
    // bounce light at the base, and blue-ish states tint the lower body
    const bl=x.createLinearGradient(0,ryB,0,ryB-R*.1); bl.addColorStop(0,rgba(mix([60,180,200],col,Math.min(1,.9*tint)),.3+.2*tint)); bl.addColorStop(1,'rgba(70,195,210,0)');
    x.fillStyle=bl; x.fillRect(-rx,ryB-R*.1,rx*2,R*.14);
    if(!this.palette){ const rl=x.createLinearGradient(-rx,0,rx,0); rl.addColorStop(.45,'rgba(40,150,165,0)'); rl.addColorStop(1,'rgba(40,150,165,.16)'); x.fillStyle=rl; x.fillRect(-rx,-R*.2,rx*2,ryB+R*.2) }   // teal side light: Koru's own colours only
    x.restore();
    if(full) grainStamp(x,belly,grainSheet('belly'+R,[-R*.72,R*.38,R*.72,ryB+2],R*.4,ryB),.17);
    if(tint>.3){ x.save(); x.clip(body); x.globalCompositeOperation='screen';  // state light shining through the lower body
      const lt=x.createLinearGradient(0,ryB,0,ryB-R*.6); lt.addColorStop(0,rgba(col,.4*tint*(.45+.55*cool))); lt.addColorStop(1,rgba(col,0)); x.fillStyle=lt; x.fillRect(-rx,ryB-R*.6,rx*2,R*.65);
      x.restore() }
    if(full){ stamp(x,sheet('rims'+R,SB,g=>{ inner(g,body,'rgba(190,240,248,.95)',R*.06,0,R*.035,BB);   // rim light hugging the top edge
        inner(g,body,'rgba(214,248,252,.6)',R*.02,0,R*.01,BB);
        g.save(); g.clip(body); const sh=new Path2D(); sh.ellipse(R*.16,-R*.92,R*.29,R*.08,0,0,Math.PI*2); drop(g,sh,'rgba(220,248,251,.38)',R*.08); g.restore();   // broad soft sheen, no hard spot
        inner(g,body,'rgba(70,190,215,.7)',R*.09,-R*.06,0,BB);                    // wide cyan rims, stronger on the lit right
        inner(g,body,'rgba(65,172,200,.55)',R*.08,R*.05,0,BB) },R*.3,C1));
      // state light: a soft rim along the bottom and lower sides in the state colour
      // (a band of light on the lower half, not an outline: a wide pass, and a narrower one for the brighter bottom edge)
      const lower=g=>{ g.globalCompositeOperation='destination-in'; const v=g.createLinearGradient(0,0,0,R*.65); v.addColorStop(0,'rgba(0,0,0,0)'); v.addColorStop(1,'#000'); g.fillStyle=v; g.fillRect(SB[0],SB[1],SB[2]-SB[0],SB[3]-SB[1]) };
      stampTint(x,sheet('state1'+R,SB,g=>{ inner(g,body,'#fff',R*.15,0,-R*.08,BB); lower(g) },R*.4,C1),rgba(col,Math.min(1,.08+1.2*Math.max(0,tint-.2))*upright));
      if(tint>.3) stampTint(x,sheet('state2'+R,SB,g=>{ inner(g,body,'#fff',R*.05,0,-R*.03,BB); lower(g) },R*.25,C1),rgba(mix(col,[255,255,255],.1),.9*(tint-.3)/.7*upright)) }
    this.layer('body',d);
    for(const w of wings){ const a=(1-smooth(clamp((w.far-.35)/.3,0,1)))*(w.cup||w.lift<.6?1:0); if(a>.01){ x.save(); x.globalAlpha=a; drawWing(w,true); x.restore() } }   // a cupped wing stays in front
    this.layer('wings',d);

    // head: lower in busy states, tilts around the neck, the body stays on the floor
    x.save(); x.transform(head.a,head.b,head.c,head.d,head.e,head.f);
    const ex=G.eyeSp, ey=R*G.eyeY, shape=this.eyeOv||m.eye||this.cfg.eye;
    // d.eyes: each orange disc in the head's space (px): centre x,y, radius r, and its kx,ky squeeze for the head turn
    d.eyes=[-1,1].map(sd=>{ const far=Math.max(0,sd*yawN), near=Math.max(0,-sd*yawN);
      return {sd,far,x:sd*ex*R+fx-R*.013*Math.abs(yawN),y:ey,r:R*G.disc*(shape==='wide'?1.04:1)*s.es*m.es,kx:1+.057*near-.085*far,ky:1-far*.015} });
    this.layer('headBack',d);
    const face=new Path2D(), tufts=new Path2D(), tuftBoxes=[], badgeFold=this.cfg.fold?s.badgeS:0, FB=[-R*1.4,-R*1.3,R*1.4,R*.55];
    for(const sd of[-1,1]){ const far=Math.max(0,sd*yawN), near=Math.max(0,-sd*yawN);
      face.addPath(toPath(ringPts(sd*ex+f,G.eyeY,G.ring,1-.16*far+.07*near,sd,.05,.15+.1*far),R));   // a light pull keeps the rings round under the beak
      face.addPath(outline(mirror(browSegs(-f*sd,far),-sd),R));          // left-side shapes, mirrored for sd = 1
      face.addPath(toPath([[f+sd*.002,-.247],[f+sd*.05,-.272],[f+sd*.035,-.205],[f,-.215]],R));   // closes the sliver under the V tip, between brow and rings
      const tp=mirror(tuftPts(-f*sd*.15,s.ear+(sd<0?.55*badgeFold:0),far),-sd), tf=blob(tp,R); tufts.addPath(tf); face.addPath(tf);
      tuftBoxes.push({tf,box:[Math.min(...tp.map(q=>q[0]))*R,Math.min(...tp.map(q=>q[1]))*R,Math.max(...tp.map(q=>q[0]))*R,Math.max(...tp.map(q=>q[1]))*R]}) }
    d.face=face; d.tufts=tufts;
    if(full) drop(x,tufts,'rgba(2,40,46,.35)',R*.05,0,R*.035);
    const dg=x.createLinearGradient(0,-R*1.15,0,ey+R*G.ring); dg.addColorStop(0,'#40B2BF'); dg.addColorStop(.35,'#4EBBC3'); dg.addColorStop(1,'#2E9FAB');
    x.fillStyle=dg; x.fill(face);
    if(full){ x.save(); x.clip(face);                                  // light from the right, a soft clay tuft
      const lr=x.createLinearGradient(-R*1.2,0,R*1.2,0); lr.addColorStop(0,'rgba(255,255,255,0)'); lr.addColorStop(1,'rgba(200,245,250,.1)'); x.fillStyle=lr; x.fillRect(-R*1.5,-R*1.5,R*3,R*2.5);
      x.restore();
      x.save(); x.clip(tufts);
      for(const sd of[-1,1]){ const tx=-sd*1.08*R+fx*.15, tg=x.createRadialGradient(tx,-R*1.1,0,tx,-R*1.1,R*.32); tg.addColorStop(0,'rgba(80,200,218,.4)'); tg.addColorStop(1,'rgba(80,200,218,0)'); x.fillStyle=tg; x.fillRect(tx-R*.4,-R*1.45,R*.8,R*.7);
        const lx=-sd*1.12*R+fx*.15, lg=x.createRadialGradient(lx,-R*.72,0,lx,-R*.72,R*.22); lg.addColorStop(0,'rgba(80,200,218,.3)'); lg.addColorStop(1,'rgba(80,200,218,0)'); x.fillStyle=lg; x.fillRect(lx-R*.3,-R*1.0,R*.6,R*.6) }
      const ts=grainSheet('tufts'+R,[-R*1.45,-R*1.4,R*1.45,-R*.35],-R*1.2,-R*.5,R*.65,R*.92); for(const {tf,box} of tuftBoxes) grainStamp(x,tf,ts,.45,box);
      inner(x,face,'rgba(175,238,246,.8)',R*.03,0,R*.022,FB); inner(x,face,'rgba(4,50,58,.35)',R*.04,0,-R*.025,FB); x.restore() }
    if(s.blush>.01&&shape!=='happy'){ x.save(); x.clip(face);         // love and proud: a blush on each ring (happy eyes carry their own lines)
      for(const e of d.eyes){ const bx=e.x+e.sd*R*.22, by=ey+R*.43, g=x.createRadialGradient(bx,by,0,bx,by,R*.16);
        g.addColorStop(0,`rgba(255,84,128,${.6*s.blush})`); g.addColorStop(1,'rgba(255,84,128,0)'); x.fillStyle=g; x.fillRect(bx-R*.16,by-R*.16,R*.32,R*.32) }
      x.restore() }
    this.layer('face',d);
    // eyes
    for(const e of d.eyes){ const dr=e.r;
      x.save(); x.translate(e.x,e.y); x.scale(e.kx,e.ky);
      const disc=new Path2D(); disc.arc(0,0,dr,0,Math.PI*2);
      const eg=x.createLinearGradient(0,-dr,0,dr); eg.addColorStop(0,rgba(K.eyeIn,1)); eg.addColorStop(1,rgba(K.eyeEdge,1));
      x.fillStyle=eg; x.fill(disc);
      if(full){ const d0=R*G.disc, k=dr/d0; x.save(); x.scale(k,k);   // shading drawn for the resting disc, scaled with it
        stamp(x,sheet('disc'+R,[-d0-2,-d0-2,d0+2,d0+2],g=>{ const p=new Path2D(); p.arc(0,0,d0,0,Math.PI*2); inner(g,p,'rgba(30,70,80,.16)',R*.035,0,R*.012,[-d0,-d0,d0,d0]) },R*.1)); x.restore() }
      const dc=new Path2D(), dl=dr+R*.005; dc.arc(0,0,dl,0,Math.PI*2); x.save(); x.clip(dc);   // a hair wider than the disc, so a lid covers its antialiased rim
      this.eye(shape,dr,e.sd,yawN,pitN,t,e.far);
      const lid=1-s.open; if(lid>.01){ lidPath(x,dl,lid);   // the lid comes down with a rounded edge and a thin lash line
        const lg=x.createLinearGradient(0,-dr,0,dr*(2*lid-1)); lg.addColorStop(0,'#3FAFBA'); lg.addColorStop(1,'#2E9DA9'); x.fillStyle=lg; x.fill();
        if(lid<.98){ x.strokeStyle='rgba(22,65,73,.55)'; x.lineWidth=R*.016; x.beginPath(); lidEdge(x,dr,lid); x.stroke() } }
      x.restore(); x.restore() }
    // beak: a matte teardrop lit from the right
    x.save(); x.translate(d.beakAt.x,d.beakAt.y);
    const br=R*.125, tip=R*.18, beak=beakPath(br,tip);
    d.br=br; d.tip=tip; d.beak=beak;
    let custom=false; for(const fe of features) if(fe.beak){ x.save(); custom=fe.beak(this,d); x.restore(); if(custom) break }   // first feature to draw the beak wins (script order)
    if(!custom) beakFinish(x,beak,R,full,'closed');
    x.restore();
    this.layer('headFront',d);
    this.layer('headTop',d);                               // above everything on the head (what the beak holds, over hats and glasses)
    x.restore();
    x.restore();

    // badge
    if(this.badge&&s.badgeS>.01){ const bs=s.badgeS*(this.mini?1.25:1), b=this.badge;
      const bo=this.cfg.bo||[0,0], bx2=cx+(-rx*.70+bo[0]*R)*sxE, by2=cy+(-R*.80+bo[1]*R)*syE;
      x.save(); x.translate(bx2,by2); x.rotate(this.cfg.brot||0); x.scale(bs*(this.cfg.bsc||1),bs*(this.cfg.bsc||1));
      const [c0,c1]=this.badgeCol.map(hexRgb), glow=this.mini?0:1;
      const shine=(path,h)=>{ if(!glow) return; x.save(); x.clip(path); const g=x.createLinearGradient(0,-h,0,h*.1); g.addColorStop(0,'rgba(255,255,255,.32)'); g.addColorStop(1,'rgba(255,255,255,0)'); x.fillStyle=g; x.fillRect(-R,-h,R*2,h*1.1); x.restore() };
      const fillGlow=(path,r,bloom)=>{ const g=x.createLinearGradient(0,-r,0,r); g.addColorStop(0,rgba(c0,1)); g.addColorStop(1,rgba(c1,1));
        x.save(); x.shadowColor=rgba(c1,.7); x.shadowBlur=R*bloom*glow; x.fillStyle=g; x.fill(path); x.restore() };
      if(b==='dots'&&this.mini){ const ph=(t*2.4)%1, r=R*.22*(1+.25*Math.sin(ph*Math.PI*2));   // BotEngine.swift:1677-1686
        x.fillStyle='#000'; x.beginPath(); x.arc(0,0,R*.2,0,Math.PI*2); x.fill(); x.fillStyle=rgba(c0,1); x.beginPath(); x.arc(0,0,r*.5,0,Math.PI*2); x.fill() }
      else if(b==='dots'){ const w=R*.58,h=R*.32, pill=new Path2D(); pill.roundRect(-w/2,-h/2,w,h,h/2);
        fillGlow(pill,h/2,.09); shine(pill,h/2);
        for(let i=0;i<3;i++){ const ph=((t*2.4-i*.22)%1+1)%1; const r=R*.04*(1+.4*Math.max(0,Math.sin(ph*Math.PI*2)));   // Swift's pulse (1697) on the target's smaller dots
          x.save(); x.shadowColor='rgba(255,255,255,.6)'; x.shadowBlur=R*.02; x.fillStyle=this.cfg.dot||'#fff'; x.beginPath(); x.arc((i-1)*R*.135,0,r,0,Math.PI*2); x.fill(); x.restore() } }
      else if(b==='bang'||b==='q'){ const r=b==='q'?R*.238:R*.22, dot=new Path2D(); dot.arc(0,0,r,0,Math.PI*2);
        fillGlow(dot,r,.1); shine(dot,r);
        if(!this.mini){ x.save(); x.shadowColor='rgba(120,40,0,.35)'; x.shadowBlur=R*.02; x.shadowOffsetY=R*.01; glyph(x,b,R); x.restore() } }
      else if(b==='arrow'){ const r=R*.22, dot=new Path2D(); dot.arc(0,0,r,0,Math.PI*2); fillGlow(dot,r,.1); shine(dot,r);
        if(!this.mini){ const ph=(t*.8)%1, lift=ph<.25?-Math.sin(ph/.25*Math.PI)*R*.035:0;   // the arrow rises a little now and then
          x.save(); x.strokeStyle='#fff'; x.lineWidth=R*.055; x.lineCap=x.lineJoin='round'; x.beginPath(); x.moveTo(0,R*.12+lift); x.lineTo(0,-R*.11+lift);
          x.moveTo(-R*.09,-R*.02+lift); x.lineTo(0,-R*.11+lift); x.lineTo(R*.09,-R*.02+lift); x.stroke(); x.restore() } }
      else if(b==='ring'){ x.save(); x.shadowColor=rgba(c1,.6); x.shadowBlur=R*.08*glow; x.fillStyle='#060708'; x.beginPath(); x.arc(0,0,R*.11,0,Math.PI*2); x.fill(); x.restore();
        x.fillStyle=rgba(c0,1); x.beginPath(); x.arc(0,0,R*.087,0,Math.PI*2); x.fill() }
      else { const r=R*.15, dot=new Path2D(); dot.arc(0,0,r,0,Math.PI*2); fillGlow(dot,r,.2); fillGlow(dot,r,.08); shine(dot,r) }
      x.restore() }
    // aura
    if(this.cfg.aura) this.aura=this.cfg.aura;              // the last aura fades out with s.auraA after the state changes
    const aura=s.auraA>.01?this.aura:null; x.save(); x.globalAlpha=clamp(s.auraA,0,1);
    if(aura==='spark'&&!this.mini){ const top=cy-R*1.18*syE;
      for(const [ox,oy,sz,ph] of [[-.03,-.09,.17,0],[-.32,.01,.095,1.7],[.2,.04,.095,3.1]]){ const k=.8+.2*Math.sin(t*3+ph);
        x.save(); x.translate(cx+ox*R,top+oy*R); x.scale(k,k); x.fillStyle='#DFFFEE'; x.shadowColor='rgba(70,240,170,.9)'; x.shadowBlur=R*.08; star(x,R*sz,R*sz*.22,4); x.fill(); x.restore() } }
    if(aura==='wobble'&&!this.mini){ x.save(); x.strokeStyle=rgba(col,1); x.lineCap='round'; x.lineWidth=R*.035;
      for(const sd of[-1,1]) for(let i=0;i<2;i++){ x.globalAlpha=.65+.35*Math.sin(t*6+i*1.4+(sd>0?2:0));
        const bx=cx+sd*R*(sd<0?1.2+i*.11:1.31+i*.1), y0=cy+R*(sd<0?-.6:-.42)+i*R*.03, len=R*.28;   // right: in the gap above the wing
        x.beginPath(); x.moveTo(bx,y0); x.quadraticCurveTo(bx+sd*R*.08,y0+len/2,bx,y0+len); x.stroke() }
      x.restore() }
    x.restore();
    // particles
    for(const p of this.parts){ if(p.age<0)continue; const k=p.age/p.life, a=k<.2?k/.2:1-(k-.2)/.8; const px=cx+(p.x+p.vx*p.age)*R*1.3, py=cy+(p.y+p.vy*p.age)*R*1.3; const sz=R*p.sz*(1+k*.4), edge=clamp((py-sz)/(R*.25),0,1);   // fades out before the canvas top
      x.save(); x.translate(px,py); x.globalAlpha=clamp(a,0,1)*edge;
      if(p.type==='heart'){ x.fillStyle='#FF4D6D'; x.rotate(Math.sin(p.age*6)*.3); heart(x,sz); x.fill() }
      else if(p.type==='star'){ x.fillStyle='#F7B32B'; x.rotate(p.rot+p.age*2); star(x,sz,sz*.45); x.fill() }
      else if(p.type==='spark'){ x.fillStyle='#DFFFEE'; x.shadowColor='rgba(70,240,170,.9)'; x.shadowBlur=R*.06; x.rotate(p.rot*.1); star(x,sz*.8*(1-.6*k),sz*.18*(1-.6*k),4); x.fill() }   // shrinks as it fades, near upright, mint glow
      else if(p.type==='sweat'){ x.fillStyle='#7CC7FF'; x.beginPath(); x.moveTo(0,-sz); x.quadraticCurveTo(sz*.8,sz*.2,0,sz*.6); x.quadraticCurveTo(-sz*.8,sz*.2,0,-sz); x.fill() }
      else if(particles[p.type]) particles[p.type](x,sz,p);
      x.restore() }
    this.layer('front',d);
  }
  // Inside one orange eye disc (radius dr), centred on 0,0 and clipped to it.
  eye(shape,dr,sd,yawN,pitN,t,far){ const x=this.x, R=this.c.width*.3*this.frame, ink=K.ink, c=this.cfg;
    const pr=R*G.pupil, reach=dr-pr-R*.02;
    let px=yawN*reach*(c.scan?1.15:.8)*(1-.08*far), py=-pitN*reach*.85-far*R*.02-R*.014;
    if(c.converge) px+=-sd*reach*.35;
    px+=this.m.lookX*reach; py-=this.m.lookY*reach;
    x.fillStyle=ink; x.strokeStyle=ink; x.lineCap='round'; x.lineJoin='round';
    const pupil=(r)=>{ x.save(); x.translate(px,py); x.scale(1-far*.07,1); x.fillStyle=ink; x.beginPath(); x.arc(0,0,r,0,Math.PI*2); x.fill();
      x.shadowColor='rgba(255,245,235,.8)'; x.shadowBlur=R*.012; x.fillStyle='rgb(252,243,237)'; x.beginPath(); x.arc(r*.57,-r*.39,r*.24,0,Math.PI*2); x.fill(); x.restore() };
    const happy=()=>crescent(x,dr*.3,dr*.7,Math.PI*1.1,Math.PI*1.9,dr*.3);   // tapering to points, no round terminals
    switch(shape){
      case 'wide': pupil(pr*1.08); break;
      case 'pill': pupil(pr*(c.pupil||1)); break;
      case 'dot': pupil(pr*.55); break;
      case 'flat': { const w=R*.38,h=R*.11; rr(x,-w/2-sd*R*.07,-h/2+py*.2,w,h,h/2); x.fill(); break }
      case 'line': x.save(); x.rotate(-sd*.25); rr(x,-dr*.5,-R*.05,dr,R*.1,R*.05); x.fill(); x.restore(); break;
      case 'happy': happy();
        x.strokeStyle='rgba(232,112,104,.85)'; x.lineWidth=R*.018; for(let i=0;i<3;i++){ const yy=dr*(.42+i*.12), xo=sd*dr*(.5+i*.05); x.beginPath(); x.moveTo(xo,yy); x.quadraticCurveTo(xo+sd*dr*.12,yy-dr*.02,xo+sd*dr*.2,yy-dr*.1); x.stroke() } break;
      case 'closed': x.save(); x.lineWidth=R*.095; x.beginPath(); x.arc(0,-dr*.18,dr*.58,Math.PI*.2,Math.PI*.8); x.stroke(); x.restore(); break;
      case 'spiral': { x.lineWidth=R*.07; x.beginPath(); let qx=0,qy=0,aa=0; for(let a=0;a<=4*Math.PI;a+=.12){ const r=R*.03+a/(4*Math.PI)*R*.22; aa=a+t*6*sd; qx=Math.cos(aa)*r; qy=Math.sin(aa)*r; a?x.lineTo(qx,qy):x.moveTo(qx,qy) }
        x.lineTo(qx+Math.cos(aa+1.2)*R*.06,qy+Math.sin(aa+1.2)*R*.06); x.stroke(); break }
      case 'heart': x.fillStyle='#FF4D6D'; heart(x,dr*.62); x.fill(); break;
      case 'star': x.save(); x.fillStyle='#F7B32B'; x.rotate(t*1.5*sd); star(x,dr*.6,dr*.27); x.fill(); x.restore(); break;
      case 'tired': pupil(pr); x.fillStyle='#31A3AF'; x.fillRect(-dr,-dr,dr*2,dr*.95); x.fillStyle=ink; rr(x,-dr,-dr*.07,dr*2,R*.05,R*.025); x.fill(); break;
      case 'wink': if(sd<0) pupil(pr); else happy(); break;
      default: if(eyeShapes[shape]) eyeShapes[shape](this,{x,R,dr,sd,px,py,pr,t,far,ink,pupil}); else pupil(pr);
    }
  }
}
Bot.all=[];

window.Koru={params,SHOT,GRID,FILM,Clock,NOW,rand,reseed,clamp,lerp,smooth,E,hexRgb,rgba,mix,K,G,STATES,EMOTES,
  rr,drop,inner,grainOn,sheet,stamp,floorPool,bodyW,beakPath,beakFinish,Bot,register,each,eyeShapes,particles,actions};
})();
