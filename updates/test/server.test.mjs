// The whole service against a fake GitHub on localhost: what the Mac app gets, and what GitHub is asked.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { config, createService } from '../src/server.mjs';

const TOKEN = 'test-token-not-real';
let github, service, base, calls;

const releases = [
  { tag_name: 'konclui-v0.7.0', draft: false, prerelease: false, body: 'newest', assets: [{ id: 70, name: 'Konclui.zip', size: 10 }] },
  { tag_name: 'konclui-v0.6.0', draft: false, prerelease: false, body: 'older', assets: [{ id: 60, name: 'Konclui.zip', size: 9 }] },
  { tag_name: 'v0.5.6', draft: false, prerelease: false, body: 'coucou', assets: [{ id: 56, name: 'Coucou.zip', size: 8 }] },
];

const listen = (server) => new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server.address().port)));

before(async () => {
  calls = [];
  github = createServer((req, res) => {
    calls.push({ url: req.url, auth: req.headers.authorization, accept: req.headers.accept, etag: req.headers['if-none-match'] });
    if (req.url.startsWith('/repos/konclui/konclui-notch/releases?')) {
      if (req.headers['if-none-match'] === '"v1"') { res.writeHead(304); return res.end(); }
      res.writeHead(200, { 'Content-Type': 'application/json', ETag: '"v1"' });
      return res.end(JSON.stringify(releases));
    }
    const m = req.url.match(/^\/repos\/konclui\/konclui-notch\/releases\/assets\/(\d+)$/);
    if (m && req.headers.accept === 'application/octet-stream') {
      res.writeHead(302, { Location: `https://objects.githubusercontent.com/signed/${m[1]}?X-Amz-Expires=300` });
      return res.end();
    }
    res.writeHead(404); res.end();
  });
  const githubPort = await listen(github);
  const cfg = config({ GITHUB_TOKEN: TOKEN, GITHUB_API: `http://127.0.0.1:${githubPort}`, CACHE_SECONDS: '0',
                       BLOCKED_TAGS: 'konclui-v0.6.0' });
  service = createServer(createService(cfg).handle);
  base = `http://127.0.0.1:${await listen(service)}`;
});

after(() => { github.close(); service.close(); });

test('health says it is configured, without the token', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  const text = await res.text();
  const health = JSON.parse(text);
  assert.equal(health.ok, true);
  assert.equal(health.configured, true);
  assert.ok(!Number.isNaN(Date.parse(health.startedAt)), 'startedAt is a date');
  assert.ok(!text.includes(TOKEN));
});

test('the releases: Koncluí only, the blocked tag gone, links through the service', async () => {
  const res = await fetch(`${base}/v1/mac/releases`);
  assert.equal(res.status, 200);
  const list = await res.json();
  assert.deepEqual(list.map((r) => r.tag_name), ['konclui-v0.7.0']);
  assert.equal(list[0].assets[0].browser_download_url, 'https://updates.konclui.com/v1/mac/download/konclui-v0.7.0/Konclui.zip');
  const asked = calls.find((c) => c.url.startsWith('/repos/konclui/konclui-notch/releases?'));
  assert.equal(asked.auth, `Bearer ${TOKEN}`);
});

test('a second look sends the ETag and keeps the list on 304', async () => {
  await fetch(`${base}/v1/mac/releases`);
  const again = await fetch(`${base}/v1/mac/releases`);
  assert.deepEqual((await again.json()).map((r) => r.tag_name), ['konclui-v0.7.0']);
  assert.ok(calls.some((c) => c.etag === '"v1"'));
});

test('the download is a redirect to GitHub\'s short-lived link', async () => {
  const res = await fetch(`${base}/v1/mac/download/konclui-v0.7.0/Konclui.zip`, { redirect: 'manual' });
  assert.equal(res.status, 302);
  assert.equal(res.headers.get('location'), 'https://objects.githubusercontent.com/signed/70?X-Amz-Expires=300');
  assert.equal(res.headers.get('cache-control'), 'no-store');
});

test('no download for a blocked, unknown, Coucou or malformed tag', async () => {
  for (const path of ['konclui-v0.6.0/Konclui.zip', 'konclui-v9.9.9/Konclui.zip', 'v0.5.6/Konclui.zip',
                      '..%2F..%2Fetc/Konclui.zip', 'konclui-v0.7.0/Coucou.zip']) {
    const res = await fetch(`${base}/v1/mac/download/${path}`, { redirect: 'manual' });
    assert.equal(res.status, 404, path);
  }
});

test('the notes page, for a tag and for latest', async () => {
  const one = await fetch(`${base}/v1/mac/notes/konclui-v0.7.0`);
  assert.equal(one.status, 200);
  assert.match(await one.text(), /Koncluí 0\.7\.0[\s\S]*newest/);
  const latest = await fetch(`${base}/v1/mac/notes/latest`);
  assert.match(await latest.text(), /newest/);
  assert.equal((await fetch(`${base}/v1/mac/notes/konclui-v0.6.0`)).status, 404);
});

test('nothing but GET and HEAD', async () => {
  assert.equal((await fetch(`${base}/v1/mac/releases`, { method: 'POST' })).status, 405);
});

test('without a token every release request answers 503', async () => {
  const bare = createServer(createService(config({ GITHUB_TOKEN: '' })).handle);
  const url = `http://127.0.0.1:${await listen(bare)}`;
  const health = await (await fetch(`${url}/health`)).json();
  assert.equal(health.configured, false);
  assert.equal((await fetch(`${url}/v1/mac/releases`)).status, 503);
  bare.close();
});
