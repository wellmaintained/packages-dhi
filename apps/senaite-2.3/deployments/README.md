# SENAITE LIMS 2.3.x — Local Deployment

A two-container deployment stack for the SENAITE LIMS 2.3.x line: a
SENAITE app container plus an nginx reverse proxy, backed by a named
ZODB volume.

| Stack | Compose file | Default URL | Plone | senaite.lims | Image |
|-------|--------------|-------------|-------|---------------|-------|
| 2.3.x | `docker-compose.yml` | http://localhost:8081/ (port 8081) | 5.2.9 (Zope 4 / WSGI) | 2.3.0 | `senaite-lims-2.3:dev` |

This stack is the per-version-line 2.3.x sibling of `senaite-1.3` (port
8080) and `senaite-current` (port 80). Each line's app is structurally
self-contained — the long-term shape of a "release line" abstraction will
emerge once a third version-line is on the table (see ADR-0015).

## Prerequisites

- **Docker** with `docker compose` (v2). Recent Docker Desktop or any
  Docker Engine ≥ 20.10 with the compose plugin installed.
- **Just** (https://just.systems). `just --version` should report ≥ 1.0.
- The `senaite-lims-2.3:dev` image must be available locally. Either:
  - Pull from GHCR once the pre-release pipeline publishes it, or
  - Build it yourself (the python-2.7 base must exist locally first):

    ```sh
    APP=senaite-2.3 just ci build python-2.7
    APP=senaite-2.3 just ci build senaite-lims
    ```

  The build produces `ghcr.io/wellmaintained/packages-dhi/senaite-lims-2.3:dev`
  in your local Docker image store. Verify with
  `docker images | grep senaite-lims-2.3`.

## Recipes

```sh
APP=senaite-2.3 just app-up      # Start on http://localhost:8081/
APP=senaite-2.3 just app-down    # Stop and delete the ZODB volume
APP=senaite-2.3 just app-logs    # Tail logs
```

`*-down` passes `-v` to `docker compose down`, which **wipes the ZODB
filestorage volume**. To preserve ZODB state, run the bare
`docker compose -f apps/senaite-2.3/deployments/docker-compose.yml down`
without the `-v`.

## Running alongside other version-line stacks

The 2.3.x stack picks host port 8081 by default and uses the project name
`senaite-2-3`, so it lands in a distinct project namespace from the
1.3.x stack (port 8080, project `senaite-1-3`) and the current stack
(port 80). All three can run concurrently:

```sh
APP=senaite-current just app-up   # 2.6.x at http://localhost/
APP=senaite-2.3 just app-up       # 2.3.x at http://localhost:8081/
APP=senaite-1.3 just app-up       # 1.3.x at http://localhost:8080/
```

## Configuration knobs

| Variable | Default | Effect |
|----------|---------|--------|
| `BIND_IP` | `127.0.0.1` | Host IP that nginx publishes to. |
| `HTTP_PORT_23` | `8081` | Host port for this stack. |
| `SENAITE_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-lims container. |
| `NGINX_RESTART_POLICY` | `unless-stopped` | restart policy for the senaite-nginx container. |

Override at the command line, e.g. `HTTP_PORT_23=18081 APP=senaite-2.3 just app-up`
to run the stack on http://localhost:18081/ (useful when port 8081 is
already in use).

`BIND_IP` defaults to `127.0.0.1`. Override (e.g. `BIND_IP=0.0.0.0
APP=senaite-2.3 just app-up`) only on a trusted network — the
admin/admin credentials would be reachable from anything that can route
to the bind IP.

## First-time setup: create a SENAITE site

When the stack starts for the first time, ZODB is empty and Plone shows
its "add new site" form at the root. SENAITE adds a `@@senaite-addsite`
view that pre-populates the form for a SENAITE-shaped site.

1. Bring the stack up (`APP=senaite-2.3 just app-up`). Wait ~30–60s for
   the senaite-lims healthcheck to flip to "healthy" — buildout-installed
   C extensions need to import on first launch.
2. Tail the logs (`APP=senaite-2.3 just app-logs`) until you see
   `Zope Ready to handle requests`.
3. Open http://localhost:8081/ in a browser. You should see the Plone
   "Welcome to Plone" / "Create a new SENAITE site" page.
4. Click **Create a SENAITE site** (or POST directly to
   `http://localhost:8081/@@senaite-addsite` with form fields
   `site_id=senaite` and `site_title=SENAITE LIMS`).
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
  `apps/senaite-2.3/images/senaite-lims/prod.yaml`.

The credentials are visible in the image-definition file; treat any
deployment that reuses them as ephemeral.

## What's running

```
┌──────────────────┐   :8081        ┌──────────────────────────────┐
│   browser        │ ─────────────► │  senaite-nginx               │
│   localhost      │                │  dhi.io/nginx:1.29           │
└──────────────────┘                │  proxy_pass with VHM prefix  │
                                    └──────────────┬───────────────┘
                                                   │  :8080
                                                   ▼
                                    ┌──────────────────────────────┐
                                    │  senaite-lims                │
                                    │  Plone 5.2.9 + senaite.lims  │
                                    │  Data.fs → named volume      │
                                    └──────────────────────────────┘
```

The nginx config injects a Plone VirtualHostMonster (VHM) URL prefix
so that absolute URLs Plone generates (links, redirects,
`absolute_url()` calls) match the public host the browser sees. The
2.3 config uses `$http_host` (raw Host header) so the public URL
preserves the host port the user is connecting to (e.g. 8081), since
nginx's in-container listen port (80) wouldn't.

## Persistent state

| Volume name (project-prefixed) | Mounted at |
|--------------------------------|------------|
| `senaite-2-3_senaite_filestorage_23` | `/opt/senaite/var/filestorage` |

Logs (`/opt/senaite/var/log`), the buildout instance pidfile, and other
runtime state inside `var/` are **not** persisted; they are regenerated
on each container start.

## Production deployment notes

- The compose file references images by plain tag. A digest-pinned
  variant produced from `apps/senaite-2.3/app-images.lock.yaml` is the
  intended production artefact (build with
  `APP=senaite-2.3 just build-app-compose`).
- The senaite-lims image is currently tagged `:dev` — the locally-built
  artefact. Once the CI pre-release pipeline pushes the senaite-lims-2.3
  component tag to GHCR, switch the `image:` line to the GHCR-published
  digest from `apps/senaite-2.3/app-images.lock.yaml`.
