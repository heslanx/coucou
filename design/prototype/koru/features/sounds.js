// Sounds: Koncluí's own set, played on the bot's sound events (states, emotes, greet, slap, gulp, listening) as the Mac app does.
// The files are scripts/konclui/sounds.py's output (konclui branch) converted to AAC. Only the live main bot plays them:
// captures run on the virtual clock and stay silent, and the notch minis are quiet as in the app.
(()=>{
const {register,Clock}=Koru;
const NAMES=['annoyed','approval','approve','attach','blip','close','dizzy','error','finish','greet','greeting','gulp','hover','love','open',
  'peek','pop','proud','question','rate','search','send','slap','sleep','think','tick','wink','work','yawn'];
let on=true, volume=.6;
const pools={};   // two players a sound, so a quick repeat overlaps the first instead of cutting it
function play(name){ if(Clock.virtual) return;
  const pool=pools[name]||(pools[name]=[0,1].map(()=>{ const a=new Audio(`koru/sounds/${name}.m4a`); a.preload='auto'; return a }));
  const a=pool.find(p=>p.paused)||pool[0]; a.currentTime=0; a.volume=volume;
  a.play().catch(()=>{}) }   // refused until the page has had a click (browser autoplay rule): that sound is simply skipped

register({name:'sounds',
  onSound(b,name){ if(on&&!b.mini) play(name) },
  controls(ui){ ui.group('Sons'); ui.toggle('Som','#3CCFD9',v=>{ on=v }).classList.add('on'); ui.slider('Volume',0,1,.05,volume,v=>{ volume=v });
    for(const n of NAMES) ui.button(n,'#5B6472',()=>play(n)) }
});
})();
