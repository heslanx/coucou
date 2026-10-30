# Koncluí — usability and product experience

The rules every screen, message and interaction of Koncluí follows. They come from the owner's product guide (the
same rules apply to all of Koncluí's projects), adapted here to a native macOS notch app. They are the review gate for
every change that touches what a person sees or does. Engineering rules are in [ENGINEERING.md](ENGINEERING.md); what the
fork changes and why is in [KONCLUI.md](../../KONCLUI.md).

**The goal:** a new person can use Koncluí alone, by clicking and learning. No mandatory training, support or tutorial,
and no fabricated urgency.

Where a rule from the web version of the guide has no meaning in a Mac app, section 9 says so and gives the native
equivalent, so nobody has to re-decide it. Section 11 says how the hub window's visual system (tokens, components, glass,
motion) meets the contrast, motion and polish rules of sections 6 and 8.

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
- The popover of an agent follows the state: the **primary is the one thing that state needs** (Install when nothing is
  installed, Update when outdated, no primary when it is fine); the **quiet** button (Uninstall) exists only once there is
  something to take back; before anything is written the popover shows **only the lines Koncluí adds or removes**, with the
  whole file behind "Ver o arquivo inteiro". A path is a detail, never a status line: it lives under "Detalhes" with the two
  actions a path is for (Show in Finder, Copy path).
- A switch the product blocks (the 4-tab limit) keeps its reason beside it as a door that offers the way out (a list of the
  tabs that can be turned off, one click each); it is never a bare grey control.

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
| Sentences | Short and direct, with full stops, commas or parentheses only. **No dashes** (no "—" or "–" used as punctuation) in any of the 14 languages. Russian too: use a colon, a comma or a full stop. | "O arquivo passa de 10 MB. Escolha uma imagem menor." |
| Paths and ranges | A path to a menu item is written with Apple's chevron "›" and the page's own name, never "Settings → Chat" when Chat is a page of the window. A range is "a" or "…", never a dash. | "Ative em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade." / "Adicione a chave em Chat." / "⌘1 … ⌘9" |
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
| The window of the app | Koncluí | Koncluí | never "Koncluí Flow", "Flow" or "Ditado Flow". The sidebar's first group is "Ditado e notas" (`konclui.hub.section.flow`); the second is "Notch". |
| The character | a Koru | Koru | feminine in pt-BR, es, fr, de, ru |
| The expanded and the closed bar at the top of the screen | notch | notch | never "ilha", "island" or "o island". "Dynamic Island" stays only where it is the iPhone's feature (`iphone.live-activity.toggle`). |
| A tab in the notch for a tool, agent or service | aba | pill | owner's choice; `scripts/konclui/rebrand.py` (TERMS) turns every pt-BR "pílula" into "aba". Counted as "N de 4 abas ligadas", never "slots". |
| The small floating indicator while you dictate (Settings, "Posição do indicador de ditado") | indicador de ditado | dictation pill | not an "aba": it is not a tab of the notch |
| Dictation, the Flow pages of the window | ditado | dictation | the page that holds its options is "Ajustes do ditado" (en "Dictation settings"); a button that opens it says "Abrir os ajustes do ditado" |
| Koncluí's settings as a whole (menu bar, window of the standalone Settings) | Ajustes | Settings | menu "Ajustes…", window "Ajustes do Koncluí". Never for one page. |
| macOS System Settings | Ajustes do Sistema | System Settings | paths inside it use "›" |
| A page of the window's Notch group | its own name: Geral, Abas ativas, Agentes, Chat, Integrações, Voz, Atalhos | General, Active pills, Agents, Chat, Integrations, Voice, Shortcuts | a sentence says "em Chat", "em Integrações", not "Ajustes → Chat" |
| The call-notes feature | Notetaker | Notetaker | owner decision (A1-52): stays the feature's name in pt-BR, es, fr, ru, id, ar, bn, hi, tr; de, th, zh keep their upstream words. No "Notas de chamada". |
| Claude Code hook integration | hooks | hooks | |
| The WhatsApp gateway | gateway | gateway | "GOWA" only under Details (Advanced fields, the install progress); never in the sentences of a failed install |
| Where a Koncluí subscription is meant | assinatura | subscription | "Conectado pela sua assinatura Koncluí"; "Koncluí Proxy" only as a product name in Chat's list |
| Quotes around a name or phrase | “…” | “…” | per language: es, ru, ar «…»; fr « … »; de „…“; zh-Hant 「…」. Never French guillemets in pt-BR or en. |
| What Koru says aloud | "você", short sentences, "aba" for a pill, "e-mail" | | Spoken pt-BR is informal Brazilian ("Pronto.", "Deixa eu ver."); never "tu", never European forms |

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
    including transparency; no information by colour alone (an error has colour + icon + text). Primary buttons draw ink
    on the accent (section 11.1), not white text, which was about 2.2:1.
  - **Motion and transparency**: respect Reduce Motion (the prototype's Koru does, `design/prototype/koru/docs/MOTION.md`;
    the app must too) and Reduce Transparency / Increase Contrast.

---

## 7. Review gate (checklist before merging a screen change)

- [ ] The four states are designed: loading, empty with the next action, error with a way out, partial.
- [ ] Unavailable data reads "unavailable", not `0`.
- [ ] Exactly **one** primary action stands out per region.
- [ ] A first-run tool (a demo, a tour) steps back once the person has set the product up; it does not lead a set-up screen.
- [ ] Everything clickable shows the pointing-hand cursor and works with the keyboard, without hover.
- [ ] A disclosure or expanding row opens from its whole label; no name is cut by "…" where a short form fits.
- [ ] No control can be blocked silently: a blocked one says why and how to unlock it.
- [ ] Data on screen (names, numbers, paths, statuses, dates) opens a popover with quick actions.
- [ ] Numbers and counters are clickable and show the records behind them (zero included).
- [ ] Actions that change data offer Undo, or a preview + confirmation when irreversible.
- [ ] A removal or uninstall previews like an install (what changes, in lines) and says per file what happened afterwards.
- [ ] Buttons use specific verbs; texts have no dashes and no technical jargon; terms match the glossary.
- [ ] No retired word on the screen: notch (never "ilha"/"island"), aba, Ajustes with one meaning, "Koncluí" for the window
      (`python3 scripts/konclui/test-copy.py`).
- [ ] The view's state (page, filters, selection) survives closing and reopening.
- [ ] Page edges and columns line up with the header card (gutter 28; text at gutter + 18).
- [ ] Text uses a role of 11.1 (4.5:1 on its surface); status uses `KoncluiStatus`; no new grey, green, red or amber.
- [ ] A disabled control cannot be mistaken for an enabled one; a blocked "Adicionar" says what is missing.
- [ ] Nothing animates under Reduce Motion; Increase Contrast and Reduce Transparency were looked at.
- [ ] Every new string exists in all 14 languages (`python3 scripts/test-localization.py`).
- [ ] The changed path was walked in the running app, including blocked, error and recovery states, and with the keyboard
      (a screenshot or a unit test alone does not prove an interaction).
- Both pickers list the three languages the parser, the answers and the voice support; adding a fourth language means
  adding it to `VoiceLanguage`, the parser, the sentence table and the two prompts (`KoncluiVoicePrompts.swift`) first,
  never a picker entry alone (a language that cannot be understood would be a silent blocked control).

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

---

## 11. Visual system (the hub window)

Section 6 (Contrast and colour; Motion and transparency) says what is required. This section says how the hub window meets it, so a
change does not have to re-decide it. The numbers live in `KoncluiThemeCore.swift` (pure, tested by
`scripts/konclui/test-theme.sh`), the colours, type roles and controls in `KoncluiTheme.swift`. Nothing here adds a hue, a size or
a radius the app did not already use (section 8). The checklist lines for it are in section 7.

### 11.1 Tokens

| Group | Token | Value | Use |
|---|---|---|---|
| Surface | canvas, panel, card, field, control | #000000, #0E0F11, #18191C, #1F2024, #1D1E22 | window and sidebar, the page's big card, cards, text fields, secondary buttons |
| Text | textPrimary, textBody, textSecondary, textTertiary | #F5F6F8, #C7CAD0, #8E939C, #83888F | titles and values, reading text, supporting text, the quietest text that still reads (4.5:1 on every surface, fields included) |
| Accent | accent, onAccent, selection | #FB923C, #170C04, #C2410C | the region's one primary, text links and focus; ink on the accent (8.5:1; white on it is 2.3:1); a selected segment, where macOS draws white on the tint (5.2:1) |
| Status | ok, attention, error, off | #34D399, #F5B83D, #FF453A, textSecondary | status is never the accent |
| Space | gutter, cardPadding, sectionGap, rowGap, labelGap | 28, 18, 22, 12, 8 | page edge and every column, card content, between sections, between rows, label to card |
| Radius | panel, band, card, control, chip | 20, 18, 14, 9, capsule | the page's card, the header band, cards, buttons and fields and menus, chips |

Type roles (minimum 11 pt): display 30 bold, tracking -0.6 (page title) · title 15 semibold · body 13.5 · bodyStrong 13.5 medium ·
detail 12 · label 11 bold, capitals, tracking 1.2 (section titles, GroupBox titles) · metric 30 bold, monospaced digits.
Hierarchy comes from size, weight and value together, never from low contrast. `.koncluiType(_:)` applies a role.

The old greys fold into the four text roles: #A4A9B1, #A4A9B2, #B7BBC2, #C7CBD2, #C7CAD0, #D5D7DB become `textBody` (or
`textSecondary` for supporting text); `HubTheme.muted` (#6B7079, 3.5:1 on a card) is `textTertiary`. Two greens, two reds and two
ambers become `ok`, `error`, `attention`. A new colour needs a row in this table.

### 11.2 One gutter

Every page's left edge is the gutter (28 pt) and its right edge is the gutter again: the header card, cards, section labels, a
Notetaker column and its detail pane all start and end there. Text inside a card (and the header's title) starts at gutter +
`cardPadding` (18): one inner edge. Check each page against its header card in the before/after stills; a column that sits 14 pt
left of the card (the owner's complaint about the Notetaker) is a defect. The Notetaker's list column is 280 pt: gutter on the
card side, 14 pt free beside its divider, so "Gravar uma chamada" is 238 pt wide and still fits in the longest language.

### 11.3 Components (the hub's own)

- **Buttons**: `.koncluiPrimary` (ink on the accent) and `.koncluiSecondary` (neutral) for settings pages; `HubButtonStyle` for the
  Flow pages (same look, 34 pt high). A disabled button drops to the card colour with secondary text and the arrow cursor, so it
  never looks like an enabled primary; the reason still belongs beside it (section 1.1), and "Adicionar" and "Salvar" stay enabled
  and say what is missing under the field. A destructive role is red text. One primary per region (the squint test).
- **Segmented controls**: `.pickerStyle(.segmented).koncluiSegmented()`; the selected segment is `selection`, not the accent.
- **Cards**: `HubCard` on Flow pages; every `GroupBox` in the hub is drawn the same way (`KoncluiGroupBoxStyle`): its title above in
  the label role, the content on a full-width card; a box inside a card is flat. Do not nest cards.
- **Toggles**: a labelled `Toggle` is a row, label left and switch right (`KoncluiToggleStyle`), so every on/off sits in one
  column. A `Toggle` with `.labelsHidden()` is a selection in a list (Abas ativas, Atalhos) and stays a checkbox, drawn with an
  off box you can see (3:1 against the card). An on/off setting with a hidden label asks for `.toggleStyle(.switch)`.
- **Status**: `KoncluiStatus(tone:text:door:)`: a dot (an icon for an error), a sentence, a chevron when it opens a popover. One
  way to say "installed", "not installed", "needs attention", "failed", "off". Never the accent, never a grey caption that looks
  like a link.
- **Doors**: a status or a name that opens a popover is a `Button` with the pointing hand (`.koncluiPointer()`), a hover fill and a
  chevron; the popover is a short list of `KoncluiPopoverAction` rows, the likeliest first.
- **Fields**: `KoncluiField` (via `HubField`): an edge you can see (white 16 %), a 2 pt accent ring with focus, an optional label
  above that stays while typing, an optional line below that says what is missing.
- **Key caps**: `KoncluiKeyCap`: one filled chip for every shortcut.
- **Popovers** are their own windows: they take the system's glass and do not inherit the hub's styles; a popover's content calls
  `.koncluiTheme()` when it uses hub buttons, toggles or boxes.

Upstream's settings views reach this look without being rewritten: `FlowHubView` injects the styles once (`.koncluiTheme()`), and
`scripts/konclui/rebrand.py` (`HUB_STYLES`) turns `.borderedProminent`, `.bordered` and `.pickerStyle(.segmented)` into the three
names above. Outside the hub (the standalone Settings window) the same names draw upstream's own styles, so that window is
unchanged.

### 11.4 Where glass is allowed

In exactly one place: the compact page header of the notch pages (Geral, Abas ativas, Agentes, Chat, Integrações, Voz, Atalhos)
while the settings scroll under it (`KoncluiSettingsPage`, `View.koncluiPinnedHeader`). On macOS 26 it is `safeAreaBar(edge: .top)`
with `scrollEdgeEffectStyle(.soft, for: .top)`; on macOS 15 to 25 it is `safeAreaInset` with a 12 pt fade under the bar. The band is
translucent over `.ultraThinMaterial`; Reduce Transparency draws it solid (`panel`). Pinned chrome is compact (116 pt); a full-height
band is never pinned over scrolling content, and content meets chrome through a soft edge, not a hard cut.

No glass on cards, bands, the sidebar or buttons: the window is OLED black, so a blur over it frosts nothing, and over a live band it
would re-blur every frame. Popovers keep the system's own. Do not animate blur radius, and do not add refraction or "liquid"
displacement.

### 11.5 Motion rules

- Every canvas reads one environment value, `koncluiMotion` (`KoncluiMotion.rate`): the display's own rate while the window is the
  front one, 30 frames a second while it is visible but not the front one, and once (still) when the window is hidden,
  minimised or covered, or when **Reduce Motion** is on. Reduce Motion draws the colour wash still, with the Koru standing.
- A band has drifting particles and a breathing glow only where `KoncluiMotion.liveBandPages` says (the Ditado page). Every other
  band, and the glow cards, are a colour wash drawn once, with the Koru on it.
- A new animation reads `koncluiMotion` (or Reduce Motion) before it asks for the display's rate; the 0 % CPU rule for a hidden
  island is unchanged.
- Increase Contrast: hairlines 7 % become 20 %, supporting text becomes `textBody`, control edges 16 % become 40 %. Components read
  `colorSchemeContrast`; a view that hard-codes a hairline does not meet section 6.
