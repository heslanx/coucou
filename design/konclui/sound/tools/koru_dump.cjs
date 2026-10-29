// Renders Koru's 8 official sounds with lib/koru-sound.js (read-only require) and writes raw float32 here.
const fs = require('fs');
const path = require('path');
const KoruSound = require('/Users/erickheslan/Developments/konclui-project/koru/lib/koru-sound.js');
const sr = +(process.argv[2] || 48000);
const out = process.argv[3];
for (const name of ['chirp', 'chirp-double', 'chime-rise', 'boop-down', 'tick', 'tick-double', 'whoosh', 'thump']) {
  const x = KoruSound.render(name, sr);
  fs.writeFileSync(path.join(out, `${name}-${sr}.f32`), Buffer.from(x.buffer));
  console.log(name, x.length);
}
