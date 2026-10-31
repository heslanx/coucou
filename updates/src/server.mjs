// Koncluí's update service: the Mac app asks it for releases, it asks the private repository with a read-only token
// that never leaves this process. No dependencies, no logs of who asked (no telemetry). See ../README.md.
import { createServer } from 'node:http';
import { pathToFileURL } from 'node:url';
import { ASSET, TAG, assetId, macReleases, notesPage, parseBlocked } from './feed.mjs';

export function config(env = process.env) {
  return {
    token: env.GITHUB_TOKEN ?? '',
    repo: env.REPO || 'konclui/konclui-notch',
    publicURL: (env.PUBLIC_URL || 'https://updates.konclui.com').replace(/\/+$/, ''),
    port: Number(env.PORT || 3000),
    cacheSeconds: Number(env.CACHE_SECONDS || 300),
    blocked: parseBlocked(env.BLOCKED_TAGS),
    api: (env.GITHUB_API || 'https://api.github.com').replace(/\/+$/, ''),
  };
}

export function createService(cfg) {
  let cache = { at: 0, etag: null, releases: [] };

  const github = (path, extra = {}) =>
    fetch(`${cfg.api}/repos/${cfg.repo}${path}`, {
      redirect: 'manual',
      ...extra,
      headers: {
        Authorization: `Bearer ${cfg.token}`,
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'konclui-updates',
        ...(extra.headers ?? {}),
      },
    });

  /** The repository's releases, at most once per cacheSeconds; a 304 keeps what we had without spending the rate limit. */
  async function releases({ fresh = false } = {}) {
    if (!fresh && Date.now() - cache.at < cfg.cacheSeconds * 1000) return cache.releases;
    const res = await github('/releases?per_page=50', {
      headers: { Accept: 'application/vnd.github+json', ...(cache.etag ? { 'If-None-Match': cache.etag } : {}) },
    });
    if (res.status === 304) {
      cache.at = Date.now();
      return cache.releases;
    }
    if (!res.ok) throw new Error(`GitHub answered ${res.status} for the releases`);
    cache = { at: Date.now(), etag: res.headers.get('etag'), releases: await res.json() };
    return cache.releases;
  }

  const send = (res, status, body, type = 'application/json; charset=utf-8', headers = {}) => {
    res.writeHead(status, { 'Content-Type': type, 'X-Content-Type-Options': 'nosniff', ...headers });
    res.end(type.startsWith('application/json') ? JSON.stringify(body) : body);
  };

  async function handle(req, res) {
    const url = new URL(req.url, 'http://local');
    if (req.method !== 'GET' && req.method !== 'HEAD') return send(res, 405, { error: 'method not allowed' });
    const parts = url.pathname.split('/').filter(Boolean);

    if (url.pathname === '/health') return send(res, 200, { ok: true, configured: Boolean(cfg.token) });
    if (!cfg.token) return send(res, 503, { error: 'the service has no GITHUB_TOKEN' });

    try {
      // GET /v1/mac/releases: GitHub's releases shape, only Koncluí's Mac releases, links through this service.
      if (url.pathname === '/v1/mac/releases') {
        const list = macReleases(await releases(), cfg);
        return send(res, 200, list, undefined, { 'Cache-Control': 'public, max-age=60' });
      }

      // GET /v1/mac/download/<tag>/Konclui.zip: a redirect to GitHub's short-lived link for the private asset.
      if (parts.length === 5 && parts[0] === 'v1' && parts[1] === 'mac' && parts[2] === 'download' && parts[4] === ASSET) {
        const tag = parts[3];
        if (!TAG.test(tag)) return send(res, 404, { error: 'no such release' });
        let id = assetId(await releases(), tag, cfg.blocked);
        if (id == null) id = assetId(await releases({ fresh: true }), tag, cfg.blocked);   // published a moment ago
        if (id == null) return send(res, 404, { error: 'no such release' });
        const asset = await github(`/releases/assets/${id}`, { headers: { Accept: 'application/octet-stream' } });
        const location = asset.headers.get('location');
        if (asset.status >= 300 && asset.status < 400 && location) {
          return send(res, 302, '', 'text/plain; charset=utf-8', { Location: location, 'Cache-Control': 'no-store' });
        }
        return send(res, 502, { error: `GitHub answered ${asset.status} for the asset` });
      }

      // GET /v1/mac/notes/<tag|latest>: the release notes as a page, for "See what's new".
      if (parts.length === 4 && parts[0] === 'v1' && parts[1] === 'mac' && parts[2] === 'notes') {
        const list = macReleases(await releases(), cfg);
        const release = parts[3] === 'latest' ? list[0] : list.find((r) => r.tag_name === parts[3]);
        if (!release && parts[3] !== 'latest') return send(res, 404, notesPage(null), 'text/html; charset=utf-8');
        return send(res, 200, notesPage(release), 'text/html; charset=utf-8', { 'Cache-Control': 'public, max-age=60' });
      }

      return send(res, 404, { error: 'not found' });
    } catch (error) {
      console.error(`[updates] ${error.message}`);   // never the token, never who asked
      return send(res, 502, { error: 'the releases are unreachable right now' });
    }
  }

  return { handle, releases };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const cfg = config();
  if (!cfg.token) console.error('[updates] GITHUB_TOKEN is not set: every release request answers 503');
  const service = createService(cfg);
  createServer(service.handle).listen(cfg.port, () => console.log(`[updates] listening on ${cfg.port} for ${cfg.repo}`));
}
