import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assetId, macReleases, notesPage, parseBlocked } from '../src/feed.mjs';

const publicURL = 'https://updates.konclui.com';
const release = (tag, extra = {}) => ({
  tag_name: tag, draft: false, prerelease: false, body: `notes of ${tag}`, published_at: '2026-10-30T00:00:00Z',
  html_url: `https://github.com/konclui/konclui-notch/releases/tag/${tag}`,
  assets: [{ id: 7, name: 'Konclui.zip', size: 34_000_000, browser_download_url: 'https://github.com/private' }],
  ...extra,
});

test('only Koncluí Mac releases with a Konclui.zip', () => {
  const list = macReleases([
    release('konclui-v0.7.0'),
    release('v0.5.6'),                                   // Coucou's tag, arrives with every sync
    release('windows-v0.6.0'),
    release('konclui-v0.8.0', { draft: true }),
    release('konclui-v0.9.0', { prerelease: true }),
    release('konclui-v0.6.0', { assets: [{ id: 1, name: 'notes.txt', size: 3 }] }),
    release('konclui-v0.6.0-beta'),
  ], { publicURL });
  assert.deepEqual(list.map((r) => r.tag_name), ['konclui-v0.7.0']);
});

test('every link points at the service, never at the private repository', () => {
  const [r] = macReleases([release('konclui-v0.7.0')], { publicURL });
  assert.equal(r.html_url, 'https://updates.konclui.com/v1/mac/notes/konclui-v0.7.0');
  assert.deepEqual(r.assets, [{
    name: 'Konclui.zip', size: 34_000_000,
    browser_download_url: 'https://updates.konclui.com/v1/mac/download/konclui-v0.7.0/Konclui.zip',
  }]);
  assert.ok(!JSON.stringify(r).includes('konclui-notch'));
  assert.equal(r.assets[0].id, undefined);
});

test('a blocked tag disappears from the list and cannot be downloaded', () => {
  const blocked = parseBlocked(' konclui-v0.7.0 ,konclui-v0.7.1,');
  assert.deepEqual([...blocked], ['konclui-v0.7.0', 'konclui-v0.7.1']);
  const list = macReleases([release('konclui-v0.7.0'), release('konclui-v0.6.0')], { publicURL, blocked });
  assert.deepEqual(list.map((r) => r.tag_name), ['konclui-v0.6.0']);
  assert.equal(assetId([release('konclui-v0.7.0')], 'konclui-v0.7.0', blocked), null);
});

test('assetId only for a valid, published tag', () => {
  const list = [release('konclui-v0.7.0'), release('konclui-v0.8.0', { draft: true })];
  assert.equal(assetId(list, 'konclui-v0.7.0'), 7);
  assert.equal(assetId(list, 'konclui-v0.8.0'), null);
  assert.equal(assetId(list, '../../etc'), null);
  assert.equal(assetId(null, 'konclui-v0.7.0'), null);
});

test('the notes page escapes what the release says', () => {
  const page = notesPage({ tag_name: 'konclui-v0.7.0', body: '<script>alert(1)</script> & "more"' });
  assert.ok(page.includes('Koncluí 0.7.0'));
  assert.ok(page.includes('&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;more&quot;'));
  assert.ok(!page.includes('<script>'));
});
