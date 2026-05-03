# SENAITE LIMS — Local Deployment

A two-container stack that runs SENAITE LIMS 2.0.0 (Plone 5.2.4 on
Python 2.7) behind an nginx reverse proxy on `http://localhost/`. The
SENAITE application image is the wellmaintained DHI build defined at
`apps/senaite/images/senaite-lims/prod.yaml`; the proxy is the stock
`dhi.io/nginx:1.29` image.

## Prerequisites

- **Docker** with `docker compose` (v2). Recent Docker Desktop or any
  Docker Engine ≥ 20.10 with the compose plugin installed.
- **Just** (https://just.systems). `just --version` should report ≥ 1.0.
- The senaite-lims image must be available locally. Either:
  - Pull from GHCR once the pre-release pipeline publishes it, or
  - Build it yourself: `APP=senaite just ci build python-2.7 && APP=senaite just ci build senaite-lims`. This produces `ghcr.io/wellmaintained/packages-dhi/senaite-lims:dev` in your local Docker image store.

## Recipes

All recipes are defined at the repository root `Justfile` and operate
against `apps/senaite/deployments/docker-compose.yaml`.

| Command | What it does |
|---------|--------------|
| `just senaite-up` | Start senaite-lims + nginx in the background |
| `just senaite-down` | Stop the stack **and** delete the ZODB volume |
| `just senaite-logs` | Tail logs from both containers |

Note that `senaite-down` passes `-v` to `docker compose down`, which
**wipes the ZODB filestorage volume**. This is the right default for a
demo environment that you bring up and tear down repeatedly. If you want
to preserve ZODB state, run `docker compose -f apps/senaite/deployments/docker-compose.yaml down`
without the `-v`.

## First-time setup: create a SENAITE site

When the stack starts for the first time, ZODB is empty and Plone shows
its "add new site" form at the root. SENAITE adds a `@@senaite-addsite`
view that pre-populates the form for a SENAITE-shaped site.

1. Run `just senaite-up`. Wait ~30–60s for the senaite-lims healthcheck
   to flip to "healthy" — buildout-installed C extensions need to import
   on first launch.
2. Tail the logs (`just senaite-logs`) until you see
   `Zope Ready to handle requests`.
3. Open `http://localhost/` in a browser. You should see the Plone
   "Welcome to Plone" / "Create a new SENAITE site" page.
4. Click **Create a SENAITE site** (or POST directly to
   `http://localhost/@@senaite-addsite` with form fields
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
  `apps/senaite/images/senaite-lims/prod.yaml` (the `[instance]` section
  of the inline buildout heredoc).

The credentials defined in the buildout config are visible in
`apps/senaite/images/senaite-lims/prod.yaml`; treat any deployment that
reuses them as ephemeral.

## What's running

```
┌──────────────────┐        ┌──────────────────────────────┐
│   browser        │  :80   │  senaite-nginx               │
│   localhost      │ ─────► │  dhi.io/nginx:1.29           │
└──────────────────┘        │  proxy_pass with VHM prefix  │
                            └──────────────┬───────────────┘
                                           │  :8080
                                           ▼
                            ┌──────────────────────────────┐
                            │  senaite-lims                │
                            │  Plone 5.2.4 + senaite.lims  │
                            │  Data.fs → ./senaite_filestorage│
                            └──────────────────────────────┘
```

The nginx config injects a Plone VirtualHostMonster URL prefix
(`/VirtualHostBase/http/$host:$server_port/VirtualHostRoot/`) so that
absolute URLs Plone generates (links, redirects, `absolute_url()`
calls) match the public host the browser sees. See
`apps/senaite/deployments/nginx/default.conf` for the full config and
inline rationale.

## Persistent state

A single named volume, `senaite_filestorage`, holds the ZODB Data.fs
plus blob storage. It is mounted at `/opt/senaite/var/filestorage`
inside the senaite-lims container.

Logs (`/opt/senaite/var/log`), the buildout instance pidfile, and other
runtime state inside `/opt/senaite/var` are **not** persisted; they are
regenerated on each container start. If you want to preserve logs,
extend the compose file with a second volume covering the parent dir.

## Production deployment notes

- This compose file references images by plain tag. A digest-pinned
  variant produced from `apps/senaite/app-images.lock.yaml` is the
  intended production artefact (mirroring the sbomify pattern at
  `Justfile:49 build-sbomify-compose`). Adding a sibling
  `build-senaite-compose` recipe is tracked as future work.
- The senaite-lims image is currently tagged `:dev` — the locally-built
  artefact. Once the CI pre-release pipeline pushes senaite-lims to
  GHCR, switch the `image:` line in `docker-compose.yaml` to the
  GHCR-published digest from `apps/senaite/app-images.lock.yaml`.
- `BIND_IP` defaults to `127.0.0.1`. Override (e.g. `BIND_IP=0.0.0.0
  just senaite-up`) only on a trusted network — the admin/admin
  credentials would be reachable from anything that can route to the
  bind IP.

## Helm chart

Not provided. The reference deployment at `apps/sbomify/deployments/`
ships compose files only — there is no `helm/` subdirectory to mirror.
Adding a Helm chart for SENAITE is left as future work and should land
alongside (or after) a sbomify Helm chart so the two stay structurally
aligned.
