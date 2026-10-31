// What the Mac app sees of Koncluí's releases. Pure functions, so `npm test` checks the rules without a network.
//
// The releases live in the private repository; the app never has a token. The service hands the app GitHub's own
// releases shape (MacUpdate.latest reads it unchanged), cut down to what the app needs and with every link pointing
// back at the service: the zip's download and the notes page.

export const ASSET = 'Konclui.zip';
/** Koncluí's Mac tags. Upstream Coucou's `v0.5.6` tags reach the repository with every sync: never Koncluí's. */
export const TAG = /^konclui-v\d+(\.\d+){1,3}$/;

/** The published Mac releases, newest first as GitHub lists them, without the blocked tags. */
export function macReleases(releases, { publicURL, blocked = new Set() }) {
  const out = [];
  for (const r of Array.isArray(releases) ? releases : []) {
    if (r?.draft || r?.prerelease || !TAG.test(r?.tag_name ?? '') || blocked.has(r.tag_name)) continue;
    const zip = (r.assets ?? []).find((a) => a?.name === ASSET);
    if (!zip) continue;
    out.push({
      tag_name: r.tag_name,
      name: r.name ?? r.tag_name,
      draft: false,
      prerelease: false,
      published_at: r.published_at ?? null,
      body: r.body ?? '',
      html_url: `${publicURL}/v1/mac/notes/${r.tag_name}`,
      assets: [{ name: ASSET, size: zip.size ?? 0, browser_download_url: `${publicURL}/v1/mac/download/${r.tag_name}/${ASSET}` }],
    });
  }
  return out;
}

/** The GitHub asset id of a tag's zip, if that release is one the app may download. */
export function assetId(releases, tag, blocked = new Set()) {
  if (!TAG.test(tag) || blocked.has(tag)) return null;
  const r = (Array.isArray(releases) ? releases : []).find((x) => x?.tag_name === tag && !x.draft && !x.prerelease);
  return r?.assets?.find((a) => a?.name === ASSET)?.id ?? null;
}

/** "konclui-v0.6.0,konclui-v0.6.1" → a set; the emergency brake for a release that must not be installed. */
export function parseBlocked(value) {
  return new Set(String(value ?? '').split(',').map((s) => s.trim()).filter(Boolean));
}

const escape = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

/** The page "See what's new" opens: the release notes, as plain text, nothing loaded from elsewhere. */
export function notesPage(release) {
  const title = release ? `Koncluí ${release.tag_name.replace(/^konclui-v/, '')}` : 'Koncluí';
  const body = release ? escape(release.body || '') : 'No release yet.';
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(title)}</title>
<style>body{font:15px/1.6 -apple-system,system-ui,sans-serif;background:#03051a;color:#f0f5fb;margin:0;padding:48px 24px}
main{max-width:680px;margin:auto}h1{font-size:28px;margin:0 0 24px}pre{white-space:pre-wrap;font:inherit;color:#b4bdcc}</style>
</head><body><main><h1>${escape(title)}</h1><pre>${body}</pre></main></body></html>
`;
}
