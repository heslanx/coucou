'use strict';

const document = require('./koru.json');
const HELP = 'Você pode dizer: tocar coruja, tocar som de venda ou parar.';
const escapeXML = value => value.replace(/[<>&"']/g, char => ({
  '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;'
})[char]);

function assetRoot(value) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new Error('KORU_ASSET_BASE_URL must be a public HTTPS directory without credentials, query or fragment.');
  }
  return url.href.replace(/\/$/, '');
}

// Use only behind an AWS Lambda Alexa Skills Kit trigger restricted to this skill ID.
// This is not a public HTTP handler: HTTP hosting also requires Amazon signature verification.
exports.handler = async event => {
  const skillId = process.env.KORU_SKILL_ID;
  if (!skillId || event.context?.System?.application?.applicationId !== skillId) {
    throw new Error('Unrecognized Alexa application.');
  }
  const request = event.request;
  if (!request || !Number.isFinite(Date.parse(request.timestamp)) ||
      Math.abs(Date.now() - Date.parse(request.timestamp)) > 150000) {
    throw new Error('Missing or stale Alexa request.');
  }
  if (request.type === 'SessionEndedRequest') return { version: '1.0', response: {} };
  const intent = request.type === 'IntentRequest' ? request.intent?.name : null;
  if (intent === 'AMAZON.StopIntent' || intent === 'AMAZON.CancelIntent') {
    return { version: '1.0', response: {
      outputSpeech: { type: 'PlainText', text: 'Até logo!' }, shouldEndSession: true
    } };
  }
  const base = assetRoot(process.env.KORU_ASSET_BASE_URL);
  let text = HELP;
  let sound;
  if (request.type === 'LaunchRequest') text = `Oi! Eu sou a Koru. ${HELP}`;
  if (intent === 'OwlSoundIntent') { sound = 'owl'; text = 'Essa é a minha coruja.'; }
  if (intent === 'SaleSoundIntent') { sound = 'sale'; text = 'Aqui está o som de venda. É só uma demonstração.'; }
  const response = {
    outputSpeech: { type: 'SSML', ssml: `<speak>${escapeXML(text)}${sound ? `<audio src="${escapeXML(base)}/${sound}.mp3"/>` : ''}</speak>` },
    reprompt: { outputSpeech: { type: 'PlainText', text: HELP } },
    shouldEndSession: false
  };
  if (event.context?.System?.device?.supportedInterfaces?.['Alexa.Presentation.APL']) {
    response.directives = [{ type: 'Alexa.Presentation.APL.RenderDocument',
      token: 'koru', document, datasources: { koru: {
        image: `${base}/koru.png`, message: sound === 'sale' ? 'Som de venda · demonstração' : sound === 'owl' ? 'Som da coruja' : 'Oi, eu sou a Koru.',
        hint: 'Diga “tocar coruja” ou “tocar som de venda”.'
      } }
    }];
  }
  return { version: '1.0', response };
};
