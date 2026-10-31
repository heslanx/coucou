# Koncluí updates

The service the Mac app asks for updates. Koncluí's releases live in the private repository `konclui/konclui-notch`; the app
has no token, so it asks this service, which holds a read-only token and answers with what the app may install. Why it is
so: [ADR-002](../docs/konclui/decisions/ADR-002-update-service.md). How the app uses it:
[WORKFLOW.md](../docs/konclui/WORKFLOW.md), "How the app finds and installs an update".

```
Koncluí (Mac) ──HTTPS──▶ updates.konclui.com (this service, Easypanel)
                              │  GITHUB_TOKEN, read-only, only in this process
                              ▼
                     konclui/konclui-notch (private) → Releases → Konclui.zip
```

## Endpoints

| Request | Answer |
|---|---|
| `GET /health` | `{"ok": true, "configured": true, "startedAt": "…"}`: `configured` is whether a token is set (the token never appears); `startedAt` changes at every deploy, the proof that a push to `main` was deployed |
| `GET /v1/mac/releases` | GitHub's releases shape, cut to Koncluí's Mac releases: published, not prereleases, tag `konclui-vX.Y.Z`, a `Konclui.zip`, not blocked. Every link points at this service. `MacUpdate.latest` reads it as it read GitHub |
| `GET /v1/mac/download/<tag>/Konclui.zip` | `302` to GitHub's short-lived link for the private asset. The zip never passes through this service and the token never leaves it |
| `GET /v1/mac/notes/<tag>` or `/v1/mac/notes/latest` | the release notes as a page, for the app's "See what's new" |

The service asks GitHub at most once every `CACHE_SECONDS` (with the ETag, so an unchanged list does not spend the rate
limit), and again when a download names a tag it has not seen yet (a release published a moment ago). It keeps no logs of
who asked: no IPs, no versions, no identifiers (CLAUDE.md, no telemetry); it logs only its own errors.

## Settings

| Variable | Default | |
|---|---|---|
| `GITHUB_TOKEN` | (none) | **required**. A fine-grained token, repository `konclui/konclui-notch` only, permission Contents: Read only. Set in Easypanel; never in git, never in a message |
| `PUBLIC_URL` | `https://updates.konclui.com` | the address the app uses; the links in the answers are built on it |
| `REPO` | `konclui/konclui-notch` | where the releases are |
| `BLOCKED_TAGS` | (none) | the emergency brake: `konclui-v0.7.0,konclui-v0.7.1` disappear from the list and cannot be downloaded, at the next deploy |
| `CACHE_SECONDS` | `300` | how long the list is kept |
| `PORT` | `3000` | |

## Deploy on Easypanel

Deployed on 2026-10-30 on the KNC Easypanel (`epanel.konclui.com`), the same way as `bos_backend`:

| | |
|---|---|
| Service | project `backend`, service `updates` (app) |
| Source | GitHub `konclui/konclui-notch`, branch `main`, path `/updates`; Dockerfile |
| Automatic deploy | on: Easypanel added a `push` webhook to the repository (`services.app.enableGithubDeploy`) |
| Deploy | 1 replica, zero downtime |
| Domains | `updates.konclui.com` (the app's address; needs its DNS record, below) and `backend-updates.2i27md.easypanel.host` (works without any DNS, for checks) → port 3000, HTTPS |
| Environment | `PUBLIC_URL=https://updates.konclui.com`, `REPO=konclui/konclui-notch`, `PORT=3000`, and `GITHUB_TOKEN` (below) |

DNS: `updates` → the KNC server, proxied, in Cloudflare (created 2026-10-30, like `bos-api.konclui.com`). The server's Let's
Encrypt certificate is issued once the record exists: a domain added before its record keeps Easypanel's own certificate
(Cloudflare answers 526) until a redeploy makes the proxy ask again.

**The token**, the owner's step:

1. github.com → Settings → Developer settings → Fine-grained tokens → Generate. Resource owner `konclui`, only
   `konclui/konclui-notch`, Repository permissions → Contents: Read-only, an expiry you will remember to renew.
2. Into the Mac's Keychain, typed at a hidden prompt (nothing in the shell history):
   `security add-generic-password -U -a konclui -s konclui-updates-github-token -w`
3. `python3 updates/scripts/set-github-token.py`: accepts only a fine-grained token, checks that it reads the releases, puts it
   in Easypanel's environment, redeploys and waits for `/health` to say `configured`. Nothing is printed. Run it again to
   rotate the token.

Checks, from any Mac:

```
curl https://updates.konclui.com/health          # {"ok":true,"configured":true,"startedAt":"…"}
curl https://updates.konclui.com/v1/mac/releases # [] until the first release, then that release
```

A push to `main` redeploys the service (the webhook fires on every push; Easypanel always builds `main`). Easypanel's
automatic deploy fails silently when the image does not build, so after a change to `updates/` check that `startedAt` in
`/health` moved, not only that the push went through. The webhook's deliveries are on GitHub: repository Settings →
Webhooks.

Managing it without the UI: Easypanel's API (`POST /api/trpc/<procedure>`, `{"json": …}`) with `services.app.inspectService`,
`services.app.updateEnv`, `services.app.deployService`, `domains.listDomains`, `domains.createDomain`. `inspectService` returns
the environment, the token included: print only the fields you need.

## Pulling a release back

Add its tag to `BLOCKED_TAGS` and redeploy: within a minute no Mac sees it or can download it. A Mac that already installed it
keeps it; publish a fixed release with a higher version, which every Mac will take.

## Develop

```
cd updates
npm test                                   # 13 tests, a fake GitHub on localhost, no network
GITHUB_TOKEN=… npm start                   # http://localhost:3000/v1/mac/releases
docker build -t konclui-updates . && docker run --rm -p 3000:3000 -e GITHUB_TOKEN=… konclui-updates
```
