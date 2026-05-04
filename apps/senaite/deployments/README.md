# SENAITE LIMS — Local Deployment

Two parallel deployment stacks for SENAITE LIMS:

| Stack | Compose file | Default URL | Plone | senaite.lims | Image |
|-------|--------------|-------------|-------|---------------|-------|
| 2.0.0 | `docker-compose.yml` | http://localhost/ (port 80) | 5.2.4 (Zope 4 / WSGI) | 2.0.0 | `senaite-lims:dev` |
| 1.3.5 | `docker-compose-1.3.yml` | http://localhost:8080/ (port 8080) | 4.3.20 (Zope 2.13 / ZServer) | 1.3.5 | `senaite-lims-1.3:dev` |

Each stack is a two-container deployment (a SENAITE app container plus
an nginx reverse proxy) backed by a named ZODB volume. The two stacks
are deliberately structured as **siblings** rather than variants of a
shared base — the long-term shape of a "release line" abstraction will
emerge from this duplication once the smoke-test and release-website
integration siblings land.

## Prerequisites

- **Docker** with `docker compose` (v2). Recent Docker Desktop or any
  Docker Engine ≥ 20.10 with the compose plugin installed.
- **Just** (https://just.systems). `just --version` should report ≥ 1.0.
- The relevant senaite-lims image must be available locally. Either:
  - Pull from GHCR once the pre-release pipeline publishes it, or
  - Build it yourself (the python-2.7 base must exist locally first):
    - 2.0.0: `APP=senaite just ci build python-2.7 && APP=senaite just ci build senaite-lims`
    - 1.3.5: `APP=senaite just ci build python-2.7 && APP=senaite just ci build senaite-lims-1.3`

  Each build produces `ghcr.io/wellmaintained/packages-dhi/<image>:dev`
  in your local Docker image store. Verify with
  `docker images | grep senaite-lims`.

## Recipes

All recipes are defined at the repository root `Justfile`.

| Command | What it does |
|---------|--------------|
| `just senaite-up` | Start the 2.0.0 stack on http://localhost/ |
| `just senaite-down` | Stop the 2.0.0 stack **and** delete its ZODB volume |
| `just senaite-logs` | Tail logs from the 2.0.0 stack |
| `just senaite-1-3-up` | Start the 1.3.5 stack on http://localhost:8080/ |
| `just senaite-1-3-down` | Stop the 1.3.5 stack **and** delete its ZODB volume |
| `just senaite-1-3-logs` | Tail logs from the 1.3.5 stack |

Note: `just` disallows `.` in recipe names, so the 1.3.x recipes are
named `senaite-1-3-up` rather than `senaite-1.3-up`.

`*-down` passes `-v` to `docker compose down`, which **wipes the ZODB
filestorage volume**. This is the right default for a demo environment
that you bring up and tear down repeatedly. To preserve ZODB state, run
the bare `docker compose -f apps/senaite/deployments/<file>.yml down`
without the `-v`.

## Running both stacks at once

Both stacks can run concurrently. Each compose file declares its own
project name (`deployments` for 2.0.0 — derived from the parent
directory — and an explicit `senaite-1-3` for 1.3.5), so they land in
distinct project namespaces with no shared container, network, or
volume names. The 2.0.0 stack publishes nginx on host port 80 and the
1.3.5 stack on host port 8080; nothing else is exposed.

```sh
just senaite-up
just senaite-1-3-up
# 2.0.0 at http://localhost/
# 1.3.5 at http://localhost:8080/
```

## Configuration knobs

Both stacks honour the same set of environment variables:

| Variable | Default | Effect |
|----------|---------|--------|
| `BIND_IP` | `127.0.0.1` | Host IP that nginx publishes to. |
| `HTTP_PORT` (2.0.0 only) | `80` | Host port for the 2.0.0 stack. |
| `HTTP_PORT_13` (1.3.5 only) | `8080` | Host port for the 1.3.5 stack. |
| `SENAITE_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-lims container. |
| `NGINX_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-nginx container. |

Override at the command line, e.g.
`HTTP_PORT_13=18080 just senaite-1-3-up` to run the 1.3 stack on
http://localhost:18080/ (useful when port 8080 is already in use).

`BIND_IP` defaults to `127.0.0.1`. Override (e.g. `BIND_IP=0.0.0.0
just senaite-up`) only on a trusted network — the admin/admin
credentials would be reachable from anything that can route to the
bind IP.

## First-time setup: create a SENAITE site

When a stack starts for the first time, ZODB is empty and Plone shows
its "add new site" form at the root. SENAITE adds a `@@senaite-addsite`
view that pre-populates the form for a SENAITE-shaped site.

1. Bring the stack up (`just senaite-up` or `just senaite-1-3-up`).
   Wait ~30–60s for the senaite-lims healthcheck to flip to "healthy" —
   buildout-installed C extensions need to import on first launch.
2. Tail the logs (`just senaite-logs` or `just senaite-1-3-logs`)
   until you see `Zope Ready to handle requests`.
3. Open the URL for that stack in a browser. You should see the Plone
   "Welcome to Plone" / "Create a new SENAITE site" page.
4. Click **Create a SENAITE site** (or POST directly to
   `<base-url>/@@senaite-addsite` with form fields `site_id=senaite`
   and `site_title=SENAITE LIMS`).
5. After site creation Plone redirects to `/senaite`. Log in via the
   user widget at `/senaite/login_form`.

## Default credentials

The buildout configuration baked into both images creates an emergency
Zope user with credentials:

- **Username:** `admin`
- **Password:** `admin`

These are appropriate for a local demo only. For anything beyond that:

- Override the user before exposing the service. The simplest way is to
  exec into the container and run `bin/instance adduser <user> <pass>`.
- Or rebuild the image with a different `user = ...` line in the image
  definition — `apps/senaite/images/senaite-lims/prod.yaml` for 2.0.0
  or `apps/senaite/images/senaite-lims-1.3/prod.yaml` for 1.3.5.

The credentials are visible in those image-definition files; treat any
deployment that reuses them as ephemeral.

## What's running

Both stacks share the same shape:

```
┌──────────────────┐  :80 or :8080   ┌──────────────────────────────┐
│   browser        │ ──────────────► │  senaite-nginx               │
│   localhost      │                 │  dhi.io/nginx:1.29           │
└──────────────────┘                 │  proxy_pass with VHM prefix  │
                                     └──────────────┬───────────────┘
                                                    │  :8080
                                                    ▼
                                     ┌──────────────────────────────┐
                                     │  senaite-lims                │
                                     │  Plone + senaite.lims        │
                                     │  Data.fs → named volume      │
                                     └──────────────────────────────┘
```

The nginx config injects a Plone VirtualHostMonster (VHM) URL prefix
so that absolute URLs Plone generates (links, redirects,
`absolute_url()` calls) match the public host the browser sees.

The two stacks ship slightly different nginx configs:

- `nginx/default.conf` (2.0.0) uses `$host:$server_port` in the VHM
  URL. Adequate while the stack publishes on the default HTTP port (80) —
  the browser's Host header omits the port, and `$server_port`
  resolves to the in-container nginx listen port (also 80).
- `nginx/default-1.3.conf` (1.3.5) uses `$http_host`. `$server_port`
  reflects nginx's in-container listen port (80), not the host port
  the user is connecting to (8080), so the 2.0.0 form would lock
  Plone to port 80 even when the user is on :8080. `$http_host` is
  the raw Host header, which preserves the browser's view
  ("localhost:8080" when on :8080, plain "localhost" when on :80).

Both configs forward `Host`, `X-Real-IP`, `X-Forwarded-For`,
`X-Forwarded-Host`, and `X-Forwarded-Proto`, and disable proxy
buffering so SENAITE's report-streaming endpoints work.

## Persistent state

Each stack uses a single named volume for its ZODB Data.fs plus blob
storage:

| Stack | Volume name (project-prefixed) | Mounted at |
|-------|--------------------------------|------------|
| 2.0.0 | `deployments_senaite_filestorage` | `/opt/senaite/var/filestorage` |
| 1.3.5 | `senaite-1-3_senaite_filestorage_13` | `/opt/senaite-1.3/var/filestorage` |

Logs (`/opt/<senaite>/var/log`), the buildout instance pidfile, and
other runtime state inside `var/` are **not** persisted; they are
regenerated on each container start. To preserve logs, extend the
relevant compose file with a second volume covering the parent dir.

## Production deployment notes

- Both compose files reference images by plain tag. A digest-pinned
  variant produced from `apps/senaite/app-images.lock.yaml` is the
  intended production artefact. Build it with
  `APP=senaite just build-app-compose` (or the `build-senaite-compose`
  per-app wrapper). Note that the existing wrapper currently pins
  `docker-compose.yml` only — pinning `docker-compose-1.3.yml` is a
  follow-up once we settle on whether 1.3.x and 2.0.0 share or diverge
  production manifests.
- The senaite-lims images are currently tagged `:dev` — the
  locally-built artefacts. Once the CI pre-release pipeline pushes the
  senaite-lims and senaite-lims-1.3 component tags to GHCR, switch the
  `image:` lines to the GHCR-published digests from
  `apps/senaite/app-images.lock.yaml`.

## Helm chart

Not provided. The reference deployment at `apps/sbomify-current/deployments/`
ships compose files only — there is no `helm/` subdirectory to mirror.
Adding Helm charts for SENAITE is left as future work and should land
alongside (or after) a sbomify Helm chart so the structures stay
aligned across apps.
