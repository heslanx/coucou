// Dance: Koru dances at 112 BPM while music plays (BotEngine.swift applyDance).
// Ports BotEngine.swift applyDance() 1110-1124 (a hop on every beat, a sway and a 0.1 rad lean over two beats around the base,
// a squash on landing), the dancingLevel ramp 1082-1088 (linear, in over 0.3 s, out over 0.5 s), drawEyes() 1515-1517 (happy
// eyes while idle or finished, not on minis) and BotCanvasView.swift 67-84 (dances only while idle, working, thinking, searching, finished).
(()=>{
const {register,NOW,clamp,mix,rgba,floorPool}=Koru;
const BPM=112, DANCES={idle:1,working:1,thinking:1,searching:1,finished:1}, CALM={idle:1,finished:1};
let held=null;                                             // ?beat=<b> holds the beat still for a capture
// One clock for every bot, as Swift's CACurrentMediaTime(): Koru and the minis dance in step.
const beat=()=>held??NOW()/1000*BPM/60;

register({name:'dance',
  init(b){ b.dance={on:false,go:false,l:0,lift:0} },
  update(b,dt){ const D=b.dance; D.go=D.on&&!!DANCES[b.state]; D.l=D.go?Math.min(1,D.l+dt/.3):Math.max(0,D.l-dt/.5) },
  modify(b,m){ const D=b.dance, l=D.l; D.lift=0; if(l<=.001) return;
    const p=Math.PI*beat(), sw=Math.sin(p), hop=Math.abs(sw), land=Math.pow(1-hop,6);
    D.lift=.2*hop*l; m.ox+=.08*sw*l; m.oy-=D.lift; m.rot+=.1*sw*l; m.sx*=1+.045*land*l; m.sy*=1-.06*land*l;
    // Mochi has no wings or head of his own; Koru's follow the beat a little late: the wings open on the way up,
    // the head (and its tufts) swings after the body and nods on landing.
    m.flap+=(.12+.22*Math.abs(Math.sin(p-.3)))*l; m.headTilt+=.06*Math.sin(p-.9)*l; m.headY+=.025*Math.pow(1-Math.abs(Math.sin(p-.5)),4)*l;
    if(D.go&&l>.15&&!b.mini&&CALM[b.state]&&!m.eye) m.eye='happy' },
  // Core's floor glow rises with her base; a pool left lit on the floor, as core's two bands, shows the hop.
  layers:{floor(b,d){ const k=b.dance.lift/.2; if(k<.02||d.mini) return; const {x,R,cx,cy,rx,ryB,col}=d, a=k*(.4+.6*b.s.go), y=cy+b.dance.lift*R+ryB;
    for(const [sy,r,a0] of [[.09,1.15,1],[.16,1.4,.45]])
      floorPool(x,cx,y,rx*r,sy,[[0,rgba(mix(col,[255,255,255],.2),clamp(a*a0,0,1))],[.2,rgba(col,clamp(.8*a*a0,0,1))],[.45,rgba(col,clamp(.45*a*a0,0,1))],[.75,rgba(col,.12*a*a0)],[1,rgba(col,0)]]) }},
  // A song of 1.6 s: the dance sets in, holds and fades (with ?dance=1 it is already on and keeps going).
  actions:{dance(b){ const D=b.dance; if(D.on) return; D.on=true; b.after('dance',1600,()=>{ D.on=false }) }},
  soak(b,bad){ const D=b.dance; if(D.on||D.l>.001) bad.push('dance:'+D.l.toFixed(2)) },
  // ?dance=1 dances from the first frame; &beat=<b> holds the beat (.5 = top of the hop, leaning right; 0 = landing); &lx=<look x>.
  capture(b,p){ if(p.has('beat')) held=+p.get('beat'); if(!p.has('dance')||p.get('dance')==='0') return;
    b.dance.on=true; b.dance.l=1; if(p.has('lx')) b.look.x=+p.get('lx') },
  controls(ui,{main,mini,mini2}){ ui.group('Música'); ui.toggle('Música','#FA2D48',v=>{ for(const b of [main,mini,mini2]) b.dance.on=v }) }
});
})();
