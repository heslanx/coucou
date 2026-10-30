# Koru on Echo Show

Development skill in Brazilian Portuguese. Say **“Alexa, abrir minha coruja”**,
then **“tocar coruja”**, **“tocar som de venda”** or **“parar”**.
The sale sound is explicitly a demonstration, not evidence of an actual sale.

## Local verification and packaging

No dependency installation is required. Use Node.js 22+ and Python 3:

```sh
cd alexa
npm test
npm run package
```

Outputs: `dist/lambda.zip` (handler `index.handler`) and `dist/assets.zip`.
The interaction model is `skill-package/interactionModels/custom/pt-BR.json`.
The APL document is `lambda/koru.json`; its datasource is named `koru`.

## Activate on your Echo Show

1. Open https://developer.amazon.com/alexa/console/ask with the Amazon account
   registered to the Echo Show. Create a **Custom** skill, **Portuguese (BR)**,
   using your own backend. Name it Koru; its invocation name is **minha coruja**.
2. In the interaction model's JSON editor, import `pt-BR.json`. Save and build.
   Enable the **Alexa Presentation Language** interface.
3. Host the three files in `assets.zip` in a public HTTPS directory, with
   `image/png` and `audio/mpeg` content types and no authentication. Expose only
   these media files, not the repository. This requires a hosting account and
   may incur hosting charges. No cloud resources are created by the local scripts.
4. Create an AWS Lambda function with a supported Node.js runtime (22 or later)
   in a region supported by Alexa Skills Kit. Upload `lambda.zip`, set the
   handler to `index.handler`, and configure:
   - `KORU_SKILL_ID`: the skill's application ID.
   - `KORU_ASSET_BASE_URL`: the HTTPS directory containing `koru.png`, `owl.mp3`
     and `sale.mp3`, without a query string.
5. Add an **Alexa Skills Kit** Lambda trigger with **Skill ID verification
   enabled**, restricted to this skill ID. Configure the Lambda ARN as the
   skill endpoint. Do not expose this handler with a Function URL or HTTP API:
   it relies on the ASK trigger to authenticate Amazon. A public HTTP endpoint
   would additionally need Amazon certificate/signature verification.
6. Enable skill testing in **Development**, with the device language set to
   Portuguese (BR). Test launch, both sounds, help and stop in the simulator,
   then on the Echo Show. Verify readable layout and audible playback on the
   actual model before considering the integration delivered.

## Scope and limitations

- Local code and audio are prepared; account setup, deployment and device
  verification are separate steps. The Amazon console requires login in the available QA browser; the personal
  browser is not accessible through CDP. No skill was deployed.
- Displays the existing Koru artwork. This is not the animated Canvas engine.
- A custom skill is a session, not a permanent replacement for the Echo home
  screen. Device/session timeouts apply. It does not automatically launch,
  push sale alerts, monitor the microphone or read live Coucou sessions.
- No credentials, customer information, agent commands or project state are
  sent. A future live integration needs an authenticated bridge and a clear
  event contract; being on the same Wi-Fi does not supply that bridge.
- The skill checks the application ID and timestamp and does not perform
  side effects. Duplicate requests can safely return the same presentation.

## Media provenance

Source repository (read-only): `konclui-project/konclui-work`.

- `owl.mp3`: converted from `art/sale-sounds/owl-hoots.wav` (isolated owl).
- `sale.mp3`: converted from `media/sounds/sale.mp3`, the production sale sound
  that already includes the owl, as documented in that project's README.
- `koru.png`: copied from `design/koru/koru-coucou-01-idle.png` in this repository.

Original audio copies are preserved in `design/prototype/koru/sounds/originals`.
The prototype's **Coruja** and **Som de venda** buttons use AAC copies and its
existing sound toggle, volume and reduced-motion behavior. No existing sound
was replaced. This change does not install sounds in the native Mac app.

Alexa copies are MPEG-2 MP3, 24 kHz, stereo, 48 kbps CBR, with Xing disabled:

```sh
ffmpeg -i INPUT -ac 2 -codec:a libmp3lame -b:a 48k -ar 24000 -write_xing 0 OUTPUT.mp3
```

References: [SSML audio requirements](https://developer.amazon.com/en-US/docs/alexa/custom-skills/speech-synthesis-markup-language-ssml-reference.html#audio),
[APL](https://developer.amazon.com/en-US/docs/alexa/alexa-presentation-language/add-visuals-and-audio-to-your-skill.html),
[device testing](https://developer.amazon.com/en-US/docs/alexa/test/test-your-skill-overview.html).

## Verification recorded during preparation

- All 12 local handler tests passed (launch, both sounds, speaker fallback,
  stop/cancel, help fallback, session end, application checks and validation).
- Both imported prototype buttons invoked successful browser media playback
  at the existing volume of 0.12. This confirms decoding/playback, not a human
  listening assessment. Programmatic activation verified both handlers.
- FFprobe confirmed 24 kHz, stereo, 48 kbps MP3 for both Alexa audio files.
- Original audio copies matched source SHA-256 hashes; JSON and upload archive
  contents were checked. `git diff --check` passed.
- APL rendering, invocation recognition and playback on an actual Echo Show
  remain unverified. Amazon sign-in is required before simulator/device tests.
