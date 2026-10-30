# Koncluí — usability and product experience

The rules every screen, message and interaction of Koncluí follows. They come from the owner's product guide (the
same rules apply to all of Koncluí's projects), adapted here to a native macOS notch app. They are the review gate for
every change that touches what a person sees or does. Engineering rules are in [ENGINEERING.md](ENGINEERING.md); what the
fork changes and why is in [KONCLUI.md](../../KONCLUI.md).

**The goal:** a new person can use Koncluí alone, by clicking and learning. No mandatory training, support or tutorial,
and no fabricated urgency.

Where a rule from the web version of the guide has no meaning in a Mac app, section 9 says so and gives the native
equivalent, so nobody has to re-decide it.

---

## 1. The six interaction words

### 1.1 Frustrated click: no click without an answer
- Every control a person has a reason to click responds: with the result, with progress, or with an explanation.
  A click with no result, no explanation and no way out is a product defect, even when the code does what it was written to do
  (the classic case: a "Send" button that is disabled and silent because a required field is empty).
- A blocked control explains why in one line and points to the way out. In SwiftUI, do not leave a bare `.disabled(true)`
  with nothing next to it: keep the reason visible beside the control (not only in a hover tooltip), and guard the action
  itself so the explanation never bypasses validation.
- Resolution cascade for an unavailable action, in this order:
  1. **Remove**: if the control never makes sense in this context, do not show it.
  2. **Explain**: say in one line why it is blocked.
  3. **Redirect**: offer a link or move focus straight to the field or setting that is missing.
  4. **Resolve**: let the person fix it right there, in the same click.
- When a "I clicked and nothing happened" bug is found, fix the shared component everywhere it is used, not only on that screen,
  and list any occurrence left.

### 1.2 Door: every piece of data shown can be clicked
- No relevant piece of data is dead text. A name, phone number, path, agent, pill, status, date or count opens a small
  popover with **2 to 5 likely actions** for it. Examples in Koncluí: a WhatsApp number (open the chat, copy, ignore this chat);
  an agent row in Settings → Agents (install hooks, open its config file, copy the path); a session's pill (open its terminal,
  copy the folder); a path (reveal in Finder, copy).
- The most likely action is always first, and the order of actions is fixed per kind of data across every screen.
- The standard pattern for an integration or agent block is the **compact row + popover** (the owner's choice for WhatsApp,
  version 8 of `design/konclui/whatsapp/whatsapp-settings-10.html`): one calm line with the status; clicking it, or its
  "Options" button, opens a subtle popover built from the existing component (the same hooks block, the same toggles).
  Setup expands in place and collapses back to the line when it is done.

### 1.3 Habits: the ten habits of the product
1. **Measure friction**: notice where people get stuck or repeat clicks.
2. **Next best action**: suggest the logical next step and say why.
3. **Never lose work**: keep drafts, typed text and screen state through closing a popover, navigating or a lost connection.
4. **Never ask for what is already known**: fill in or infer what the Mac and Koncluí already know (installed CLIs, signed-in
   accounts, saved keys). Example: the Chat lists what this Mac is signed in to before asking for any API key.
5. **Proportional preview and confirmation**: show exactly what will change before state-changing, bulk or external actions
   (installing hooks shows the file diff and writes only after confirmation).
6. **Answer within 100 ms and roll back honestly**: if an optimistic change fails, put the screen back and say what happened.
7. **Stop dirty data at the door**: validate format and integrity while the person types or imports.
8. **Notify only what is actionable**: no alert about something the person does not need to, or cannot, decide on.
   The notch is a scarce place: only what deserves interrupting the person reaches it.
9. **Show the essential for the role**: adapt density and emphasis to what matters to the person using it.
10. **Explain the cause**: every automatic change, block or calculation shows the rule that produced it
    ("Hidden because no API key is saved", "Muted: group message without a mention").

### 1.4 Signal: affordance and sensory feedback
- Everything clickable shows the pointing-hand cursor. Native buttons and links already do; a custom clickable view
  (a row, a chip, a pill, a card) sets it explicitly (`.pointerStyle(.link)` on macOS 15+, or `NSCursor.pointingHand`
  on hover), with no exception.
- Sound, morphing icons and prefetching may reinforce the feeling of response when measured and under the person's control
  (Settings → Sound, volume, reduced motion), but they are never the only way information is given.
- **Hovering is silent**: passing the pointer over something never plays a sound by default.
- **The whole label is the target.** A disclosure (accordion) opens and closes from anywhere on its label row, not only
  from the chevron; the same goes for a row that expands. In SwiftUI use `KoncluiDisclosureStyle` (the hub window applies it
  to every `DisclosureGroup`; popovers are separate windows and apply it themselves).

### 1.5 Undo: the universal safety net
- Every click that changes data offers **Undo** right away, in a visible notice that stays long enough and is reachable
  with the keyboard.
- When the action cannot be undone (sending a message, writing another app's settings file), the screen shows a clear
  preview and a confirmation proportional to the impact, saying exactly what will be sent or written, and where.
- If an Undo fails, say the real reason.

### 1.6 Slice: lists, filters and the state of the view
Koncluí's lists (dictation history, Dictionary, Snippets, Notetaker notes, reminders, ignored chats, pills, agents) follow
one mechanic:
- One shared filter, sort and group control, in the same order and with the same keyboard shortcuts on every list.
- Switching between views of the same set (list, cards, calendar) never loses the filter, search, sort, grouping, selection
  or the open record.
- The view's state survives closing and reopening the window (the native equivalent of keeping it in the URL; see section 9).
- In work-queue modes (approvals, questions), the queue is visible, each item needs at most one action besides answering,
  and an item already handled in the session leaves the queue and does not come back.

---

## 2. The ten interface heuristics (screen standard)

Every new or changed screen meets these before it is done:

1. **Visibility of system status**
   - Every screen that loads data has four designed states: **loading**, **empty**, **error** and **partial**.
   - Every action gives visual feedback within **100 ms** (the result or a progress indicator).
   - Data that failed to load or does not exist reads **"unavailable"** ("indisponível"), never `0`.
2. **Match with the real world**: speak the person's language, never table, column or internal names, file formats or
   error codes (no `nb-hook`, `GOWA`, `ChatProvider` in a sentence a person must understand; technical details go under
   "Details").
3. **Control and freedom**: every flow has an obvious way out (Cancel, Back, Close) that keeps what was filled in, or warns
   before discarding it.
4. **Consistency and standards**: the same concept always has the same name, icon and behaviour across the app (glossary in
   section 5). Reuse the base components before creating a visual variation.
5. **Error prevention**: validate while typing; safe defaults. Truncated text shows in full as soon as it is interacted
   with. A direct click that changes a record's state opens a short confirmation popover saying what will change, followed
   by Undo once applied.
6. **Recognition rather than recall**: the available options, current values and the context of the decision stay on screen.
   Nobody has to memorise a value on one screen to type it on another.
7. **Flexibility and efficiency**: repeated tasks have a fast path (keyboard shortcuts, bulk actions, saved filters) without
   hiding the step-by-step path for beginners.
8. **Aesthetics, minimalism and hierarchy**: every element helps the current decision; secondary information is on demand.
   **One primary action per region**, checked with the squint test (blur your eyes: the primary button is the only obvious
   point of emphasis). Block notices and hints stay discreet and never compete with it.
9. **Error recovery**: error messages are written for people and answer three questions: what happened, what the impact is,
   what to do now.
10. **Help in context**: a concept or field that does not explain itself carries a short instruction where it is filled in.

---

## 3. Transparency, traceability and zero silent errors

A person can audit numbers and understand failures alone, without asking "why didn't this run?" or "where does this number
come from?".

- **No silent error.** No failure is swallowed in code. An exception never becomes a fake success, a silently empty list or a
  chart at zero.
- **Background errors show on the affected thing.** When a poller (GitHub, Vercel, Stripe…), a hook, the WhatsApp gateway,
  the MCP bridge or a chat route fails in the background, the error shows on the pill or card it affects and in its Settings
  block, not only in a log.
- **A toast is not enough.** A notice that disappears by itself, or a red icon with no details on click, is never the only
  evidence of a failure.
- **Granular operational states**, told apart in the interface: *Done*, *Waiting*, *Retrying*, *Skipped by a rule* (saying
  which rule), *No matching record*, *Delivery unknown*, *Failed*.
- **Failure memory.** When an operation fails and then recovers on a retry, its history keeps the earlier failure.
- **Inspection has no side effect.** Opening the details of an error, log or metric only reads; retrying or fixing are
  separate buttons.
- **Every number is clickable, zero included.** Any metric, total or counter (Statistics: words dictated, words per minute,
  day streak; usage gauges; counts in lists) opens a side sheet showing (1) where the number comes from, (2) the criteria
  and calculation used, (3) the exact records behind it, even when the result is 0.
- **Automation audit and "Send to support".** Operational screens (hooks, approvals, reminders, MCP) show separate counters
  for runs, successes and errors. A run's details show what was sent, what was expected, what actually happened, the
  authorised payload (marking the fields hidden for security), and a **"Send to support"** button that packages the
  diagnosis. In Koncluí this respects the "no telemetry" rule: the person starts it, sees the exact payload, and secrets
  are redacted before anything leaves the Mac.

---

## 4. Lists and filters

- **Same mechanic for different things**: every list screen uses the same skeleton.
- **View formats stay visible**: when a list offers formats (list, cards, calendar), they show on every list; a format a list
  cannot support stays visible, unavailable, with the reason.
- **Filter options come from the catalog, not from the records**: a "Stage" or "Category" filter lists every defined value,
  not only the ones that already have items.
- **Saved filters store IDs, never names**: renaming a tag, pill or category never breaks a saved filter, rule or automation
  (in Koncluí: pill IDs, feature flag IDs and hook markers are stable contract values).
- **Compute before slicing**: search, filter, sort and group run over the whole set before paging or truncating, never over
  only the rows already on screen.
- **Keep before refusing**: an event that arrives for something the person removed (a hook event for a pill that is off, a
  WhatsApp message in an ignored chat, a reminder update after deletion) is recorded or handled by an explicit rule, never
  silently dropped.

---

## 5. Microcopy

Interface text is part of the product's function. Koncluí ships in 14 languages; the rules apply to every one.

| Context | Rule | Example (pt-BR) |
|---|---|---|
| Sentences | Short and direct, with full stops, commas or parentheses only. **No dashes** (no "—" or "–" used as punctuation). | "O arquivo passa de 10 MB. Escolha uma imagem menor." |
| Buttons | Active voice + a specific verb saying what happens. Never "OK", "Yes" or "Confirm" alone. | "Instalar hooks", "Salvar contato" instead of "Confirmar" |
| Errors | What happened + impact + next step. Never blame the person, never a technical code. | "Não foi possível salvar. Suas alterações continuam na tela. Tente de novo em instantes." |
| Empty states | Why there is nothing, and the button for the next action. | "Nenhum ditado ainda. Segure ⌥ da direita em qualquer app e fale." |
| Blocked controls | One line: the reason and how to unlock it. | "Salve uma chave de API para usar este provedor." |
| Vocabulary | One name per concept across the app (glossary below). | The app says "aba"; no screen says "pílula". |
| Names in tight places | A name never ends in "…" mid-word. Where space is fixed (a tab in the notch: at most 11 characters and 64 pt), a long name has a short form chosen by hand in `KoncluiTabLabel.shortForms`; `scripts/konclui/test-tab-label.sh` checks every catalog name. | "Claude Desk" instead of "Claude Deskt…" |

Existing strings that break a rule (many use "—") are rewritten when their screen is touched; do not leave a touched screen
half-converted.

### Glossary (one name per concept)

| Concept | pt-BR | en | Notes |
|---|---|---|---|
| The app | Koncluí | Koncluí | never "Coucou" or "NotchBuddy" in the UI |
| The character | a Koru | Koru | feminine in pt-BR, es, fr, de, ru |
| A tab in the notch for a tool, agent or service | aba | pill | owner's choice; `scripts/konclui/rebrand.py` (TERMS) turns every pt-BR "pílula" into "aba" |
| Claude Code hook integration | hooks | hooks | |
| The WhatsApp gateway | gateway | gateway | "GOWA" only under Details |

Add a row whenever a new concept reaches the interface.

---

## 6. Perceived performance and accessibility

- **Response budgets**: visual feedback on click or typing within **100 ms**; interactive and live operations within **200 ms**
  (above that is a bug); no layout jump while the person is about to click.
- **Koncluí's own budgets**: 0 % CPU when the island is hidden; animations at the display's frame rate (see the motion
  doctrine in `design/prototype/koru/docs/MOTION.md`); never block Claude Code (the hook exits at once when the app does not
  answer).
- **Accessibility (WCAG 2.2 AA, macOS equivalents)**:
  - **Keyboard first**: every feature works from start to end with the keyboard (Full Keyboard Access), with a visible focus
    ring and a logical Tab order; focus returns where it was when a popover or sheet closes.
  - **No hover dependency**: no action or essential information appears only on hover.
  - **VoiceOver**: every control has an accessible name; status changes that matter are announced.
  - **Contrast and colour**: at least **4.5:1** for text (3:1 for large text), checked against the real background
    including transparency; no information by colour alone (an error has colour + icon + text). Known issue: the orange
    primary button with white text is about 2.2:1.
  - **Motion and transparency**: respect Reduce Motion (the prototype's Koru does, `design/prototype/koru/docs/MOTION.md`;
    the app must too) and Reduce Transparency / Increase Contrast.

---

## 7. Review gate (checklist before merging a screen change)

- [ ] The four states are designed: loading, empty with the next action, error with a way out, partial.
- [ ] Unavailable data reads "unavailable", not `0`.
- [ ] Exactly **one** primary action stands out per region.
- [ ] Everything clickable shows the pointing-hand cursor and works with the keyboard, without hover.
- [ ] A disclosure or expanding row opens from its whole label; no name is cut by "…" where a short form fits.
- [ ] No control can be blocked silently: a blocked one says why and how to unlock it.
- [ ] Data on screen (names, numbers, paths, statuses, dates) opens a popover with quick actions.
- [ ] Numbers and counters are clickable and show the records behind them (zero included).
- [ ] Actions that change data offer Undo, or a preview + confirmation when irreversible.
- [ ] Buttons use specific verbs; texts have no dashes and no technical jargon; terms match the glossary.
- [ ] The view's state (page, filters, selection) survives closing and reopening.
- [ ] Every new string exists in all 14 languages (`python3 scripts/test-localization.py`).
- [ ] The changed path was walked in the running app, including blocked, error and recovery states, and with the keyboard
      (a screenshot or a unit test alone does not prove an interaction).

---

## 8. UI polish pass (procedure)

Use this when asked for a "polish pass" on a screen. These are visual refinements only: do not change features, wording,
content, row order or overall layout unless a step says so. Use the existing design language (SF Symbols, the app's text
styles, its radius and elevation values); do not invent new values. Each step's "keep" list protects against side effects of
that step; a later step (type hierarchy) may intentionally change something an earlier one left alone.

1. **Icons**: one icon set (SF Symbols), matching optical size and stroke weight, not only point size; consistent alignment.
   Keep meanings, selected states, labels, colours, layout and hit targets.
2. **Text contrast**: raise contrast without changing sizes or layout. Secondary text stays easy to read and still visibly
   different from primary. Measure against the real background (transparency included) and report the ratios
   (4.5:1 body, 3:1 large). Keep status colours.
3. **Corner radius**: one radius per element type (cards, fields, buttons, chips); nested shapes match
   (inner ≈ outer − padding). Keep intentional capsules. Change only corners.
4. **Shadows and elevation**: remove heavy shadows and glows; depth only where something really sits above something else.
   Keep fills, borders, layout and type.
5. **Line spacing**: fix paragraph line height before resizing any card; keep font, size, weight, wording and width; let
   containers grow.
6. **Type hierarchy**: with the existing text styles, make the main value, the title and the supporting text clearly
   different (main value large, details small). Keep fonts, order, colours and alignment.
7. **Alignment**: titles and labels on one leading edge, values in one trailing column. Leave intentional icon alignment.
8. **Long text stress test**: real worst cases (long project names, long paths, large numbers, multi-word statuses, the
   longest of the 14 languages, usually German or Russian). Nothing cut off or overlapping; no tiny text.

Final checks: the narrowest window and notch sizes; larger system text and Increase Contrast; then summarise what changed
per step, list the contrast ratios, and flag what was left on purpose or could not be fixed without breaking a rule.

---

## 9. Web rules and their Mac equivalents

| Web rule | In Koncluí |
|---|---|
| `cursor: pointer` | pointing-hand cursor on every custom clickable view (1.4) |
| `aria-disabled` instead of a silent `disabled` | the reason stays visible next to the control; the action is guarded (1.1) |
| Filter state in the URL | the window restores its page, filters and selection when it reopens |
| Server-side filtering before pagination | local lists filter and sort the whole set before truncating (4) |
| Web Vitals (LCP, INP, CLS) | the 100/200 ms budgets, 0 % CPU when hidden, no layout jump (6) |
| Narrow phone width (polish pass) | the narrowest window and the notch sizes (8) |

---

## 10. Review lenses

Use these frameworks to review a screen, a flow or a message. The summaries are enough without any tool; Claude Code users
can run the skill of the same name for a full pass.

- **Usability heuristics** (`/ux-heuristics`, Nielsen and Krug): the ten heuristics of section 2, plus "don't make me think":
  a screen explains itself at a glance.
- **UX copy** (`/design:ux-copy`): microcopy, errors, empty states, button labels (section 5).
- **Hook model** (`/hooked-ux`): trigger (a notch event, a finished task), action (one click to approve or answer), variable
  reward (Koru's reactions, the weekly recap), investment (pills, agents and dictionary set up). Use it to make Koncluí worth
  coming back to, never to manipulate: notify only what is actionable (1.3, habit 8).
- **Made to Stick** (`/made-to-stick`, SUCCESs: simple, unexpected, concrete, credible, emotional, stories): onboarding copy,
  What's New items, the site and store texts.
- **Contagious** (`/contagious`, STEPPS: social currency, triggers, emotion, public, practical value, stories): what people
  share (the weekly recap image, Koru's outfits and moods).
- **Apple design** (`/apple-design`, Human Interface Guidelines): native controls and behaviour first; a custom control has
  to earn its place.
- **Steve Jobs review** (`/steve-jobs-design-review`): focus and saying no; the default is what most people need; remove
  before adding.
- **Interface review** (`/better-interface`): one ranked report across accessibility, layout, writing, typography, colour and
  polish, used before a release.
