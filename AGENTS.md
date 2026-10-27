# AGENTS.md

Guidance for coding agents working on `osixia/openldap` (v2), an OpenLDAP container image built on [osixia/baseimage](https://github.com/osixia/container-baseimage) (Alpine).

## Documentation

- Keep the main `README.md` concise and simple. For new options, add only the required environment-variable table rows there; put explanations in the relevant service README.
- Document bootstrap features briefly alongside the other features in the existing bootstrap READMEs. Do not create a separate documentation page for a small feature unless explicitly requested, and do not add feature explanations to the main README.

## Repository layout

| Path | Role |
| --- | --- |
| `Dockerfile` | Installs pinned Alpine `openldap*` packages (`OPENLDAP_VERSION`), copies `services/` and `environment/`, runs as user `ldap` (uid/gid 911). |
| `environment/.env*` | Default env vars, loaded by the baseimage. One file per concern: core, bootstrap, ctl, cron, upgrade. |
| `services/<name>/` | baseimage services: `install.sh` (image build), `startup.sh` (each start), `process.sh` (long-running process). |
| `services/openldap/` | Runs `slapd`. Ships custom schemas, custom modules, certs dir and the `openldap-ctl` CLI. |
| `services/openldap-bootstrap/` | First-start initialization from LDIF fragments + feature scripts. |
| `services/openldap-upgrade/` | Version check + restore-based migration on start. |
| `services/openldap-pre-upgrade/` | Pre-upgrade backup, meant to run as an **init container on the N-1 image** (see below). |
| `services/openldap-cron/` | `crond` running scheduled backups (as root, separate container). |
| `build/` | Go CI/CD tool wrapping [osixia/dagger-build](https://github.com/osixia/dagger-build). Not part of the image. |
| `docs/examples/` | Compose examples (quickstart, replication). |

`.dockerignore` excludes `*.md`, `.gitkeep`, `build/`, `docs/`: none of them reach the image.

## baseimage service model

- Startup order follows `.priority`, **ascending** (lower runs first): `openldap` (100) → `openldap-bootstrap` (150) → `openldap-upgrade` (200). Services without `.priority` default to 500.
  - `openldap/startup.sh` copies modules and schemas first, so bootstrap can read them.
  - Bootstrap must run before upgrade: on a fresh install, upgrade runs `slapd -T test` on the freshly created config and writes the version file.
- `.optional` services (`openldap-cron`, `openldap-pre-upgrade`) are not started by default. Enable them explicitly, e.g. `osixia/openldap -x openldap-cron`.
- Use the baseimage CLI, not raw equivalents: `container log <level>` (`fatal` exits), `container envsubst`, `container processes start|stop openldap`, `container run -- <cmd>`, `container packages install`. The running slapd pid file is `/run/container/processes/openldap.pid`.

## Upgrade flow (important)

The upgrade is a **backup on N-1 / restore on N** mechanism, driven by the version file `${OPENLDAP_CONF_DIR}/.version` (`OPENLDAP_UPGRADE_CONF_VERSION_FILE`).

1. **`openldap-pre-upgrade` runs on the N-1 image, as an init container** (e.g. Kubernetes `initContainers` using the *previous* image tag, sharing the config, data and backup volumes) before the N container starts:
   - no version file → nothing to do;
   - version file matches the image's `OPENLDAP_VERSION` (at `OPENLDAP_UPGRADE_MIGRATION_LEVEL` granularity) → `openldap-ctl backup openldap-upgrade-<conf version>` (`slapcat` of db 0 and db 1);
   - otherwise → skip.

   It must run on N-1 because the dump has to be produced by the slapd/slapcat version that wrote the database. slapd is not running in the init container, so `slapcat` reads the files offline.
2. **`openldap-upgrade` runs on the N image** at every start:
   - no version file → `slapd -T test`, write version, exit;
   - same comparable version → nothing to do;
   - downgrade → fatal unless `OPENLDAP_UPGRADE_FORCE=true`;
   - otherwise needs `openldap-upgrade-<old conf version>{-config.gz,-data.gz}` in `OPENLDAP_BACKUP_DIR` (fatal if missing, unless forced), then `openldap-ctl restore ... --force` (checks the gzip files, wipes conf/data, `slapadd` + `slapindex`) and writes the new version.

Consequences when editing this area:

- **Cross-version contract.** The pre-upgrade code that actually runs is the one shipped in the *previous* release. Any change to `openldap-pre-upgrade/startup.sh`, `openldap-upgrade/assets/scripts/common.sh` (`extract_version`, `backup_files_prefix`), backup file naming (`OPENLDAP_UPGRADE_BACKUP_FILES_PREFIX`, `OPENLDAP_CTL_BACKUP_*_FILE_SUFFIX`) or the version file location only takes effect one release later, and `openldap-upgrade` on N must keep understanding what N-1 produced.
- `openldap-pre-upgrade` sources `/container/services/openldap-upgrade/assets/scripts/common.sh`, so that file is shared by both sides.
- Both sides must use the same `OPENLDAP_UPGRADE_MIGRATION_LEVEL` (`major|minor|patch`, default `minor`), otherwise the backup prefix will not match.
- v1 → v2 is **not** supported automatically. Only v2.x → v2.y.

## Bootstrap

Runs only when both `OPENLDAP_CONF_DIR` and `OPENLDAP_DATA_DIR` are empty (hidden files and `lost+found` ignored). It never modifies an existing database. All temporary files live in one `BOOTSTRAP_TMP_DIR` removed by an `EXIT` trap.

1. **env phase:** every `assets/scripts/NN-*.sh env <tmpfile>` appends `export VAR=...` lines (via `prepare_env_file`), which are then sourced. This is where passwords are generated/hashed and derived values computed (LDIF snippets, DN parts, upper-cased booleans for `TRUE`/`FALSE` LDAP syntax).
2. **ldif phase:** every script `ldif <source_dir> <tmp_dir>` renders `*.ldif.template` with `container envsubst templates` and copies `.ldif` files from its sub-directory (`base/`, `tls/`, `ppolicy/`, …, `custom/`) into one flat directory. Same output filename = later script wins (that is how `custom/` overrides/removes built-in fragments).
3. Files are sorted with `sort -V`, stripped of leading/trailing empty lines, and concatenated. **Prefix grouping by tens:** files in the same ten-group (`60-`…`69-`) are glued without a blank line (same LDIF entry, so they can add attributes to one entry); a group change inserts a blank line (new entry). Files without a numeric prefix are their own group.
4. Result is loaded with `slapadd -n 0` (config) then `slapadd -n 1` (data). Use plain entries, never `changetype: modify`.

Validation lives in the `env` phase and fails with `container log fatal`: `OPENLDAP_BOOTSTRAP_SUFFIX` must start with `dc=` (`00-base.sh`); replication needs 2 to 9 hosts, the current FQDN among them and a replication password without `"` (`80-replication.sh`; syncrepl `rid` is built as `<current id><provider id>1`, so ids must stay single-digit).

Adding a feature: create `services/openldap-bootstrap/assets/scripts/NN-feature.sh` guarded by `OPENLDAP_BOOTSTRAP_<FEATURE>`, source `helpers/common.sh` (and `helpers/password.sh`), call `check_args "$@"`, handle `env` and `ldif`; add templates under `ldif/config/<feature>/` and/or `ldif/data/<feature>/`; add defaults in `environment/.env.bootstrap`; document in `README.md`, `ldif/README.md` and `scripts/README.md`. Mind overlay order: `syncprov` must stay last (`180-…`).

## openldap-ctl

`/usr/bin/openldap-ctl` → `services/openldap/assets/openldap-ctl/openldap-ctl.sh`, which dispatches to `command/<name>.sh` (adding a file there adds a command).

- `backup <prefix> [--config] [--data] [--clean N] [--clean-prefix P]`: `slapcat | gzip` into `OPENLDAP_BACKUP_DIR`, written to a temp file then moved (atomic), umask 077. `--clean` only removes backup files (`*-config.gz`, `*-data.gz`) older than N days, starting with P if set; the cron uses `openldap-cron-` so manual and upgrade backups are kept.
- `restore <prefix> [--config] [--data] [--force]`: first checks the backup files exist and are valid gzip (before stopping or deleting anything), then refuses if slapd runs or dirs are not empty unless `--force` (stops/restarts slapd). Existing data is moved to `<dir>/.restore-previous` (same volume) and put back if the restore fails; a leftover `.restore-previous` (interrupted restore) blocks the next restore.
- `password generate|hash`, `schema2ldif <file.schema> [deps]`.

## Coding conventions

- Bash only. Every script starts with:
  ```bash
  #!/bin/bash

  set -euo pipefail

  # if container log level is trace:
  # print commands and their arguments as they are executed
  container log level eq trace && set -x
  ```
- Quote and brace every expansion: `"${VAR}"`. Use `${VAR:?}` before `rm -fr`.
- Log through `container log`; pipe noisy command output with `2>&1 | container log debug`. Use `container log fatal` for errors (it exits).
- Use `mktemp` + `trap ... RETURN`/`EXIT` for temp files.
- When `eval`-ing a command taken from an env var (e.g. `OPENLDAP_CTL_PASSWORD_HASH_CMD`), keep user arguments inside single quotes so they are expanded after eval: `eval "${CMD}"' -s "${password}"'`.
- Commands print a full usage line (`Usage: openldap-ctl <command> ...`) and validate their arguments before doing anything destructive.
- Env var names: `OPENLDAP_*`, then `OPENLDAP_BOOTSTRAP_*`, `OPENLDAP_CTL_*`, `OPENLDAP_UPGRADE_*`, `OPENLDAP_CRON_*`. New defaults go in the matching `environment/.env*` file **and** the README tables.
- Must pass ShellCheck (CI). Use targeted `# shellcheck disable=SCxxxx` only when needed (e.g. `SC1091` for sourced container paths).
- Container runs as non-root `ldap`: no writes outside the volumes, `/container`, `/tmp` or the dirs prepared in `services/openldap/install.sh`. Default ports are 3890/6360 (unprivileged).
- Comments and docs in English. Update `CHANGELOG.md` (project-specific changes only) for user-visible changes.

## Build, test, CI

- CI (`.github/workflows/go.yml`): golangci-lint + govulncheck on `build/`, ShellCheck on the repo, then the build pipeline (multi-arch build, tests, push, cosign signing + SBOM on tags).
- Integration tests live in `build/tests/` (Go scenarios + bash checks in `testdata/`), see `build/README.md`. Add a scenario or a check there when adding a feature. Tested combinations: modules except `dyngroup.so` (conflicts with `dynlist.so`) and `mqtt.so` (conflicts with `lastbind.so`), schemas except `msuser.ldif` (not loadable) and `nis.ldif`/`virtualMail.ldif` (conflict with `rfc2307bis.ldif`/`postfix-book.ldif`, tested separately).
- Local:
  ```bash
  shellcheck $(git ls-files '*.sh')
  cd build && go mod vendor && go run main.go job test ../Dockerfile --arches amd64
  docker build -t osixia/openldap:dev .
  docker run --rm -it osixia/openldap:dev --log-level debug   # --bash, --skip-process also useful
  ```
- When bumping OpenLDAP: `OPENLDAP_VERSION` in `Dockerfile` (Alpine package version, e.g. `2.6.15-r0`), base image in both `Dockerfile` and `build/main.go`, and `CHANGELOG.md`.
