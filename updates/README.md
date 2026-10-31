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
| `GET /health` | `{"ok": true, "configured": true}` (`configured` is whether a token is set; the token never appears) |
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

1. **The token** (github.com → Settings → Developer settings → Fine-grained tokens → Generate): resource owner `konclui`,
   only `konclui/konclui-notch`, Repository permissions → Contents: Read-only, an expiry you will remember to renew.
2. **The app** in the Koncluí project: source GitHub `konclui/konclui-notch`, branch `main`, build path `/updates`, build type
   Dockerfile. Environment: `GITHUB_TOKEN=<the token>` (and `PUBLIC_URL` if the domain is not `updates.konclui.com`).
3. **The domain** `updates.konclui.com` → port 3000, HTTPS on.
4. **Deploy**, then check from any Mac:
   `curl https://updates.konclui.com/health` → `{"ok":true,"configured":true}`, and
   `curl https://updates.konclui.com/v1/mac/releases` → `[]` until the first release, then that release.

Easypanel rebuilds the service on every push to `main` (its webhook does not filter folders): a rebuild takes seconds and
changes nothing when `updates/` did not change.

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
