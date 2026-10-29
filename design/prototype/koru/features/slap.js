// Slap: a click annoys Koru, and three in a row make her dizzy.
// Ports BotEngine.swift slap() 423-444 (interruptGreet, squash, lag-spring kick, line eyes 0.8 s, 3 slaps in 1.7 s = dizzy),
// IslandWindowController.swift handleDizzy() 1311-1326 (dizzy for 3.3 s, then the previous state and a happy emote)
// and the violet glow of notch-buddy.html slap() 795-796 (0.9 s).
(()=>{
const {register,E,NOW,rand,EMOTES,eyeShapes,hexRgb,rgba,mix,inner,rr,floorPool,sheet,stamp}=Koru;
const COOL=80;                                            // ms: a double-click is two slaps, a duplicated event is not
const VIOLET=hexRgb('#A855F7'), DEEP=hexRgb('#7C3AED'), PALE=mix(VIOLET,[255,255,255],.2);
// The line eyes of BotEngine.swift (case .line, 1576), slanted more: the knock tilts the head, which would flatten one of them.
EMOTES.slapped={eye:'slapped'};
eyeShapes.slapped=(b,{x,R,dr,sd,ink})=>{ x.save(); x.rotate(-sd*.4); x.fillStyle=ink; rr(x,-dr*.48,-R*.06,dr*.96,R*.12,R*.06); x.fill(); x.restore() };
function slap(b){ const k=b.slap, n=NOW();
  b.interruptGreet(); if(b.state==='dizzy'||n-k.last<COOL) return; k.last=n;
  k.times=k.times.filter(t=>n-t<1700); k.times.push(n);
  const sd=rand()<.5?-1:1; b.squash(); b.physVy-=1.2; b.physVx+=.7*sd;
  // Mochi shows the kick only on its outfits; Koru rocks her head and body away from the hit.
  b.anim('knock',[[sd,90,E.out],[-.3*sd,220,E.inOut],[0,260,E.out]]);
  b.anim('slapGlow',[[1,120,E.out],[1,500,E.lin],[0,280,E.inOut]]);
  // The spiral eyes show at once: the line eyes of the slap before would otherwise hold over them.
  if(k.times.length>=3){ k.times=[]; const back=b.state; b.clearOverride(); b.setState('dizzy');
    b.after('slapDizzy',3300,()=>{ b.setState(back); b.emote('happy') }) }
  else b.emote('slapped',800) }
function slap3(b){ slap(b); b.after('slap3a',250,()=>slap(b)); b.after('slap3b',500,()=>slap(b)) }

register({name:'slap',
  init(b){ b.slap={times:[],last:-1e9}; b.set('knock',0); b.set('slapGlow',0) },
  onClick(b){ slap(b); return true },
  // Another state chosen while dizzy wins over the recovery.
  onState(b,prev,next){ if(prev==='dizzy'&&next!=='dizzy') b.cancel('slapDizzy') },
  modify(b,m){ const k=b.s.knock; if(Math.abs(k)<.002) return;
    m.headTilt+=k*.17; m.rot+=k*.04; m.ox+=k*.03; m.flap+=Math.abs(k)*.22 },
  // The violet glow as the core's state light: a floor band and pool, and a rim along the base.
  layers:{floor(b,d){ const g=b.s.slapGlow; if(g<.01) return; const {x,cx,cy,rx,ryB,sy}=d;
    for(const [k,sk,r,a0] of [[1.0,.1,1.2,1],[1.03,.2,1.6,.5]])
      floorPool(x,cx,cy+ryB*sy*k,rx*r,sk,[[0,rgba(VIOLET,a0*g)],[.4,rgba(DEEP,.7*a0*g)],[.75,rgba(DEEP,.2*a0*g)],[1,rgba(DEEP,0)]]) },
    // The rim along the lower body is cached once per size and faded upward, so it has no edge where it ends on the sides.
    body(b,d){ const g=b.s.slapGlow; if(g<.01||!d.full) return; const {x,R,rx,ryB,body}=d, BB=[-rx,-R*.2,rx,ryB];
      x.globalAlpha=g; stamp(x,sheet('slapRim'+R,[-rx-2,-R*.2,rx+2,ryB+2],c=>{ inner(c,body,rgba(VIOLET,.8),R*.075,0,-R*.035,BB); inner(c,body,rgba(PALE,.3),R*.03,0,-R*.015,BB);
        const fade=c.createLinearGradient(0,-R*.2,0,ryB*.75); fade.addColorStop(0,'rgba(0,0,0,0)'); fade.addColorStop(1,'#000');
        c.globalCompositeOperation='destination-in'; c.fillStyle=fade; c.fillRect(-rx-R,-R*1.2,2*rx+2*R,ryB+R*2.4) },R*.3)) }},
  actions:{slap,slap3},
  soak(b,bad){ for(const v of ['knock','slapGlow']) if(Math.abs(b.s[v])>.01) bad.push(v+':'+b.s[v].toFixed(2)) },
  // ?shot=<state>&slap=<ms>[&slaps=<n>][&lx=<look x>]: n slaps 250 ms apart, the last one <ms> before the 2.2 s still.
  capture(b,p){ if(!p.has('slap')) return; const n=+(p.get('slaps')||1), at=2200-(+p.get('slap')); if(p.has('lx')) b.look.x=+p.get('lx');
    for(let i=0;i<n;i++) b.after('slapShot'+i,Math.max(0,at-(n-1-i)*250),()=>slap(b)) },
  controls(ui,bots){ ui.group('Tapa'); ui.button('Tapa','#A855F7',()=>slap(bots.main)); ui.button('3 tapas','#FF5AAA',()=>slap3(bots.main)) }
});
})();
