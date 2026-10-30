const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { handler } = require('../lambda/index.js');

beforeEach(() => {
  process.env.KORU_SKILL_ID = 'amzn1.ask.skill.test';
  process.env.KORU_ASSET_BASE_URL = 'https://assets.example.com/koru';
});
function request(intent, screen = true) {
  return {
    context: { System: { application: { applicationId: 'amzn1.ask.skill.test' },
      device: { supportedInterfaces: screen ? { 'Alexa.Presentation.APL': {} } : {} } } },
    request: { type: intent ? 'IntentRequest' : 'LaunchRequest',
      timestamp: new Date().toISOString(), ...(intent ? { intent: { name: intent } } : {}) }
  };
}

test('launch displays Koru on Echo Show and explains the available commands', async () => {
  const { response } = await handler(request());
  assert.match(response.outputSpeech.ssml, /Oi! Eu sou a Koru/);
  assert.equal(response.directives[0].type, 'Alexa.Presentation.APL.RenderDocument');
  assert.equal(response.directives[0].datasources.koru.image, 'https://assets.example.com/koru/koru.png');
  assert.equal(response.shouldEndSession, false);
});
for (const [intent, file] of [['OwlSoundIntent', 'owl'], ['SaleSoundIntent', 'sale']]) {
  test(`${intent} plays the corresponding audio`, async () => {
    const { response } = await handler(request(intent));
    assert.match(response.outputSpeech.ssml, new RegExp(`https://assets.example.com/koru/${file}.mp3`));
    if (file === 'sale') assert.match(response.outputSpeech.ssml, /demonstração/);
  });
}
test('speaker-only devices receive speech without screen directives', async () => {
  const { response } = await handler(request('OwlSoundIntent', false));
  assert.equal(response.directives, undefined);
  assert.match(response.outputSpeech.ssml, /owl.mp3/);
});
for (const intent of ['AMAZON.StopIntent', 'AMAZON.CancelIntent']) {
  test(`${intent} ends the session without requiring asset configuration`, async () => {
    delete process.env.KORU_ASSET_BASE_URL;
    const { response } = await handler(request(intent));
    assert.equal(response.shouldEndSession, true);
    assert.equal(response.directives, undefined);
  });
}
test('fallback explains how to recover without playing a sound', async () => {
  const { response } = await handler(request('AMAZON.FallbackIntent'));
  assert.match(response.outputSpeech.ssml, /tocar coruja/);
  assert.doesNotMatch(response.outputSpeech.ssml, /<audio/);
});
test('session end returns no further speech', async () => {
  const event = request();
  event.request.type = 'SessionEndedRequest';
  assert.deepEqual(await handler(event), { version: '1.0', response: {} });
});
test('rejects requests from another skill', async () => {
  const event = request();
  event.context.System.application.applicationId = 'another-skill';
  await assert.rejects(handler(event), /Unrecognized/);
});
test('fails closed when the authorized skill is not configured', async () => {
  delete process.env.KORU_SKILL_ID;
  await assert.rejects(handler(request()), /Unrecognized/);
});
test('rejects stale and malformed request timestamps', async () => {
  for (const timestamp of ['2020-01-01T00:00:00Z', 'invalid']) {
    const event = request();
    event.request.timestamp = timestamp;
    await assert.rejects(handler(event), /stale/);
  }
});
test('rejects unsafe asset configuration', async () => {
  for (const url of ['http://example.com', 'https://user:password@example.com', 'https://example.com?secret=value']) {
    process.env.KORU_ASSET_BASE_URL = url;
    await assert.rejects(handler(request()), /public HTTPS/);
  }
});
