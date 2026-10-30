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
  users and the default settings. Credentials out of the box: **admin / admin**.
- Uploaded media lives in the `streama_data` volume mounted at `/data`.
- No external credentials are required to boot. The **TheMovieDB API key** is an in-app setting
  (Settings page), not an environment variable.
- First login lands in the settings flow: the *Upload Directory* has no value yet, so set it there
  (e.g. `/data/streama`) before adding media.

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
