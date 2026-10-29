// Outfits: Koru wears the Coucou wardrobe, the 11 accessories and Auto (seasons) of MochiWardrobe.swift.
// Ports BotEngine.swift:535-565 setOutfit() (enter 350 ms inOut then a squash, exit 180 ms, change = exit then enter),
// the presence mapping of MochiOutfitDrawing.swift:309-418 and 466-503, and its shapes (213-1464) redrawn for an owl head:
// hats sit behind the ear tufts, glasses on the eye discs, the scarf at the neck line under the facial disc.
// Hats pop onto the crown where Swift drops them from 1.0 ry while fading in: at the film framing that drop left the canvas
// and the fade showed the head through the hat. Pompoms, hat tips and the scarf end lag with bot.physDx/physDy as in Swift.
// Every accessory shares Koru's clay finish; minis (and anything under 16 px R, Swift's `simplified`) drop the small details.
// Each part is drawn once into a cached sheet and stamped every frame; a part swinging with the lag is drawn live until it rests.
(()=>{
const {register,params,Clock,E,G,inner,drop,grainOn,sheet,stamp,bodyW}=Koru;
// Outfit rawValues (MochiWardrobe.swift:3-5) → live label and swatch.
const OUTFITS={partyHat:['Chapéu de festa','#F15BAE'],beanie:['Gorro','#2F6FE0'],crown:['Coroa','#FBBF24'],sunglasses:['Óculos escuros','#5B6472'],
  roundGlasses:['Óculos redondos','#9A5A1A'],bow:['Laço','#FF8CC6'],scarf:['Cachecol','#E53935'],witchHat:['Chapéu de bruxa','#7C3AED'],
  pumpkin:['Abóbora','#F97316'],santaHat:['Gorro de Natal','#B71C1C'],bunnyEars:['Orelhas de coelho','#FCA5A5']};

/* ---------------- SEASONS ---------------- */
// Outfit.seasonal(for:) (MochiWardrobe.swift:27-56): party hat > santa hat > witch hat > bunny ears > sunglasses > none.
function easter(y){ const a=y%19,b=y/100|0,c=y%100,d=b/4|0,e=b%4,f=(b+8)/25|0,g=(b-f+1)/3|0,h=(19*a+b-d-g+15)%30,i=c/4|0,k=c%4,l=(32+2*e+2*i-h-k)%7,m=(a+11*h+22*l)/451|0;
  return new Date(y,((h+l-7*m+114)/31|0)-1,(h+l-7*m+114)%31+1) }
function seasonal(t){ const D=t.getDate(), M=t.getMonth()+1;
  if((M===12&&D===31)||(M===1&&D<=2)) return 'partyHat';
  if(M===12&&D<=26) return 'santaHat';
  if(M===10||(M===11&&D===1)) return 'witchHat';
  const dd=Math.trunc((t-easter(t.getFullYear()))/864e5); if(dd>=-2&&dd<=1) return 'bunnyEars';   // whole days, as Calendar.dateComponents
  if((M===6&&D>=21)||M===7||M===8) return 'sunglasses';
  return 'none' }
// Auto reads the real calendar, as Swift's Date(); captures use ?season=YYYY-MM-DD, or Christmas Eve 2026 so a still never
// depends on the day it was taken.
const today=()=>params.has('season')?new Date(params.get('season')+'T12:00:00'):Clock.virtual?new Date(2026,11,24,12):new Date();
const pick=o=>o==='auto'?seasonal(today()):OUTFITS[o]?o:'none';

/* ---------------- PRESENCE ---------------- */
// setOutfit(): one tween, outfitP; its after-callbacks swap the outfit, and a newer call drops the pending tween with them.
function wear(b,o,animated=true){ if(o===b.outfitTarget) return; b.outfitTarget=o; b.stop('outfitP');
  const enter=()=>b.anim('outfitP',[[1,350,E.inOut]],()=>b.squash());
  if(!animated){ b.outfit=o; b.set('outfitP',o==='none'?0:1) }
  else if(o==='none') b.anim('outfitP',[[0,180,E.inOut]],()=>{ b.outfit='none' });
  else if(b.outfit==='none'){ b.outfit=o; b.set('outfitP',0); enter() }
  else b.anim('outfitP',[[0,180,E.inOut]],()=>{ b.outfit=o; enter() }) }
// Hats stay opaque and grow (Ease.back) from where they touch the crown. The others fade in, opaque at 40 % so movement
// carries the transition: glasses rise .25 ry, the scarf .3 ry, the bow scales from Koru's centre, the pumpkin only fades.
// Shapes below are in R units; hats are drawn round x = 0 and moved with the face (h).
const CROWN=-.9;
function stage(b,d,kind,x,a){ const p=b.s.outfitP, pos=E.back(p), h=d.f*.3; x.globalAlpha=a;
  if(kind==='glasses'){ const nb=new Path2D(); nb.rect(-d.W,-d.H,d.W*2,d.H*2); nb.addPath(d.beak,new DOMMatrix().translate(d.beakAt.x,d.beakAt.y)); x.clip(nb,'evenodd') }   // the beak stays in front
  x.scale(d.R,d.R);
  if(kind==='hat'){ const k=Math.max(.001,pos); x.translate(h,CROWN); x.scale(k,k); x.translate(0,-CROWN) }
  else if(kind==='glasses') x.translate(0,(1-p)*.25*G.ryTop);
  else if(kind==='scarf') x.translate(0,(1-p)*.3*G.ryTop);   // it rises inside Koru's outline (see scarf())
  else if(kind==='bow') x.scale(Math.max(.001,pos),Math.max(.001,pos));
  // The lag at rest, rounded so a resting pose keeps one sheet: lag names it (null while it swings, drawn live then).
  const rest=Math.abs(b.physVx)<.05&&Math.abs(b.physVy)<.05, q=v=>rest?Math.round(v*50)/50:v, dx=q(b.physDx), dy=q(b.physDy);
  return {R:d.R,full:d.full,simple:d.mini||d.R<16,f:d.f,h,yaw:d.s.yaw,dx,dy,lag:rest?dx+','+dy:null,rise:kind==='scarf'?(1-p)*.3*G.ryTop:0,
    eyes:kind==='glasses'?d.eyes.map(e=>({sd:e.sd,x:e.x/d.R,y:e.y/d.R,kx:e.kx,ky:e.ky})):null} }

/* ---------------- HELPERS ---------------- */
const lin=(x,x0,y0,x1,y1,...st)=>{ const g=x.createLinearGradient(x0,y0,x1,y1); for(let i=0;i<st.length;i+=2) g.addColorStop(st[i],st[i+1]); return g };
const rad=(x,cx,cy,r,...st)=>{ const g=x.createRadialGradient(cx,cy,0,cx,cy,r); for(let i=0;i<st.length;i+=2) g.addColorStop(st[i],st[i+1]); return g };
const ell=(cx,cy,rx,ry,rot=0)=>{ const p=new Path2D(); p.ellipse(cx,cy,rx,ry,rot,0,Math.PI*2); return p };
const line=(x,pts,w,c)=>{ x.lineWidth=w; x.strokeStyle=c; x.beginPath(); pts.forEach(([u,v],i)=>i?x.lineTo(u,v):x.moveTo(u,v)); x.stroke() };
// A part drawn once into a Koru.sheet at R px per unit (box in R units, pad the room inner() needs round it) and stamped
// through the current transform; key names the part and everything its drawing depends on. A null key draws it live.
function part(x,k,key,box,draw,pad=.15){ if(key==null){ x.save(); draw(x); x.restore(); return } const R=k.R;
  const s=sheet(`outfits:${key}:${R}:${+k.full}${+k.simple}`,box.map(v=>v*R),g=>{ g.scale(R,R); draw(g) },pad*R);
  x.save(); x.scale(1/R,1/R); stamp(x,s); x.restore() }
// Koru's soft clay, the one finish of every accessory (full size only): its velvet grain, a lit top-right rim and a shaded
// lower-left edge; box = bounds in R units. Colour and form come from each shape's own gradient, never from gloss.
function clay(x,p,box,k,lit=.38,dark=.3){ if(!k.full) return; const R=k.R, T=x.getTransform();
  grainOn(x,p,T.transformPoint({x:0,y:box[1]}).y,T.transformPoint({x:0,y:box[3]}).y,.32,box);
  inner(x,p,`rgba(255,250,240,${lit})`,R*.03,-R*.012,R*.022,box); inner(x,p,`rgba(20,8,30,${dark})`,R*.09,R*.03,-R*.05,box) }
// A soft contact shadow on Koru (full size only).
const cast=(x,p,k,a=.3)=>{ if(k.full) drop(x,p,`rgba(2,36,42,${a})`,k.R*.07,0,k.R*.04) };
// drawPompom(): fluffy bumps around a round centre (denser than Swift's 11), lit as one ball so it reads as wool.
function pompom(x,k,cx,cy,r,base='#FFFFFF',shade='#D5D9E2'){ x.save(); x.translate(cx,cy);
  part(x,k,'pompom'+r+base,[-r*1.1,-r*1.1,r*1.1,r*1.1],x=>{ const p=new Path2D(); p.arc(0,0,r*.9,0,Math.PI*2);
    for(let i=0;i<30;i++){ const a=i/30*Math.PI*2, br=r*(.13+.03*Math.sin(i*2.3)), bx=Math.cos(a)*r*.87, by=Math.sin(a)*r*.87; p.moveTo(bx+br,by); p.arc(bx,by,br,0,Math.PI*2) }
    x.fillStyle=rad(x,-r*.3,-r*.35,r*1.35,0,base,.55,base,1,shade); x.fill(p) },0); x.restore() }
// Koru's outline (R units, scaled by sc) as a path; in the head layers it goes back through d.head (and a rise).
const bodyR=(d,sc=1,head=false,rise=0)=>{ let M=new DOMMatrix().translate(0,-rise).scale(1/d.R); if(head) M=M.multiply(d.head.inverse());
  const p=new Path2D(); p.addPath(d.body,M.scale(sc)); return p };

/* ---------------- HATS ---------------- */
// Party hat: a tall cone worn askew on the crown (the rim tilts down to the right), polka dots, a yellow rim and pompom;
// the lean lags with physDx.
function partyHat(x,k){ const c=[.02,-.87]; x.translate(...c); x.rotate(.2); x.translate(-c[0],-c[1]);
  const rw=.45, rh=.1, lean=.22+k.dx*.12, ht=.68, ap=[c[0]+Math.sin(lean)*ht,c[1]-Math.cos(lean)*ht], L=[c[0]-rw,c[1]], Rt=[c[0]+rw,c[1]];
  part(x,k,k.lag&&'partyCone'+k.lag,[-.7,-1.65,.75,-.55],x=>{ const cone=new Path2D(); cone.moveTo(...L); cone.quadraticCurveTo((L[0]+ap[0])/2-.06,(L[1]+ap[1])/2,ap[0]-.05,ap[1]+.06); cone.quadraticCurveTo(ap[0],ap[1]-.03,ap[0]+.05,ap[1]+.06);
  cone.quadraticCurveTo((Rt[0]+ap[0])/2+.06,(Rt[1]+ap[1])/2,...Rt); cone.ellipse(c[0],c[1],rw,rh,0,0,Math.PI); cone.closePath();
  const box=[L[0]-.1,ap[1]-.1,Rt[0]+.1,c[1]+.12];
  cast(x,cone,k,.35); x.fillStyle=lin(x,L[0],ap[1],Rt[0],L[1],0,'#FCA5B5',.5,'#F7758F',1,'#DE3360'); x.fill(cone);
  x.save(); x.clip(cone);
  if(!k.simple) for(const [t,u] of [[.32,-.3],[.52,.5],[.8,-.48],[.84,.18]]){ const bx=L[0]+(Rt[0]-L[0])*(.5+u*.5), by=L[1]+(Rt[1]-L[1])*(.5+u*.5), r=.086*(.6+t*.6);
    x.fillStyle='rgba(255,255,255,.92)'; x.fill(ell(bx+(ap[0]-bx)*(1-t),by+(ap[1]-by)*(1-t),r,r*.9)) }
  x.fillStyle=lin(x,L[0],0,Rt[0],0,0,'rgba(255,255,255,.28)',.35,'rgba(255,255,255,0)',1,'rgba(90,0,30,.3)'); x.fill(cone); x.restore();
  clay(x,cone,box,k,.3,.25) });
  part(x,k,'partyRim',[-.65,-1.1,.7,-.55],x=>{ x.lineCap='round'; x.lineWidth=.15; x.strokeStyle=lin(x,0,c[1]-.06,0,c[1]+rh+.08,0,'#FFF1A8',.45,'#FFD84D',1,'#D98E0B'); x.beginPath(); x.ellipse(c[0],c[1],rw,rh,0,0,Math.PI); x.stroke();   // a plump tube
  x.lineWidth=.035; x.strokeStyle='rgba(255,250,215,.85)'; x.beginPath(); x.ellipse(c[0],c[1]-.03,rw,rh,0,Math.PI*.15,Math.PI*.7); x.stroke() });
  pompom(x,k,ap[0],ap[1]-.04,.18,'#FFD54A','#E0960B') }

// Beanie: knit cap and ribbed cuff on the crown, behind the brows and tufts; the pompom sits on a short spring.
function beanie(x,k){ part(x,k,'beanie',[-.95,-1.6,.95,-.6],x=>{
  const knit=new Path2D(); knit.moveTo(-.64,-1.0); knit.bezierCurveTo(-.66,-1.29,-.36,-1.41,0,-1.41); knit.bezierCurveTo(.36,-1.41,.66,-1.29,.64,-1.0); knit.closePath();
  const cuff=new Path2D(); cuff.moveTo(-.7,-1.03); cuff.quadraticCurveTo(0,-1.16,.7,-1.03); cuff.quadraticCurveTo(.77,-.93,.7,-.82);
  cuff.quadraticCurveTo(0,-.95,-.7,-.82); cuff.quadraticCurveTo(-.77,-.93,-.7,-1.03); cuff.closePath();
  const KB=[-.68,-1.48,.68,-1], CB=[-.8,-1.18,.8,-.8];
  cast(x,cuff,k,.35);
  x.fillStyle=lin(x,.42,-1.42,-.5,-.6,0,'#8CC2FF',1,'#3B82F6'); x.fill(knit);
  x.save(); x.clip(knit);
  if(!k.simple) for(let i=-5;i<=5;i++) line(x,[[i*.11,-1.04],[i*.1,-1.17],[i*.07,-1.3],[i*.025,-1.4]],.045,'rgba(20,50,140,.12)');
  x.fillStyle=rad(x,.22,-1.3,.4,0,'rgba(255,255,255,.35)',1,'rgba(255,255,255,0)'); x.fillRect(-1,-1.5,2,.6); x.restore();
  clay(x,knit,KB,k);
  x.fillStyle=lin(x,0,-1.1,0,-.82,0,'#4A8CF0',1,'#2563EB'); x.fill(cuff);
  if(!k.simple){ x.save(); x.clip(cuff); for(let i=-8;i<=8;i++) line(x,[[i*.086,-1.14],[i*.086,-.76]],.035,'rgba(10,30,100,.16)'); x.restore() }
  clay(x,cuff,CB,k,.3,.25) });
  pompom(x,k,k.dx*.29,-1.47+k.dy*.13,.18) }

// Santa hat: a tall red bag slouching to the right, its tip hanging past the tuft beside the head, a thick white fuzzy
// trim tilted down to the right; the tip lags with physDx/physDy.
function santaHat(x,k){ const L=[-.76,-1.03], Rt=[.72,-.86], C=[-.04,-1.25], pk=[.06,-1.6], tip=[1.22+k.dx*.3,-.46+k.dy*.15];
  part(x,k,k.lag&&'santaBag'+k.lag,[-1.0,-1.8,1.65,-.05],x=>{ const bag=new Path2D(); bag.moveTo(L[0]+.04,L[1]); bag.bezierCurveTo(L[0]+.04,L[1]-.42,pk[0]-.4,pk[1],...pk); bag.bezierCurveTo(pk[0]+.62,pk[1]-.02,tip[0]+.14,tip[1]-.78,tip[0]+.08,tip[1]-.04);
  bag.quadraticCurveTo(tip[0],tip[1]+.06,tip[0]-.08,tip[1]-.04); bag.bezierCurveTo(tip[0]-.12,tip[1]-.3,Rt[0]+.22,Rt[1]-.1,Rt[0]-.02,Rt[1]-.1); bag.quadraticCurveTo(...C,L[0]+.04,L[1]); bag.closePath();
  const box=[L[0]-.1,pk[1]-.1,tip[0]+.25,tip[1]+.1];
  cast(x,bag,k,.25);
  x.fillStyle=lin(x,-.7,-1.7,1.1,-.4,0,'#F24343',.5,'#D81F26',1,'#9C0F17'); x.fill(bag);
  x.save(); x.clip(bag); x.lineCap='round';
  for(const [a,w] of [[.15,.1],[.45,.08]]){ x.lineWidth=w; x.strokeStyle='rgba(90,0,0,.07)'; x.beginPath(); x.moveTo(pk[0]+.1+a*.4,pk[1]+.2+a*.3); x.bezierCurveTo(pk[0]+.6,pk[1]+.15+a*.2,tip[0]-.05-a*.1,tip[1]-.6,tip[0]-.04-a*.08,tip[1]-.22); x.stroke() }   // soft folds where it bends
  x.fillStyle=rad(x,pk[0]-.2,pk[1]+.18,.6,0,'rgba(255,255,255,.1)',1,'rgba(255,255,255,0)'); x.fillRect(-1,-1.8,2.6,1.6); x.restore();
  clay(x,bag,box,k,.14,.3) });
  part(x,k,'santaTrim',[-1.1,-1.5,1.1,-.5],x=>{   // drawFuzzyBand(): a thick cream roll with round ends, shaded underneath, fuzz along both edges
  const arc=[]; for(let i=0;i<=32;i++){ const t=i/32; arc.push([(1-t)**2*L[0]+2*(1-t)*t*C[0]+t*t*Rt[0],(1-t)**2*L[1]+2*(1-t)*t*C[1]+t*t*Rt[1]]) }
  const th=.3, TB=[L[0]-.2,-1.4,Rt[0]+.2,-.65], tb=new Path2D(); arc.forEach(([u,v],i)=>i?tb.lineTo(u,v-th/2):tb.moveTo(u,v-th/2));
  tb.arc(...arc[32],th/2,-Math.PI/2,Math.PI/2); for(let i=31;i>=0;i--) tb.lineTo(arc[i][0],arc[i][1]+th/2); tb.arc(...arc[0],th/2,Math.PI/2,Math.PI*1.5); tb.closePath();
  if(k.full) drop(x,tb,'rgba(2,36,42,.4)',k.R*.06,0,k.R*.03);
  x.fillStyle=lin(x,0,-1.28,0,-.74,0,'#FFFDF8',.5,'#F3EEE5',1,'#CFC5B6'); x.fill(tb);
  if(!k.simple) for(let i=0;i<arc.length;i++){ const [u,v]=arc[i], r=.026+.012*Math.sin(i*2.7)**2; x.fillStyle='#FCF9F3'; x.fill(ell(u,v-th*.45,r,r*.8)); x.fillStyle='#D3CABD'; x.fill(ell(u+.02,v+th*.43,r*.85,r*.7)) }
  if(k.full){ inner(x,tb,'rgba(120,100,80,.35)',k.R*.06,0,-k.R*.035,TB); clay(x,tb,TB,k,.2,.2) } });
  pompom(x,k,tip[0]+.02,tip[1]+.06,.26,'#FCF9F3','#D3C9BB') }

// Witch hat, behind the facial disc and both tufts like the other hats: a wide floppy brim drooping beside the head, a tall
// cone whose tip bends over to the right, a thick orange band and a big buckle; the tip lags.
function witchHat(x,k){ const by=-.9; x.translate(0,by); x.rotate(-.04); x.translate(0,-by);
  part(x,k,'witchBrim',[-1.6,-1.2,1.6,-.25],x=>{ const Wb=1.3, D=.3, top=[], bot=[];
  for(let i=0;i<=40;i++){ const u=-1+i/20, v=by+D*Math.abs(u)**3+.012*Math.sin(u*9), q=1-u*u; top.push([Wb*u,v-.1-.12*q]); bot.push([Wb*u,v+.07+.03*q]) }
  const cap=sd=>{ const e=sd>0?40:0, t=[sd*.8,.6]; return [top[e][0]+t[0]*.12,(top[e][1]+bot[e][1])/2+t[1]*.12] };   // a rounded end along the arch
  const brim=new Path2D(); top.forEach(([u,v],i)=>i?brim.lineTo(u,v):brim.moveTo(u,v)); brim.quadraticCurveTo(...cap(1),...bot[40]);
  for(let i=39;i>=0;i--) brim.lineTo(...bot[i]); brim.quadraticCurveTo(...cap(-1),...top[0]); brim.closePath();
  const BB=[-Wb-.15,by-.2,Wb+.15,by+D+.15];
  if(k.full) drop(x,brim,'rgba(2,36,42,.65)',k.R*.07,0,k.R*.045);
  x.fillStyle=lin(x,0,by-.18,0,by+D,0,'#9A55DA',.5,'#7B30C2',1,'#5E1FA0'); x.fill(brim);
  x.lineCap='round'; x.lineJoin='round'; x.save(); x.clip(brim); line(x,bot.slice(2,-2),.09,'rgba(50,8,95,.45)'); x.restore();   // the rolled lip
  clay(x,brim,BB,k,.25,.3) });
  part(x,k,k.lag&&'witchCone'+k.lag,[-.9,-1.85,1.45,-.65],x=>{ const bl=[-.64,by-.05], br=[.64,by-.05], pk=[.1+k.dx*.05,-1.6], tip=[1.0+k.dx*.25,-1.34+k.dy*.1];
  const cone=new Path2D(); cone.moveTo(...bl); cone.bezierCurveTo(bl[0]+.14,bl[1]-.42,pk[0]-.32,pk[1]+.34,pk[0]-.12,pk[1]+.06); cone.quadraticCurveTo(pk[0]-.02,pk[1]-.04,pk[0]+.14,pk[1]-.02);
  cone.bezierCurveTo(pk[0]+.45,pk[1]+.02,tip[0]-.2,tip[1]-.12,tip[0]-.04,tip[1]); cone.quadraticCurveTo(tip[0]+.04,tip[1]-.02,tip[0]+.07,tip[1]-.07);   // the bent tip flicks up
  cone.quadraticCurveTo(tip[0]+.08,tip[1]+.06,tip[0]-.08,tip[1]+.08); cone.bezierCurveTo(tip[0]-.3,tip[1]+.05,pk[0]+.42,pk[1]+.2,pk[0]+.3,pk[1]+.34);
  cone.bezierCurveTo(br[0]-.18,by-.5,br[0]-.03,br[1]-.2,...br); cone.ellipse(0,by-.05,.64,.1,0,0,Math.PI); cone.closePath();
  const box=[bl[0]-.1,pk[1]-.15,tip[0]+.15,by+.1];
  cast(x,cone,k,.3);
  x.fillStyle=lin(x,bl[0],pk[1],br[0],bl[1],0,'#A15BE0',.5,'#7A2FC0',1,'#561A94'); x.fill(cone);
  x.save(); x.clip(cone);
  x.fillStyle=lin(x,bl[0],0,br[0],0,0,'rgba(255,255,255,.2)',.4,'rgba(255,255,255,0)',1,'rgba(0,0,0,.18)'); x.fillRect(-.8,-1.8,2.2,1.2);
  x.lineWidth=.05; x.strokeStyle='rgba(30,0,60,.3)'; x.beginPath(); x.moveTo(pk[0]+.2,pk[1]+.3); x.quadraticCurveTo(pk[0]+.34,pk[1]+.16,pk[0]+.52,pk[1]+.18); x.stroke();   // the fold of the bend
  x.lineCap='butt'; x.lineWidth=.26; x.strokeStyle=lin(x,0,by-.3,0,by+.06,0,'#FF9348',.5,'#F26A1B',1,'#C9480C'); x.beginPath(); x.moveTo(bl[0]-.05,by-.2); x.quadraticCurveTo(0,by,br[0]+.05,by-.2); x.stroke();
  x.lineWidth=.03; x.strokeStyle='rgba(255,215,170,.55)'; x.beginPath(); x.moveTo(bl[0]+.02,by-.29); x.quadraticCurveTo(0,by-.12,br[0]-.02,by-.29); x.stroke(); x.restore();
  clay(x,cone,box,k,.3,.3) });
  part(x,k,'witchBuckle',[-.3,-1.35,.4,-.7],x=>{ const bx=.05, bY=by-.13, buckle=new Path2D(); buckle.roundRect(bx-.18,bY-.16,.36,.31,.07); buckle.roundRect(bx-.086,bY-.07,.172,.13,.03);
  const UB=[bx-.22,bY-.2,bx+.22,bY+.2];
  if(k.full) drop(x,buckle,'rgba(90,30,0,.4)',k.R*.03,0,k.R*.015);
  x.fillStyle=lin(x,0,bY-.16,0,bY+.15,0,'#FFE680',.5,'#FFC21A',1,'#E08A0B'); x.fill(buckle,'evenodd'); clay(x,buckle,UB,k,.45,.35);
  if(k.full){ x.save(); x.clip(buckle,'evenodd'); x.fillStyle='rgba(255,255,240,.6)'; x.beginPath(); x.moveTo(bx-.17,bY-.02); x.lineTo(bx-.08,bY-.16); x.lineTo(bx-.01,bY-.16); x.lineTo(bx-.1,bY-.02); x.fill(); x.restore();
    const hole=new Path2D(); hole.roundRect(bx-.086,bY-.07,.172,.13,.03); inner(x,hole,'rgba(90,30,0,.55)',k.R*.025,0,k.R*.015,UB) } }) }

// Crown: a molded golden crown seen from the front, five rounded lobes with ball tips, a red gem between two blue ones.
function crown(x,k){ part(x,k,'crown',[-.65,-1.65,.65,-.55],x=>{ const P=[[-.46,-1.22],[-.23,-1.32],[0,-1.44],[.23,-1.32],[.46,-1.22]], vy=-1.15;
  const F=new Path2D(); F.moveTo(-.42,-.86); F.lineTo(...P[0]);
  for(let i=1;i<P.length;i++){ const [ax,ay]=P[i-1], [bx,by]=P[i]; F.quadraticCurveTo((ax+bx)/2,2*vy-(ay+by)/2,bx,by) }
  F.lineTo(.42,-.86); F.quadraticCurveTo(0,-.8,-.42,-.86); F.closePath();
  const box=[-.5,-1.48,.5,-.78];
  cast(x,F,k,.3); x.fillStyle=lin(x,0,-1.42,0,-.82,0,'#FFDD73',.5,'#F8BC2A',1,'#E39A12'); x.fill(F);
  x.save(); x.clip(F); x.fillStyle='rgba(150,90,0,.16)'; x.fillRect(-.5,-.92,1,.1); x.restore();
  clay(x,F,box,k,.42,.32);
  const balls=new Path2D(); for(const [px,py] of P) balls.addPath(ell(px,py-.04,.09,.09));
  x.fillStyle=lin(x,0,-1.54,0,-1.12,0,'#FFE48A',1,'#EBA61C'); x.fill(balls); clay(x,balls,[-.56,-1.54,.56,-1.12],k,.4,.28);
  if(k.simple) return;
  const gems=new Path2D();
  for(const [gx,gy,rx,ry,c,e] of [[-.22,-1.06,.06,.06,'#4F8EF7','#2A5FC9'],[0,-1.12,.086,.11,'#F25555','#B8262B'],[.22,-1.06,.06,.06,'#4F8EF7','#2A5FC9']]){ const g=ell(gx,gy,rx,ry);
    x.fillStyle=lin(x,0,gy-ry,0,gy+ry,0,c,1,e); x.fill(g); gems.addPath(g) }
  clay(x,gems,[-.3,-1.24,.3,-.99],k,.5,.3) }) }

// Bunny ears: behind the head, between the tufts (in the behind layer, so the body hides their roots).
function bunnyEars(x,k){ part(x,k,'bunny',[-1.0,-1.95,1.0,-.3],x=>{ const eh=1.32, ew=.35;
  for(const sd of[-1,1]){ x.save(); x.translate(sd*.44,-.86); x.rotate(sd*.32); x.translate(0,-eh*.17);
    const o=ell(0,0,ew,eh/2), B=[-ew,-eh/2,ew,eh/2]; x.fillStyle=lin(x,0,-eh/2,0,eh/2,0,'#FFFDFB',1,'#EADDDD'); x.fill(o); clay(x,o,B,k,.3,.18);
    x.lineWidth=.8/k.R; x.strokeStyle='rgba(0,0,0,.06)'; x.stroke(o);
    const ie=ell(0,-eh/2+.1+eh*.4,ew*.56,eh*.4); x.fillStyle='rgba(250,160,168,.85)'; x.fill(ie); if(k.full) inner(x,ie,'rgba(150,50,60,.35)',k.R*.04,0,k.R*.025,B); x.restore() } }) }

/* ---------------- FACE ---------------- */
// Lens frames centred on the eye discs (d.eyes), foreshortened with them as the head turns.
function lenses(x,k,fn){ for(const e of k.eyes){ x.save(); x.translate(e.x,e.y); x.scale(e.kx,e.ky); fn(e.sd); x.restore() } }
// Sunglasses: dark rounded lenses over the orange discs (their lower edge shows), joined by one solid arched bridge whose ends
// widen into the lens tops, so no gap shows between them.
function sunglasses(x,k){ const w=.88, hh=.6, oy=-.09, [l,r]=k.eyes, y=l.y+oy-hh*.36, a=l.x+(w/2-.12)*l.kx, b=r.x-(w/2-.12)*r.kx, m=(l.x+r.x)/2;
  const bridge=new Path2D(); bridge.moveTo(a,y-.05); bridge.quadraticCurveTo(m,y-.1,b,y-.05); bridge.lineTo(b,y+.07); bridge.quadraticCurveTo(m,y-.03,a,y+.07); bridge.closePath();
  x.fillStyle=lin(x,0,y-.08,0,y+.02,0,'#3A404B',.5,'#181B21',1,'#0A0B0E'); x.fill(bridge);   // under the lenses: its ends meet their rims
  lenses(x,k,()=>part(x,k,'sunLens',[-w/2-.15,oy-hh/2-.15,w/2+.15,oy+hh/2+.15],x=>{ const lens=new Path2D(), B=[-w/2-.05,oy-hh/2-.05,w/2+.05,oy+hh/2+.05]; lens.roundRect(-w/2,oy-hh/2,w,hh,[.2,.2,.32,.32]);
    x.fillStyle=lin(x,0,oy-hh/2,0,oy+hh/2,0,'#2E333C',1,'#0A0B0E'); x.fill(lens);
    x.lineWidth=.06; x.strokeStyle='#121419'; x.stroke(lens); clay(x,lens,B,k,.32,.25);
    if(!k.simple){ x.lineCap='round'; line(x,[[-w*.2,oy+hh*.24],[w*.04,oy-hh*.26]],.045,'rgba(255,255,255,.72)') } })) }   // one thin glare
// Round glasses: thin tortoise wire around each orange disc, clear lenses (the pupils stay ink), an arched bridge that leaves
// both rims at the same angle as they curve, so no joint shows.
function roundGlasses(x,k){ const r=.41, a=.45; x.lineCap='round';
  lenses(x,k,sd=>part(x,k,'roundLens'+sd,[-r-.2,-r-.2,r+.2,r+.2],x=>{ const c=ell(0,0,r,r), tg=x.createConicGradient(.4,0,0); x.lineCap='round';
    [[0,'#4A230B'],[.07,'#A65E22'],[.13,'#5A2E0E'],[.24,'#C27A35'],[.33,'#4A230B'],[.47,'#9A5420'],[.56,'#3E1E0A'],[.68,'#B86E2C'],[.8,'#55290D'],[.9,'#A65E22'],[1,'#4A230B']].forEach(([o,c])=>tg.addColorStop(o,c));   // tortoiseshell
    x.lineWidth=.08; x.strokeStyle=tg; x.stroke(c);
    x.lineWidth=.024; x.strokeStyle=lin(x,-r,0,r,0,0,'rgba(255,230,190,0)',.4,'rgba(255,236,205,.6)',1,'rgba(255,230,190,0)'); x.beginPath(); x.arc(0,0,r+.01,Math.PI*1.1,Math.PI*1.9); x.stroke();
    if(!k.simple){ x.lineWidth=.03; x.strokeStyle='rgba(255,255,255,.22)'; x.beginPath(); x.arc(0,0,r-.07,Math.PI*1.12,Math.PI*1.38); x.stroke() }   // a glint on the glass, clear of the pupil
    const hs=new Path2D(); hs.roundRect(sd>0?r-.01:-r-.07,-.065,.08,.13,.03); x.fillStyle=lin(x,0,-.065,0,.065,0,'#B86E2C',1,'#3E1E0A'); x.fill(hs); clay(x,hs,[-r-.1,-.1,r+.1,.1],k,.35,.3) }));   // hinge studs
  const [l,rt]=k.eyes, p0=[l.x+Math.cos(a)*r*l.kx,l.y-Math.sin(a)*r*l.ky], p1=[rt.x-Math.cos(a)*r*rt.kx,rt.y-Math.sin(a)*r*rt.ky];
  x.lineWidth=.065; x.strokeStyle=lin(x,0,p0[1]-.1,0,p0[1]+.05,0,'#9A5420',1,'#4A230B'); x.beginPath(); x.moveTo(...p0); x.quadraticCurveTo((p0[0]+p1[0])/2,p0[1]-.13,...p1); x.stroke() }
// Bow: pink satin at the base of the right tuft, squeezed as the head turns away; two crisp folds run from the knot.
function bow(x,k){ const s=.42, sq=Math.max(.45,Math.cos(.3+k.yaw*.6));
  x.translate(.6+k.f*.5,-.98); x.rotate(.35+k.yaw*.3); x.scale(sq,1);
  part(x,k,'bow',[-s*1.6,-s*1.2,s*1.6,s*1.2],x=>{ x.lineCap='round';
    for(const sd of[-1,1]){ const w=new Path2D(); w.moveTo(0,0); w.bezierCurveTo(sd*s*.6,-s*.85,sd*s*1.35,-s*.55,sd*s*1.15,0); w.bezierCurveTo(sd*s*1.35,s*.55,sd*s*.6,s*.85,0,0); w.closePath();
      cast(x,w,k,.22); x.fillStyle=lin(x,0,-s*.8,0,s*.8,0,'#FFA3D2',.55,'#F25CA6',1,'#C9246F'); x.fill(w);
      if(!k.simple){ x.save(); x.clip(w); for(const v of [-.3,.26]){ x.lineWidth=s*.05; x.strokeStyle='rgba(150,15,75,.32)'; x.beginPath(); x.moveTo(sd*s*.22,v*s*.25); x.quadraticCurveTo(sd*s*.6,v*s*.95,sd*s*1.02,v*s*.7); x.stroke() } x.restore() }
      clay(x,w,[-s*1.4,-s,s*1.4,s],k,.42,.28) }
    const kn=new Path2D(); kn.moveTo(0,-s*.3); for(const sd of[1,-1]) kn.bezierCurveTo(sd*s*.27,-s*.32*sd,sd*s*.27,-s*.12*sd,sd*s*.17,0), kn.bezierCurveTo(sd*s*.27,s*.12*sd,sd*s*.27,s*.32*sd,0,s*.3*sd);   // pinched at the waist
    if(k.full) drop(x,kn,'rgba(110,10,55,.35)',k.R*.03,0,0);
    x.fillStyle=lin(x,0,-s*.3,0,s*.3,0,'#FF9DCF',1,'#D23A82'); x.fill(kn); clay(x,kn,[-s*.3,-s*.35,s*.3,s*.35],k,.4,.28) }) }

/* ---------------- BODY ---------------- */
// Scarf: a knitted band round the neck line, tucked under the facial disc; it wraps round Koru, so its ends turn away along
// the outline and its stitches crowd there. On the left an end folds over the band and hangs, its fringe swinging with physDx.
// Seen from a little above, each edge is the front half of an ellipse round Koru: it curves up into the outline at the
// sides, where a soft rounded end turns the band away.
const SW=1.24, yTop=u=>.2+.17*Math.sqrt(Math.max(0,1-(u/SW)**2)), yBot=u=>.5+.21*Math.sqrt(Math.max(0,1-(u/SW)**2));
// Stockinette: V stitches (two slim legs leaning out at the top, chained into the row below) at [u,v,z] (z narrows them
// where the band turns away): the yarn is lit over darker gaps, with a highlight along the top of each leg.
function knit(x,at,sz){ const leg=new Path2D(), hi=new Path2D();
  for(const [u,v,z] of at){ const w=sz*z; for(const sd of[-1,1]){ const cx=u+sd*w*.24, a=sd*.45;
    for(const [p,k,dy] of [[leg,1,0],[hi,.5,-sz*.14]]){ const rx=w*.15*k, ry=sz*.62*k; p.moveTo(cx+Math.cos(a)*rx,v+dy+Math.sin(a)*rx); p.ellipse(cx,v+dy,rx,ry,a,0,Math.PI*2) } } }
  x.fillStyle='rgba(70,0,0,.34)'; x.fillRect(-2,-2,4,4);   // the gaps (inside the caller's clip)
  x.fillStyle='rgba(240,60,55,.6)'; x.fill(leg); x.fillStyle='rgba(255,190,180,.18)'; x.fill(hi) }
// White yarn over red knit: the colour goes, its light and shade stay (lifted), so a white stripe keeps the stitches.
function white(x,fn){ x.save(); for(const [op,c] of [['color','#fff'],['screen','rgb(190,185,182)']]){ x.globalCompositeOperation=op; x.fillStyle=c; fn() } x.restore() }
// The band turns with the head: its pattern is at longitude lon+ph round Koru (u = SW sin). Stitches repeat every .05, so
// the knit is cached for 16 phases of that step; the white stripes are drawn live.
const KS=.05;
function scarf(x,k,d){ const m=k.f*.75, ph=Math.asin(Math.max(-1,Math.min(1,m/SW)));
  if(k.rise>.001) x.clip(bodyR(d,1.1,true,k.rise));   // while it rises it stays inside Koru's outline
  const band=new Path2D(), n=40, U=i=>-SW*Math.cos(Math.PI*i/n);   // points crowd at the ends, where the edges turn
  for(let i=0;i<=n;i++) i?band.lineTo(U(i),yTop(U(i))):band.moveTo(U(i),yTop(U(i)));
  band.bezierCurveTo(SW+.07,yTop(SW)+.02,SW+.07,yBot(SW)-.02,SW,yBot(SW));
  for(let i=n;i>=0;i--) band.lineTo(U(i),yBot(U(i)));
  band.bezierCurveTo(-SW-.07,yBot(SW)-.02,-SW-.07,yTop(SW)+.02,-SW,yTop(SW)); band.closePath();
  const BB=[-1.32,.15,1.32,.75], SB=[-1.5,0,1.5,.95];
  part(x,k,'scarfBand',SB,x=>{ if(k.full) drop(x,band,'rgba(2,36,42,.45)',k.R*.06,0,k.R*.035);
    x.fillStyle=lin(x,0,.18,0,.72,0,'#F04848',.6,'#D92B2B',1,'#B01E1E'); x.fill(band) });
  // the knit, the rolled tube, the wrap and the clay, for this phase
  const q=((Math.round(ph/KS*16)%16)+16)%16;
  part(x,k,'scarfKnit'+q,SB,x=>{ x.clip(band);
    if(!k.simple){ const at=[], rows=7, o=q/16*KS;
      for(let lon=-1.6+o;lon<=1.6;lon+=KS){ const z=Math.cos(lon); if(z<.25) continue; const u=Math.sin(lon)*SW;
        for(let j=0;j<rows;j++) at.push([u,yTop(u)+(yBot(u)-yTop(u))*(j+.5)/rows,z]) }
      knit(x,at,.046) }
    x.fillStyle=lin(x,0,.18,0,.72,0,'rgba(255,240,235,.14)',.3,'rgba(255,240,235,0)',.7,'rgba(60,0,0,0)',1,'rgba(60,0,0,.3)'); x.fillRect(-1.4,.1,2.8,.8);   // a rolled tube
    x.fillStyle=lin(x,-SW-.07,0,SW+.07,0,0,'rgba(60,0,0,.5)',.16,'rgba(60,0,0,0)',.84,'rgba(60,0,0,0)',1,'rgba(60,0,0,.5)'); x.fillRect(-1.4,.1,2.8,.8);   // it wraps round
    clay(x,band,BB,k,.28,.3) },.3);
  x.save(); x.clip(band); white(x,()=>{ for(const lon of [-1.05,-.5,.05,.6,1.15]){ const z=Math.cos(lon+ph); if(z>0) x.fillRect(Math.sin(lon+ph)*SW-.06*z,.1,.12*z,.8) } }); x.restore();   // white stripes
  // the end: it folds over the band (a rounded fold on top, a soft crease where it bends down past the band) and hangs
  const kx=-.74+m; x.translate(kx,0);
  part(x,k,k.lag&&'scarfEnd'+k.lag,[-.6,.05,.4,1.3],x=>{ const t0=yTop(-.74)-.03, yb=1.0, sw=k.dx*.14, bx=sw*1.4, end=new Path2D();
    end.moveTo(-.21,t0+.09); end.bezierCurveTo(-.21,t0-.04,.19,t0-.07,.21,t0+.06);
    end.quadraticCurveTo(.15+sw,(t0+yb)/2,bx,yb); end.lineTo(-.38+bx,yb-.03); end.quadraticCurveTo(-.3+sw,(t0+yb)/2,-.21,t0+.09); end.closePath();
    const EB=[-.42,t0-.06,.22,yb+.02], X=(s,t)=>{ const l=-.2+(bx-.18)*t, r=.2+(bx-.2)*t; return l+(r-l)*s };
    cast(x,end,k,.32); x.fillStyle=lin(x,-.4,0,.2,0,0,'#F04848',.6,'#D92B2B',1,'#B01E1E'); x.fill(end);
    x.save(); x.clip(end);
    if(!k.simple){ const at=[]; for(let j=0;j<12;j++){ const t=(j+.5)/12, v=t0+(yb-t0)*t; for(let i=0;i<6;i++){ const s=(i+.5)/6; at.push([X(s,t),v+.02*Math.sin(s*Math.PI),1]) } } knit(x,at,.058) }
    const yS=t0+(yb-t0)*.38; white(x,()=>{ x.beginPath(); x.moveTo(-.5,yS-.05); x.quadraticCurveTo(-.1,yS,.3,yS-.07); x.lineTo(.3,yS+.03); x.quadraticCurveTo(-.1,yS+.1,-.5,yS+.05); x.fill() });   // one white stripe
    const yc=yBot(-.74); x.fillStyle=lin(x,0,yc-.07,0,yc+.09,0,'rgba(60,0,0,0)',.55,'rgba(60,0,0,.28)',1,'rgba(60,0,0,0)'); x.fillRect(-.5,yc-.07,.8,.16);   // the bend past the band
    x.fillStyle=lin(x,0,t0-.05,0,t0+.08,0,'rgba(255,235,230,.18)',1,'rgba(255,235,230,0)'); x.fillRect(-.5,t0-.06,.8,.14); x.restore();   // the lit fold
    clay(x,end,EB,k,.28,.3);
    if(!k.simple){ x.lineCap='round'; for(let i=0;i<9;i++){ const u=-.36+bx+i*.042; line(x,[[u,yb-.02],[u+(i-4)*.012+sw*.3,yb+.13+.02*Math.sin(i*2.2)]],.036,i%2?'#F4EFEA':'#C92525') } } }) }   // splayed yarn

// Pumpkin: the body takes the pumpkin colours of drawBody(pumpkinColors:) and five ribs, lobes peek out from behind it;
// the facial disc and belly stay teal. Warm rims stand in for Koru's cyan ones and a warm glow lifts the lower sides, so the
// sides stay lit.
function pumpkinLobes(x,k){ x.translate(k.h,0); part(x,k,'pumpkinLobes',[-1.4,-1.25,1.4,1.25],x=>{
  for(const [u,v,rx,ry] of [[0,-.01,.42,1.03],[-.48,-.06,.42,1.07],[.48,-.06,.42,1.07],[-.92,-.04,.36,.86],[.92,-.04,.36,.86]]){ const l=ell(u,v,rx,ry);
    x.fillStyle=lin(x,0,-1,0,1,0,'#F7A04A',1,'#CF4E14'); x.fill(l); clay(x,l,[u-rx,v-ry,u+rx,v+ry],k,.2,.35) } }) }
function pumpkinBody(x,k,d){ const body=bodyR(d), Y=G.ryTop+.05, BB=[-G.rx,-G.ryTop,G.rx,G.ryBot], R=k.R; x.clip(body);
  const out=new Path2D(); out.rect(-2,-2,4,4); out.addPath(d.belly,new DOMMatrix().scale(1/R)); x.clip(out,'evenodd');   // the belly stays teal
  x.globalCompositeOperation='color'; x.fillStyle=lin(x,.85,-.9,-.95,.9,0,'#FFA94D',1,'#E8590C'); x.fillRect(-1.3,-Y,2.6,Y+G.ryBot+.05);
  x.globalCompositeOperation='soft-light'; x.fillStyle='rgba(255,150,60,.5)'; x.fillRect(-1.3,-Y,2.6,Y+G.ryBot+.05); x.globalCompositeOperation='source-over';
  if(k.full) part(x,k,'pumpkinBody',[-G.rx-.02,-G.ryTop-.02,G.rx+.02,G.ryBot+.02],x=>{ inner(x,body,'rgba(255,214,160,.8)',R*.06,0,R*.035,BB);
    x.fillStyle=lin(x,0,-.2,0,G.ryBot,0,'rgba(250,125,40,0)',1,'rgba(250,125,40,.62)'); x.fillRect(-G.rx,-.2,G.rx*2,G.ryBot+.2);   // Koru's own shade darkens the lower half
    inner(x,body,'rgba(255,150,60,.55)',R*.09,-R*.06,0,BB); inner(x,body,'rgba(255,135,45,.45)',R*.08,R*.05,0,BB);
    inner(x,body,'rgba(255,140,50,.4)',R*.28,0,-R*.14,BB) },.75);   // and its lower sides
  if(k.simple) return; x.lineCap='round';
  for(const lon of [-1.15,-.55,0,.55,1.15]){ const z=Math.cos(lon), pts=[]; for(let i=0;i<=30;i++){ const y=-.98+1.96*i/30; pts.push([Math.sin(lon)*bodyW(y)+k.f*.5*z,y]) }
    line(x,pts,.2,`rgba(150,50,0,${.16*z})`); line(x,pts,.1,`rgba(120,35,0,${.22*z})`); line(x,pts,.04,`rgba(80,20,0,${.45*z})`) } }
function pumpkinStem(x,k){ x.translate(k.h,0); part(x,k,'pumpkinStem',[-.35,-1.75,1.0,-.8],x=>{ const t=[.02,-1.04];
  // a thick stalk bending to the right with a cut end, a curly tendril and a three-lobed leaf
  const stem=new Path2D(); stem.moveTo(t[0]-.14,t[1]+.05); stem.bezierCurveTo(t[0]-.14,t[1]-.18,t[0]-.11,t[1]-.42,t[0]+.04,t[1]-.47); stem.quadraticCurveTo(t[0]+.17,t[1]-.5,t[0]+.23,t[1]-.42);
  stem.quadraticCurveTo(t[0]+.22,t[1]-.31,t[0]+.13,t[1]-.33); stem.bezierCurveTo(t[0]+.06,t[1]-.31,t[0]+.06,t[1]-.12,t[0]+.14,t[1]+.05); stem.closePath();
  const SB=[t[0]-.16,t[1]-.52,t[0]+.26,t[1]+.08];
  cast(x,stem,k,.25); x.fillStyle=lin(x,t[0]-.14,0,t[0]+.16,0,0,'#7CBF2A',.55,'#559A12',1,'#36650A'); x.fill(stem);
  if(!k.simple){ x.save(); x.clip(stem); x.lineCap='round'; for(const u of [-.06,.03]) line(x,[[t[0]+u,t[1]+.05],[t[0]+u+.01,t[1]-.2],[t[0]+u+.06,t[1]-.42]],.02,'rgba(30,70,0,.3)'); x.restore();
    x.fillStyle='#A3D65C'; x.fill(ell(t[0]+.18,t[1]-.385,.045,.06,.5)) }   // the cut end
  clay(x,stem,SB,k,.35,.25);
  if(!k.simple){ x.lineCap='round'; x.lineWidth=.04; x.strokeStyle='#5E9E18'; x.beginPath(); x.moveTo(t[0]+.1,t[1]-.18);
    x.bezierCurveTo(t[0]+.2,t[1]-.12,t[0]+.33,t[1]-.1,t[0]+.35,t[1]-.2); x.bezierCurveTo(t[0]+.37,t[1]-.3,t[0]+.25,t[1]-.3,t[0]+.28,t[1]-.2); x.bezierCurveTo(t[0]+.31,t[1]-.1,t[0]+.42,t[1]-.12,t[0]+.5,t[1]-.17); x.stroke() }
  x.save(); x.translate(t[0]+.5,t[1]-.17); x.rotate(.15); x.scale(-.95,.95);   // the leaf at the end of the tendril
  const leaf=new Path2D(); for(const [u,v,a] of [[-.13,-.07,-.6],[-.26,-.08,0],[-.18,.05,.6]]) leaf.addPath(ell(u,v,.11,.075,a));   // three lobes
  x.fillStyle=lin(x,0,-.15,-.3,0,0,'#8FD14F',1,'#4D8C12'); x.fill(leaf); clay(x,leaf,[-.5,-.3,.05,.15],k,.3,.2);
  x.lineCap='round'; x.lineWidth=.02; x.strokeStyle='rgba(30,60,0,.4)'; x.beginPath(); x.moveTo(-.02,-.01); x.quadraticCurveTo(-.18,-.08,-.32,-.03); x.stroke(); x.restore() }) }

/* ---------------- FEATURE ---------------- */
// Where each outfit draws: behind (behind the body), body, headBack (behind the facial disc and tufts), headFront.
const DRAW={partyHat:{kind:'hat',headBack:partyHat},beanie:{kind:'hat',headBack:beanie},crown:{kind:'hat',headBack:crown},
  sunglasses:{kind:'glasses',headFront:sunglasses},roundGlasses:{kind:'glasses',headFront:roundGlasses},bow:{kind:'bow',headFront:bow},
  scarf:{kind:'scarf',headBack:scarf},witchHat:{kind:'hat',headBack:witchHat},pumpkin:{kind:'fade',behind:pumpkinLobes,body:pumpkinBody,headBack:pumpkinStem},
  santaHat:{kind:'hat',headBack:santaHat},bunnyEars:{kind:'hat',behind:bunnyEars}};
// Below full opacity an accessory is drawn as one group (Swift's drawLayer), so its parts never show through each other;
// each bot keeps its own group canvas at its own size. The body layer (the pumpkin tint) blends with the body under it,
// so it fades in place.
const groups=new WeakMap();
const layer=name=>(b,d)=>{ const o=DRAW[b.outfit], fn=o&&o[name], p=b.s.outfitP, a=p<.001?0:o&&o.kind==='hat'?1:Math.min(1,p*2.5); if(!fn||a<.005) return;
  const grp=a<1&&name!=='body'; let x=d.x, g=groups.get(b);
  if(grp){ if(!g) groups.set(b,g=document.createElement('canvas')); if(g.width!==d.W||g.height!==d.H){ g.width=d.W; g.height=d.H }
    x=g.getContext('2d'); x.save(); x.setTransform(1,0,0,1,0,0); x.clearRect(0,0,d.W,d.H); x.setTransform(d.x.getTransform()) }
  if(name==='behind'&&o.kind==='hat'){ const H=d.head; x.transform(H.a,H.b,H.c,H.d,H.e,H.f) }   // the bunny ears move with the head; pumpkin lobes with the body
  fn(x,stage(b,d,o.kind,x,grp?1:a),d);
  if(grp){ x.restore(); d.x.save(); d.x.setTransform(1,0,0,1,0,0); d.x.globalAlpha=a; d.x.drawImage(g,0,0); d.x.restore() } };

register({name:'outfits',
  init(b){ b.outfit=b.outfitTarget='none'; b.set('outfitP',0) },
  layers:{behind:layer('behind'),body:layer('body'),headBack:layer('headBack'),headFront:layer('headFront')},
  // ?outfit=<rawValue|auto> wears it from the start; ?film=wear&wear=<id> animates to it (from ?outfit when given);
  // without &wear= it picks one at random, none included (as ?soak does).
  capture(b,p){ if(p.has('outfit')) wear(b,pick(p.get('outfit')),false) },
  actions:{wear:b=>{ const ids=[...Object.keys(OUTFITS),'none']; wear(b,pick(params.get('wear')||ids[Math.floor(Koru.rand()*ids.length)])) }},
  // At rest the shown outfit is the chosen one and outfitP sits at 0 (none) or 1.
  soak(b,bad){ if(b.outfit!==b.outfitTarget||b.s.outfitP!==(b.outfit==='none'?0:1)) bad.push(`outfit:${b.outfit}/${b.outfitTarget}@${b.s.outfitP.toFixed(3)}`) },
  // Live page: the main bot and the notch mini wear the same outfit; ?outfit= presets it there too. The worn choice is marked.
  controls(ui,bots){ ui.group('Roupa'); const btns={}, set=(o,id)=>{ for(const b of [bots.main,bots.mini]) wear(b,o); for(const q in btns) btns[q].classList.toggle('on',q===id) };
    for(const id in OUTFITS) btns[id]=ui.button(OUTFITS[id][0],OUTFITS[id][1],()=>set(id,id));
    btns.none=ui.button('Sem roupa','#6B7280',()=>set('none','none')); btns.auto=ui.button('Auto','#94A3B8',()=>set(seasonal(today()),'auto'));
    const o=params.get('outfit'); if(o) for(const b of [bots.main,bots.mini]) wear(b,pick(o),false);
    btns[o==='auto'?'auto':pick(o)].classList.add('on') }
});
})();
