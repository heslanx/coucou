# Koru prototype: Organic Life motion

This page maps the Koru motion doctrine (`konclui-project/koru/docs/motion-doctrine.md`, with its numbers in `spec/motion.json`
and its scheduler in `lib/koru-motion.js`) onto this prototype, rule by rule. The prototype is the Mochi engine (`koru/core.js`,
ported from Coucou's `BotEngine.swift`) drawing the Koncluí owl, so two authorities meet here: the doctrine, and Coucou parity,
which the owner asked to keep. Where they disagree the table says so and leaves the shipped behaviour alone.

What the doctrine brings is in one feature, `koru/features/life.js`, loaded after every feature that moves Koru and before
`sounds.js`.

## What life.js does

| Layer | Behaviour | Numbers | Rules |
|---|---|---|---|
| Breath | A 4 s chest rise under every state that does not breathe on its own. Sleeping keeps core's breath and dizzy its wobble, so the breath eases out under those two. | body squash 1 → 1.02 → 1, quadratic in-out (`spec/motion.json` `breathe`); width compensated as core's own breath is (`core.js:337`) | LIFE-01 |
| Moving hold | A second carrier that never lines up with the breath, so a held pose is never frozen. | 3600 ms, +0.75 % / −0.5 %, damped settle (`lifeComposition.movingHold`) | LIFE-02 |
| Follow-through | The body leads. The head trails the body's carry point (offset, squash, lean) through a critically damped follower, 40 ms behind a steady motion: a vertical lag lifts or lowers the head, a sideways one tilts it on the neck. The tuft tips trail the top of the head through a second follower, 40 ms more, ζ = 0.75 (a step overshoots 2.8 %), and bend as core's ear does. | head ω 50 rad/s, ζ 1, lag ≤ 0.03 R and ≤ 0.05 rad; tufts ω 37.5, ζ 0.75, ear ≤ 0.3 | ANIM-05, TIME-03 |
| Micro-actions | While she idles, one at a time, from the doctrine's catalogue: glance, peer, micro-tilt, weight shift, wing flick (L, R), tuft twitch (L, R), beak nibble, bill adjust, double blink, single blink (L, R). Durations and keys are the spec's, retargeted to this rig (table below). | about one every 7 s, at least 2 s apart | LIFE-01, PERF-03, PRODUCT-04 |
| Reduced motion | The OS setting, followed live, or the page's toggle. Life stops at once, and core's continuous loops are held at rest: the approval bounce, the sleeping breath, the search scan, the dizzy sway. The state still shows by its colour, eyes and badge. | — | A11Y-01, A11Y-02, A11Y-03 |

### Scheduling

- One scheduler per Koru, one micro-action at a time. Each action has its own window and its own seeded sequence of draws (the
  hash of `lib/koru-motion.js`), so no two windows fall into step.
- The spec's windows add up to 0.57 actions a second, more than one-at-a-time playback can serve. Queued, they run back to back,
  and the glance, whose window is about one action plus one rest long, locks into step with the cycle (seed 4 played nine
  glances in a row). So: every window is twice as long (`CALM = 2`, the ratios kept). Each clock starts at a random point of
  its window, as if she had been idling all along. After each action she rests 2 to 4 s. An action that comes due while she
  plays or rests is let go and re-armed from its own window instead of being queued. 300 s traces, seeds 1 to 4: 40 to 45
  actions, a mean interval of 6.7 to 7.5 s, at least 2.2 s between two actions, never the same action three times in a row.
- The idle clock runs only while she idles: in the idle state, with no emote eyes, no raised wing, no core tween moving her,
  and no other feature moving her. Life runs after every other feature, so it reads their whole frame from the modifiers. A
  reaction pauses every window, and a rest follows it. An action caught by a reaction lets go in 150 ms.
- While the page is hidden it draws nothing. Life skips any gap over 250 ms, so nothing missed is replayed on return.
- No timers and no polling. Everything advances in the frame's update from the declared durations.

### The catalogue on this rig

| Action | ms | Spec window (s) | Here | Adapted |
|---|---:|---|---|---|
| glance | 1800 | 7–9 | pupils to 0.6 of their reach, away from where she looks; 1° head lead | head tilt stands for the spec's body tilt |
| peer | 1500 | 16–28 | head turn 0.075 (of 0.62), pupils +0.18, 0.6° head tilt | — |
| micro-tilt | 900 | 12–20 | 1.5° body lean around the base | — |
| weight shift | 2400 | 26–46 | 2° lean over each side, 0.012 R shift, squash 0.985 | no feet in this rig: the body leans over each side, 2° where the spec has 2.5° |
| wing flick L / R | 700 | 17–27 / 10–15 | resting wing swings out 0.2 rad, settles slowly | 0.2 rad (about 11°), not the spec's 9°: the 9° read too faint at 300 px |
| tuft twitch L / R | 900 | 36–60 / 28–48 | one tuft perks (ear −0.4), the other counters (+0.16) | — |
| beak nibble | 560 | 15–25 | two partings to 0.2 | the bill parts along a shallow V and the lower half drops; drawn by life only while no other feature draws the beak |
| bill adjust | 700 | 36–60 | bill turns 3°, counter −1.5°; parts 0.22 / 0.08 / 0.16 | the spec's `settle` ease overshoots about 10 %: replaced by a damped settle |
| double blink | 420 | 20–40 | both lids, two closes | no per-pupil scale here, so no pupil warm-up |
| single blink L / R | 480 | 42–70 / 52–85 | one lid, slow | — |

The spec's `blink` is core's own blink (`core.js:343-346`, Coucou parity). `pupil-tremble` and `squash-blink` are retargeted
from third-party reference timelines and were left out. `foot-scratch` needs feet, and `soft-yawn` is never auto-scheduled
(core has its yawn emote).

### Core hooks

Per-side controls that a feature cannot reach through the existing modifiers. They are zero by default, so every capture is
pixel-identical. `core.js` only:

- `MODS` (`core.js:239`): `tuftL`, `tuftR`, `flapL`, `flapR`, `lidL`, `lidR`. L is viewer-left.
- Tufts (`core.js:479`): each side adds its `tuft*` to `s.ear`. Tuft twitch and tuft follow-through need one side at a time.
- Wings (`core.js:398-402`): each resting wing adds its `flap*` to `m.flap`. The wing flick moves one wing.
- Lids (`core.js:508`): each eye closes at least as far as its `lid*`. Single and double blinks without core's shared `open` tween.

### Parameters and controls

- Live: on. The **Vida** group has the Vida toggle (eases in and out in 200 ms), a Movimento reduzido toggle, and one button per
  micro-action. `?life=0` starts with life off.
- Captures (`?shot`, `?grid`, `?film`, `?soak`, `?bench`) are unchanged unless `?life=1`. With it, `&seed=<k>` picks the jitter
  (default 1), `&reduce=1` forces reduced motion, `&lifetrace=1` prints the scheduler's trace in `<pre id="lifetrace">`,
  `?film=life` films her idling and `?film=life-<action>` films one micro-action. A capture follows the OS reduced-motion
  setting only with `?life=1`, so stills never depend on the machine.
- The notch minis run no life. They are Coucou's agent indicators and keep their own behaviour.

## Rule by rule

Status: **Met** (already true, with the evidence), **Adopted** (life.js does it now), **Adapted** (how), **N/A** (why),
**Owner** (conflicts with an owner decision; kept, with a proposal), **Gap** (not done; the proposal).

### Animation principles

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| ANIM-01 squash keeps volume | MUST | Met | Squash and stretch are reciprocal (`core.js:288`), the breath compensates its width (`core.js:337`). Life's carriers reuse that compensation (`life.js:139-140`) and peak at +2.8 %. |
| ANIM-02 anticipation | SHOULD | Owner | Reactions are `BotEngine.swift` ports with Coucou's timings (`core.js:264-267`, `288`, `299-306`). No anticipation was added, to keep parity. Proposal: a 60–80 ms dip before the approval hop and the greet, if the owner wants it. |
| ANIM-03 staging | MUST | Met | One state, one badge and one emote at a time. Micro-actions never play over a reaction (`life.js:134`). |
| ANIM-04 pose to pose | MAY | Met | States are key poses (`STATES`, `core.js:44-56`), and every micro-action track ends on its rest key (`life.js:35-48`). |
| ANIM-05 follow-through | MUST | Adopted | Head 40 ms behind (critically damped), tufts 40 ms more, under-damped to 2.8 % (`life.js:144-153`). See the follow-through films below. |
| ANIM-06 slow in / slow out | MUST | Met | Core tweens use `E.out`, `E.inOut` and `E.back` (`core.js:27`), and targets ease exponentially (`core.js:340-341`). Linear appears only as holds. Life's tracks use the doctrine's role eases (`life.js:15`). |
| ANIM-07 arcs | MUST | Adapted | Joints rotate round pivots: the head on the neck, the body lean on the base (`core.js:385`), the wing at its root (`core.js:400-409`). Life's lean, tilt and flick are those rotations, so they arc. Core's sideways error shake is straight, for Coucou parity. |
| ANIM-08 secondary action | SHOULD | Adopted | Micro-actions are subordinate, one per beat, and never under a reaction (`life.js:125-127`, `134`). |
| ANIM-09 timing from the spec | MUST | Adapted | Core's timings are `BotEngine.swift`'s. Life keeps `spec/motion.json`'s durations, keys and windows (`life.js:35-48`), with the windows doubled (`life.js:54`, see Scheduling). |
| ANIM-10 exaggeration in bounds | MAY | Met | Life's largest moves: a 2° lean, a 0.2 rad wing flick, a 0.4 ear perk. Smaller than core's reactions. |
| ANIM-11 solid drawing | MUST | Met | Squash keeps the base on the floor (`core.js:382-383`), and leans pivot on the base. This rig has a front view only: profile and back are N/A. |
| ANIM-12 calm appeal | MUST | Adopted | About one quiet micro-action every 7 s, none attention-seeking. See the 20 s idle sheet. |

### Organic Life

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| LIFE-01 breath and independent windows | MUST | Adopted | The 4 s breath runs under every state except sleeping and dizzy (`life.js:24-25`, `139`), which keep core's own motion. Core's blink has its own jittered window (`core.js:343-346`, 2.2–5.4 s). Each micro-action has its own seeded window (`life.js:60-63`). The windows are adapted ×2 (Scheduling). |
| LIFE-02 moving hold | MUST | Adopted | 3600 ms, ±0.75 % (`life.js:24`). Static under reduced motion or when the toggle is off (`life.js:115`). |
| LIFE-06 tail | MUST | N/A | This Koru has no tail. |
| LIFE-08 deterministic release | MUST | Met | Core transients end at rest (`?soak` seeds 1–4 SETTLED, with and without life). Every life track ends on its rest key, and an interrupted one lets go in 150 ms (`life.js:122`). |

### Staging

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| STAGE-01 one focal action | MUST | Adopted | One micro-action at a time. The carriers stay subordinate (≤ 2.8 % squash, head lag ≤ 0.03 R). |
| STAGE-02 never cover controls | MUST NOT | N/A | Koru's canvas holds no control here; the notch layout in the app owns this. Life moves her at most 0.012 R sideways. |

### Timing and easing

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| TIME-01 reactions in 200–600 ms | SHOULD | Met / Owner | Blink 200 ms, squash 370 ms, approval hop 450 ms. The greet wave (1.55 s) and the dizzy recovery (3.3 s) are Coucou's. |
| TIME-02 celebration ≤ 1200 ms, interruptible | MUST | Met | The finished roll takes 950 ms (`core.js:264`, `287`), and any state change replaces it. |
| TIME-03 release ≤ 200 ms without a pop | MUST | Adopted | An interrupted micro-action fades in 150 ms. The followers settle in about 130 ms (1 %). The toggle eases in 200 ms. Reduced motion stops at once, by precedence. Core: a greet lets go in 150 ms (`core.js:307`). `?soak` asserts the follow-through lag is back under 0.01 R (`life.js:162-163`). |
| TIME-04 easing by role | MUST | Met / Adopted | Core uses out for responses, in-out for travel, back for settles. Life uses the doctrine's micro / travel / layout roles (`life.js:15`). |
| TIME-05 duration grows with distance and mass | SHOULD | N/A | No travel clips: Koru stays in place in this prototype. |

### Accessibility and safety

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| A11Y-01 accessibility first | MUST | Adopted | Reduced motion overrides life and core's loops (`life.js:110`, `115`). |
| A11Y-02 live preference | MUST | Adopted | Follows the `prefers-reduced-motion` media query, changes included, with no reload (`life.js:72-75`). Checked with Chrome's `--force-prefers-reduced-motion`. |
| A11Y-03 reduced: no bob, no ambient timers, outcome kept | MUST | Adopted / Gap | Life goes static, and the approval bounce, sleeping breath, search scan and dizzy sway are held (`life.js:110`). The state still shows by colour, eyes, badge and label. **Gap:** core draw-level loops still move: the z and sweat particles, the badge dot pulse, the spiral and star eye spin, the dizzy wobble lines. One-shot reactions (squash, roll, hops, greet) still play, and sound is `sounds.js`'s (K7). Proposal: a shared `Koru.still` flag. Core would read it to skip particles and pulses and to jump tweens to their end (the spec's `reducedMotion: end`), and each feature would read it to still its own loops. |
| A11Y-04 motion never the only carrier | MUST | Met | Every state has a colour, a badge, an eye shape and a label (`core.js:44-56`; the page's state buttons). |
| A11Y-05 pause, stop, hide | MUST | Adopted / Gap | The Vida toggle stops life and the Movimento reduzido toggle stills her. Core's state loops have no separate pause outside reduced motion: they are state indicators. |
| A11Y-06 no flashing | MUST NOT | Met | No flashes. The pulsing glows run at about 1 Hz, well under three a second. |
| A11Y-07 input and focus preserved | MUST | Met | Life uses no timers, takes no focus and blocks no input. A click always reaches `onClick`. |

### Product restraint

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| PRODUCT-01 motion has a purpose | MUST | Adapted | Idle life shows she is present and attentive, the doctrine's own case (OL-01/02). Each micro-action rests on a static pose. |
| PRODUCT-02 no shame or pressure | MUST NOT | Met | Nothing punitive. The error state is Coucou's short shake with flat eyes. |
| PRODUCT-03 one Koru | SHOULD | Met | One Koru on the stage. The notch minis are Coucou's agent indicators and run no life. |
| PRODUCT-04 idle never solicits | MUST NOT | Adopted | The catalogue has no wave, jump, pulse or shake (`life.js:35-48`). The greet wave plays only on its action. |
| PRODUCT-05 brief, causal reactions | SHOULD | Met | Reactions follow states, emotes and clicks (Coucou parity). |
| PRODUCT-06 one prop | MUST | N/A | Life adds no prop. Props belong to `outfits.js` and `gulp.js` and were not audited here. |

### Performance and lifecycle

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| PERF-01 suspend when hidden, no replay | MUST | Adopted | The page draws on `requestAnimationFrame`, which stops while hidden. Life skips gaps over 250 ms (`life.js:114`), and a reaction pauses the idle clock (`life.js:119`). |
| PERF-02 no polling | MUST NOT | Adopted | No timers in life. Actions end by their declared duration (`life.js:122-123`), and the followers are damped equations with fixed 2 ms steps (`life.js:67-69`). |
| PERF-03 one scheduler, one action | MUST | Adopted | One `act` per Koru (`life.js:87-90`). `?soak` asserts no overlap (`life.js:162`). The traces alternate start and end for 300 s on seeds 1–4. |
| PERF-04 within a frame | SHOULD | Gap | Not proven on target hardware. The headless bench uses software rendering at 1416 px and misses a 16.7 ms frame even with life off. Life's own logic costs nothing measurable: life on but held still costs the same as life off. The breath does cost: while the body's scale differs from 1, every cached sheet is resampled rather than copied, the same cost core's sleeping and working states already pay (see Evidence). To measure: a live GPU profile of the page. |
| PERF-05 dispose on destroy | MUST | N/A | Bots are never destroyed in the prototype. Life holds no timer and one module-level media-query listener. The Swift port must remove its observers. |
| PERF-06 minimum properties | SHOULD | Met | Life writes the existing modifiers only, and the beak reuses core's cached closed-beak sheets. |

### Topology and continuity

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| TOPO-01 morph topology | MUST | Met | Every shape is a fixed point list: body 121 points, rings 72, tufts 14 through Chaikin (`core.js:110-119`, `183-198`). The tuft bend and ear only move those points. |
| TOPO-02 no fades or swaps of anatomy | MUST NOT | Owner | Three conflicts, all kept. (1) While a wing turns over to wave, its two faces cross-fade (`core.js:418-420`). (2) A wing folding behind the body fades its front copy (`core.js:429-430`, `464`). (3) The eye shapes swap: happy, heart, star, spiral, wink and line replace the pupil (`core.js:469`, `582-598`), Coucou's emote vocabulary. Proposals: turn the wing over as a compatible morph whose back face is occluded by the body, and fold it behind by geometric occlusion only. The eye swaps would need the owner's decision, since they are Coucou's emotes. Life adds no fade: its lids and bill are geometric. |
| TOPO-03 no collapse to zero | MUST NOT | Met | The wing's turn never goes below 0.3 of its width (`core.js:409`). The fold scales to 0.75 at most. The badges that scale from zero are not anatomy. |
| TOPO-04 depth by articulation or occlusion | MUST | Owner | The far wing goes behind the body as a drawn copy (occlusion) while the front copy fades: the TOPO-02 conflict above. |
| TOPO-05 endpoints in a shared rig | MUST | N/A | The prototype has no `spec/rig.json`. Its endpoints are `core.js` constants, and the Swift port re-implements them (K2). |
| TOPO-06 shipping continuity gates | MUST | Gap | Not a shipping build. Its continuity checks are the grid diff and `?soak`. |

### IP safeguards and evidence governance

| Rule | Level | Status | Evidence / how |
|---|---|---|---|
| IP-01 references are not copied | MUST | Met | Life's values come from Koru's own `spec/motion.json`. The clips retargeted from third-party timelines (`pupil-tremble`, `squash-blink`, the reactions) were not used. |
| IP-02 Puka → Pucca | MUST | Met | The prototype names no third-party character. |
| IP-03 no third-party media | MUST NOT | Met | Life ships no asset. |
| IP-04 provenance of non-original assets | MUST | N/A | No non-original asset added. |
| IP-05 inspiration at principle level | SHOULD | Met | Life implements the doctrine's principles on this rig's own construction. |
| IP-06 no implied endorsement | MUST NOT | Met | This page cites only the Koru project. |
| EVIDENCE-01 / 02 | MUST | N/A | Source governance lives in the Koru project. This page adds no external source. |

## Evidence

Commands, from `design/prototype/` (headless Chrome, `--virtual-time-budget`; see the capture notes at the top of
`koru.html`'s script):

- Captures unchanged: `koru.html?grid=1` before and after this change, max pixel difference 0, also with
  `--force-prefers-reduced-motion`. `?film=greet` and `?film=slap` without `?life` are identical too.
- `?soak=200&seed=<1..4>`: SETTLED, with and without `&life=1`.
- 20 s idle contact sheet: `?film=life&life=1&seed=3&step=666&n=30&px=300` (wing flick, glance, micro-tilt, beak nibble).
- One action: `?film=life-<action>&life=1&step=<ms/10>&n=12&px=240&lx=0`.
- Follow-through: `?film=slap` and `?film=greet` with `&state=idle&step=33&n=30&px=300&lx=0`, against the same with `&life=1`.
- Reduced motion: `?film=life&life=1&state=approval&step=100&n=12` with `&reduce=1`, or with Chrome's
  `--force-prefers-reduced-motion`: every frame identical to the first (the normal run bounces, up to 249 levels).
- Scheduler trace: `?film=life&life=1&seed=<k>&step=4000&n=75&px=40&lifetrace=1`, read with `--dump-dom`.
- Bench (headless, software rendering, minimum ms/frame of two runs): idle 28.8 / 30.5 with life off, 45.1 / 48.8 with life
  on, 26.9 with `&life=1&reduce=1` (life on, held still). For scale, without life: sleeping 43.5 (core's breath), working 59.2.
