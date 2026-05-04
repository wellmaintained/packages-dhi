# SENAITE LIMS — Local Deployment

Two-container deployment stack for SENAITE LIMS 2.0.0 (a SENAITE app
container plus an nginx reverse proxy) backed by a named ZODB volume.

| Stack | Compose file | Default URL | Plone | senaite.lims | Image |
|-------|--------------|-------------|-------|---------------|-------|
| 2.0.0 | `docker-compose.yml` | http://localhost/ (port 80) | 5.2.4 (Zope 4 / WSGI) | 2.0.0 | `senaite-lims:dev` |

## Prerequisites

- **Docker** with `docker compose` (v2). Recent Docker Desktop or any
  Docker Engine ≥ 20.10 with the compose plugin installed.
- **Just** (https://just.systems). `just --version` should report ≥ 1.0.
- The senaite-lims image must be available locally. Either:
  - Pull from GHCR once the pre-release pipeline publishes it, or
  - Build it yourself (the python-2.7 base must exist locally first):
    `APP=senaite just ci build python-2.7 && APP=senaite just ci build senaite-lims`

  The build produces `ghcr.io/wellmaintained/packages-dhi/senaite-lims:dev`
  in your local Docker image store. Verify with
  `docker images | grep senaite-lims`.

## Recipes

All recipes are defined at the repository root `Justfile`.

| Command | What it does |
|---------|--------------|
| `just senaite-up` | Start the stack on http://localhost/ |
| `just senaite-down` | Stop the stack **and** delete its ZODB volume |
| `just senaite-logs` | Tail logs from the stack |

`*-down` passes `-v` to `docker compose down`, which **wipes the ZODB
filestorage volume**. This is the right default for a demo environment
that you bring up and tear down repeatedly. To preserve ZODB state, run
the bare `docker compose -f apps/senaite/deployments/docker-compose.yml down`
without the `-v`.

## Configuration knobs

| Variable | Default | Effect |
|----------|---------|--------|
| `BIND_IP` | `127.0.0.1` | Host IP that nginx publishes to. |
| `HTTP_PORT` | `80` | Host port for the stack. |
| `SENAITE_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-lims container. |
| `NGINX_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-nginx container. |

`BIND_IP` defaults to `127.0.0.1`. Override (e.g. `BIND_IP=0.0.0.0
just senaite-up`) only on a trusted network — the admin/admin
credentials would be reachable from anything that can route to the
bind IP.

## First-time setup: create a SENAITE site

When the stack starts for the first time, ZODB is empty and Plone shows
its "add new site" form at the root. SENAITE adds a `@@senaite-addsite`
view that pre-populates the form for a SENAITE-shaped site.

1. Bring the stack up (`just senaite-up`). Wait ~30–60s for the
   senaite-lims healthcheck to flip to "healthy" — buildout-installed
   C extensions need to import on first launch.
2. Tail the logs (`just senaite-logs`) until you see
   `Zope Ready to handle requests`.
3. Open http://localhost/ in a browser. You should see the Plone
   "Welcome to Plone" / "Create a new SENAITE site" page.
4. Click **Create a SENAITE site** (or POST directly to
   `/@@senaite-addsite` with form fields `site_id=senaite`
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
  `apps/senaite/images/senaite-lims/prod.yaml`.

The credentials are visible in that image-definition file; treat any
deployment that reuses them as ephemeral.

## What's running

```
┌──────────────────┐  :80           ┌──────────────────────────────┐
│   browser        │ ─────────────► │  senaite-nginx               │
│   localhost      │                │  dhi.io/nginx:1.29           │
└──────────────────┘                │  proxy_pass with VHM prefix  │
                                    └──────────────┬───────────────┘
                                                   │  :8080
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │  senaite-lims                │
                                    │  Plone + senaite.lims        │
                                    │  Data.fs → named volume      │
                                    └──────────────────────────────┘
```

The nginx config (`nginx/default.conf`) injects a Plone
VirtualHostMonster (VHM) URL prefix so that absolute URLs Plone
generates (links, redirects, `absolute_url()` calls) match the public
host the browser sees. It uses `$host:$server_port` in the VHM URL —
adequate while the stack publishes on the default HTTP port (80).
The config forwards `Host`, `X-Real-IP`, `X-Forwarded-For`,
`X-Forwarded-Host`, and `X-Forwarded-Proto`, and disables proxy
buffering so SENAITE's report-streaming endpoints work.

## Persistent state

The stack uses a single named volume for its ZODB Data.fs plus blob
storage:

| Volume name (project-prefixed) | Mounted at |
|--------------------------------|------------|
| `deployments_senaite_filestorage` | `/opt/senaite/var/filestorage` |

Logs (`/opt/senaite/var/log`), the buildout instance pidfile, and
other runtime state inside `var/` are **not** persisted; they are
regenerated on each container start. To preserve logs, extend the
compose file with a second volume covering the parent dir.

## Production deployment notes

- The compose file references the image by plain tag. A digest-pinned
  variant produced from `apps/senaite/app-images.lock.yaml` is the
  intended production artefact. Build it with
  `APP=senaite just build-app-compose` (or the `build-senaite-compose`
  per-app wrapper).
- The senaite-lims image is currently tagged `:dev` — the
  locally-built artefact. Once the CI pre-release pipeline pushes the
  senaite-lims component tag to GHCR, switch the `image:` line to
  the GHCR-published digest from
  `apps/senaite/app-images.lock.yaml`.

## Helm chart

Not provided. The reference deployment at `apps/sbomify-current/deployments/`
ships compose files only — there is no `helm/` subdirectory to mirror.
Adding Helm charts for SENAITE is left as future work and should land
alongside (or after) a sbomify Helm chart so the structures stay
aligned across apps.
