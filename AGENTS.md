# Streama — development environment notes

Streama is a **Grails 3.2.6** app (Groovy, AngularJS 1.x frontend, JDK 8 + Gradle 3.1). Everything
needed to run it here is in `docker-compose.base44.yml`.

## Running it

```bash
docker compose -f docker-compose.base44.yml up -d
docker compose -f docker-compose.base44.yml logs -f streama
```

- Web entry point: host port **3000** → container 8080 (`http://localhost:3000`).
- **Do not use `docker/docker-compose.yml` or `docker/Dockerfile`** — they download a prebuilt
  release jar and freeze the code. `docker-compose.base44.yml` runs the app from the source bind
  mount with `./gradlew bootRun`, so edits are live.
- First start downloads the Gradle 3.1 distribution plus all Maven artifacts from
  `https://grails.jfrog.io/grails/core` into the `gradle_home` volume (several minutes). Later
  starts compile from the cached dependencies (~1 min).

## Services / config

- `mysql` — MySQL 5.7, database `streama`. The app runs with the repo's own **`mysql` Grails
  environment** (`grails-app/conf/application.yml`), which reads `MYSQL_HOST`, `MYSQL_PORT`,
  `MYSQL_DB`, `MYSQL_USER`, `MYSQL_PASSWORD` (Spring relaxed binding of `${mysql_host:…}`).
- Hibernate `dbCreate: update` creates the schema; `BootStrap.groovy` seeds the roles, the default
  users and the default settings. The seeded admin account (username/password) is defined in
  `grails-app/services/streama/DefaultDataService.groovy` (`createDefaultUsers`).
- Uploaded media lives in the `streama_data` volume mounted at `/data`.
- No external credentials are required to boot. The **TheMovieDB API key** is an in-app setting
  (Settings page), not an environment variable.
- *Upload Directory* is seeded to `/data/streama` (the `streama_data` volume), so uploads work
  out of the box; change it in Settings if you mount media elsewhere.

## Media uploads & page weight

- **No upload size cap.** `spring.http.multipart.max-file-size` / `max-request-size` are `-1`,
  `server.tomcat.max-http-post-size` / `max-swallow-size` are `-1`, and
  `grails.controllers.upload.maxFileSize` / `maxRequestSize` are 10TB. Verified: a 1.2 GB `.mp4`
  posted to `/file/upload` with an admin session returns `200 {"id":…}` in ~18 s.
  `FileController.upload` renders JSON explicitly, so the endpoint answers JSON with or without the
  `.json` suffix. It used to `respond`, which made a plain `/file/upload` request try to resolve an
  HTML view named `upload` and throw `Could not resolve view with name 'upload'` (500).
- Uploads stream to the container temp dir and are then moved to
  `<Upload Directory>/upload/<sha256><ext>` (currently `/data/streama`). The directory is
  configurable in Settings → *Upload Directory* (extra read-only folders: *Second Directory*), so
  media can live wherever you mount it — but budget 2× the file size free during an upload.
- **Page weight / load time:** `grails.assets.bundle: true` + `grails.assets.debug: false` serve
  the bundled `vendor.js` / `streama.js` / `application.css` (6 requests, ~1 MB gzipped) instead of
  ~60-160 separately expanded files (4.3 MB uncompressed). Tomcat gzip (`server.compression`) is
  on. Asset-pipeline still answers `Cache-Control: no-cache` under `bootRun`, so every reload
  re-fetches the bundles — expected here.
- Quick check: `curl -s http://localhost:3000/login/auth | grep -c 'assets/'` should be small (~6).
  Both fixes live in `grails-app/conf/application.yml`, so they need
  `docker compose -f docker-compose.base44.yml restart streama`.

## Dev loop

- JS / CSS / GSP assets: asset-pipeline recompiles them at request time in the `mysql` (non
  development) environment — a browser refresh is enough.
- Groovy changes (controllers, services, domains, `BootStrap`): no auto-reload with `bootRun`;
  restart the app service — `docker compose -f docker-compose.base44.yml restart streama`.
- `/` returns **302 → `/login/auth`** when signed out, so it doubles as the health check, and
  `/api/v1/currentUser` plus `/api/v1/dash/*` answer once a session exists.
- The login **form action is `POST /login/authenticate`** (`/login/auth` only renders the form).
  Posting to `/login/auth` silently re-renders the login page instead of authenticating.
- Browser automation note: the Base44 preview bridge can fail to attach across the `/` → `/login/auth`
  redirect; load `/login/auth` directly when driving the page.

## Tests

`src/test/groovy` contains Spock specs; run them inside the container:
`docker compose -f docker-compose.base44.yml exec -T streama ./gradlew --no-daemon test`
