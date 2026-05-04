# SENAITE LIMS (current) — Local Deployment

The `-current` deployment tracks the **rolling latest** SENAITE line:
today senaite.lims 2.6.0 on Plone 5.2.15. When upstream ships a release
that fires the version-line criteria (see `docs/adr/0015-version-line-app-naming-with-current-sliding-pointer.md`),
this app is snapshot-renamed to `apps/senaite-2.6/` and a new
`apps/senaite-current/` is spun up against the new line.

| Stack | Compose file | Default URL | Plone | senaite.lims | Image |
|-------|--------------|-------------|-------|---------------|-------|
| current (2.6.0) | `docker-compose.yml` | http://localhost:8082/ | 5.2.15 (Zope 4 / WSGI) | 2.6.0 | `senaite-lims-current:dev` |

The stack is a two-container deployment (a SENAITE app container plus
an nginx reverse proxy) backed by a named ZODB volume.

The `-current` stack co-exists with the heritage stacks: senaite-1.3 on
:8080, senaite-2.3 on :8081, senaite-current on :8082. Pin to a numbered
line (senaite-2.3 etc.) for stability — `-current` slides forward over
time.

## Prerequisites

- **Docker** with `docker compose` (v2). Recent Docker Desktop or any
  Docker Engine ≥ 20.10 with the compose plugin installed.
- **Just** (https://just.systems). `just --version` should report ≥ 1.0.
- The senaite-lims-current image must be available locally. Either:
  - Pull from GHCR once the pre-release pipeline publishes it, or
  - Build it yourself (the python-2.7 base must exist locally first):
    - `APP=senaite-current just ci build python-2.7`
    - `APP=senaite-current just ci build senaite-lims`

  Each build produces `ghcr.io/wellmaintained/packages-dhi/senaite-lims-current:dev`
  in your local Docker image store. Verify with
  `docker images | grep senaite-lims-current`.

## Recipes

The generic `app-up` / `app-down` / `app-logs` recipes (in the
repo-root `Justfile`) are parameterised by the `APP` env var.

| Command | What it does |
|---------|--------------|
| `APP=senaite-current just app-up` | Start the stack on http://localhost:8082/ |
| `APP=senaite-current just app-down` | Stop the stack **and** delete its ZODB volume |
| `APP=senaite-current just app-logs` | Tail logs from the stack |

`app-down` passes `-v` to `docker compose down`, which **wipes the ZODB
filestorage volume**. This is the right default for a demo environment
that you bring up and tear down repeatedly. To preserve ZODB state, run
the bare `docker compose -f apps/senaite-current/deployments/docker-compose.yml down`
without the `-v`.

## Configuration knobs

| Variable | Default | Effect |
|----------|---------|--------|
| `BIND_IP` | `127.0.0.1` | Host IP that nginx publishes to. |
| `HTTP_PORT` | `8082` | Host port for the senaite-current stack. |
| `SENAITE_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-lims container. |
| `NGINX_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-nginx container. |

Override at the command line, e.g.
`HTTP_PORT=18082 APP=senaite-current just app-up` to run on
http://localhost:18082/ (useful when port 8082 is already in use).

`BIND_IP` defaults to `127.0.0.1`. Override (e.g.
`BIND_IP=0.0.0.0 APP=senaite-current just app-up`) only on a trusted
network — the admin/admin credentials would be reachable from anything
that can route to the bind IP.

## First-time setup: create a SENAITE site

When the stack starts for the first time, ZODB is empty and Plone shows
its "add new site" form at the root. SENAITE adds a `@@senaite-addsite`
view that pre-populates the form for a SENAITE-shaped site.

1. Bring the stack up (`APP=senaite-current just app-up`). Wait
   ~30–60s for the senaite-lims healthcheck to flip to "healthy" —
   buildout-installed C extensions need to import on first launch.
2. Tail the logs (`APP=senaite-current just app-logs`) until you see
   `Zope Ready to handle requests`.
3. Open http://localhost:8082/ in a browser. You should see the Plone
   "Welcome to Plone" / "Create a new SENAITE site" page.
4. Click **Create a SENAITE site** (or POST directly to
   `<base-url>/@@senaite-addsite` with form fields `site_id=senaite`
   and `site_title=SENAITE LIMS`).
5. After site creation Plone redirects to `/senaite`. Log in via the
   user widget at `/senaite/login_form`.

## Default credentials

The buildout configuration baked into the image creates an emergency
Zope user with credentials:

- **Username:** `admin`
- **Password:** `admin`

These are appropriate for a local demo only. For anything beyond that:

- Override the user before exposing the service. The simplest way is to
  exec into the container and run `bin/instance adduser <user> <pass>`.
- Or rebuild the image with a different `user = ...` line in
  `apps/senaite-current/images/senaite-lims/prod.yaml`.

The credentials are visible in that image-definition file; treat any
deployment that reuses them as ephemeral.

## What's running

```
┌──────────────────┐  :8082          ┌──────────────────────────────┐
│   browser        │ ──────────────► │  senaite-nginx               │
│   localhost      │                 │  dhi.io/nginx:1.29           │
└──────────────────┘                 │  proxy_pass with VHM prefix  │
                                     └──────────────┬───────────────┘
                                                    │  :8080
                                                    ▼
                                     ┌──────────────────────────────┐
                                     │  senaite-lims-current        │
                                     │  Plone 5.2.15 + senaite 2.6  │
                                     │  Data.fs → named volume      │
                                     └──────────────────────────────┘
```

The nginx config injects a Plone VirtualHostMonster (VHM) URL prefix
so that absolute URLs Plone generates (links, redirects,
`absolute_url()` calls) match the public host the browser sees.

`nginx/default.conf` uses `$http_host` (raw Host header) in the VHM
URL so the public host:port the browser sees is preserved verbatim,
even on non-default ports like :8082.

The config forwards `Host`, `X-Real-IP`, `X-Forwarded-For`,
`X-Forwarded-Host`, and `X-Forwarded-Proto`, and disables proxy
buffering so SENAITE's report-streaming endpoints work.

## Persistent state

A single named volume holds ZODB Data.fs plus blob storage:

| Volume name (project-prefixed) | Mounted at |
|--------------------------------|------------|
| `deployments_senaite_current_filestorage` | `/opt/senaite/var/filestorage` |

Logs (`/opt/senaite/var/log`), the buildout instance pidfile, and
other runtime state inside `var/` are **not** persisted; they are
regenerated on each container start. To preserve logs, extend the
compose file with a second volume covering the parent dir.

## Production deployment notes

- The compose file references images by plain tag. A digest-pinned
  variant produced from `apps/senaite-current/app-images.lock.yaml`
  is the intended production artefact. Build it with
  `APP=senaite-current just build-app-compose`.
- The senaite-lims-current image is currently tagged `:dev` — the
  locally-built artefact. Once the CI pre-release pipeline pushes
  the senaite-lims-current component tag to GHCR, switch the
  `image:` line to the GHCR-published digest from
  `apps/senaite-current/app-images.lock.yaml`.

## Helm chart

Not provided. The reference deployment at `apps/sbomify-current/deployments/`
ships compose files only — there is no `helm/` subdirectory to mirror.
