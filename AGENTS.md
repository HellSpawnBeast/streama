# Working on this repo in the sandbox

## Stack
- Grails 3.2.6 / Gradle wrapper 3.1 / Groovy, AngularJS frontend served from `grails-app/assets`.
- **The Gradle 3.1 wrapper only runs on JDK 8.** Newer JDKs fail before any task runs; the dev image
  (`docker/base44/dev.Dockerfile`) pins `eclipse-temurin:8-jdk`.

## Run
```bash
docker compose -f docker-compose.base44.yml up -d --build   # first build: several minutes
```
- Entry point: host port 3000 -> container 8080. `/` requires login and redirects to `/login/auth`.
- Datasource: the app's own `docker` environment in `grails-app/conf/application.yml`
  (`jdbc:h2:/data/streamadb`, `dbCreate: update`), so **no MySQL service is needed**. The repo's
  `docker/docker-compose.yml` (prebuilt release JAR + MySQL) is for production only — never use it here.
- Named volumes: `streama_data` -> `/data` (H2 files + default upload dir `/data/streama`),
  `gradle_cache` -> `/root/.gradle` (Gradle distribution + dependencies).
- Dependencies resolve from `https://grails.jfrog.io/grails/core`; a cold cache takes ~5 minutes.

## Reloading edits
`bootRun` runs under the custom `docker` environment, so Grails/spring-loaded hot reload is **off**.
After editing Groovy, GSP or asset files: `docker compose -f docker-compose.base44.yml restart streama`
(~30s) and then refresh the preview. Asset files are served with `?compile=false`, so they are
recompiled by the asset pipeline on request.

## First-run behaviour
- `BootStrap` creates `ROLE_ADMIN` + the default user **admin / admin** (only when `ROLE_ADMIN` is missing)
  and the default settings rows, so the schema is created automatically — no separate seed step.
- After login the user lands on the dashboard (`/`); Settings is at `/settings/index`.
- The TMDb API key and OpenSubtitles key are configured in the Settings UI and stored in the DB —
  they are optional and not needed to boot. ffmpeg is installed in the dev image for the optional
  audio-transcoding feature; it is auto-detected.
- `streama-remember-me.key` is generated in the working directory on first boot (gitignored).

## Verify
```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:3000/login/auth          # 200
curl -s -c /tmp/c.txt -o /dev/null -w '%{http_code}\n' -X POST \
  -d 'username=admin&password=admin&remember_me=on' http://localhost:3000/login/authenticate  # 302
curl -s -b /tmp/c.txt http://localhost:3000/api/currentUser                        # admin JSON
```
App logs: `docker compose -f docker-compose.base44.yml logs -f streama` — look for
`Grails application running at http://localhost:8080 in environment: docker`.

## Tests
Run inside the container: `docker compose -f docker-compose.base44.yml exec -T streama ./gradlew test`
(slow, resolves selenium/htmlunit test dependencies).

## Sandbox notes
- `BASE44_PREVIEW_MODE` is passed through to the service but no sandbox-only code path is required:
  the app binds `0.0.0.0:8080` and performs no Host/Origin allowlist checks of its own.
