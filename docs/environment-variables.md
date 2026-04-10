# Environment Variables

This document describes all environment variables available to configure the OpenLDAP container. Variables are grouped by the `.env` file in which they are defined under `environment/`.

## Table of Contents

- [Core (`environment/.env`)](#core-environmentenv)
- [Bootstrap (`environment/.env.bootstrap`)](#bootstrap-environmentenvbootstrap)
  - [General](#general)
  - [Config database (`cn=config`)](#config-database-cnconfig)
  - [Data database](#data-database)
  - [Readonly account](#readonly-account)
  - [Monitor backend](#monitor-backend)
  - [TLS](#tls)
  - [Replication](#replication)
  - [Paths](#paths)
- [Cron (`environment/.env.cron`)](#cron-environmentenvcron)
- [Control tool (`environment/.env.ctl`)](#control-tool-environmentenvctl)
- [Upgrade (`environment/.env.upgrade`)](#upgrade-environmentenvupgrade)

---

## Core (`environment/.env`)

These variables define the fundamental runtime paths and behaviour of the `slapd` process.

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_CONF_DIR` | `/etc/openldap/slapd.d` | Path to the OpenLDAP runtime configuration directory (`slapd.d`). |
| `OPENLDAP_DATA_DIR` | `/var/lib/openldap/openldap-data` | Path to the MDB data directory. |
| `OPENLDAP_BACKUP_DIR` | `/var/lib/openldap/openldap-backups` | Directory where backup archives are stored. |
| `OPENLDAP_MODULES_DIR` | `/usr/lib/openldap` | Directory from which `slapd` loads overlay and backend modules. Custom modules placed in `OPENLDAP_CUSTOM_MODULES_DIR` are copied here at startup. |
| `OPENLDAP_SCHEMAS_DIR` | `/etc/openldap/schema` | Directory from which `slapd` reads schema files. Custom schemas placed in `OPENLDAP_CUSTOM_SCHEMAS_DIR` are copied here at startup. |
| `OPENLDAP_CUSTOM_MODULES_DIR` | `/container/services/openldap/assets/module` | Mount point for user-supplied module files (`.so`). Contents are copied into `OPENLDAP_MODULES_DIR` at startup. |
| `OPENLDAP_CUSTOM_SCHEMAS_DIR` | `/container/services/openldap/assets/schema` | Mount point for user-supplied schema files. Contents are copied into `OPENLDAP_SCHEMAS_DIR` at startup. |
| `OPENLDAP_NOFILE` | `65536` | Maximum number of open file descriptors (`ulimit -n`) for the `slapd` process. |
| `OPENLDAP_DEBUG_LEVEL` | `256` | `slapd` debug level bitmask passed via `-d`. `256` enables stats logging. Set to `0` to disable or `-1` for maximum verbosity. See the [slapd(8) man page](https://www.openldap.org/software/man.cgi?query=slapd) for all values. |

---

## Bootstrap (`environment/.env.bootstrap`)

These variables control the **first-time initialisation** of the OpenLDAP instance (organisation, credentials, modules, schemas, TLS, replication). They are consumed by the `openldap-bootstrap` service scripts.

### General

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_ORGANIZATION` | `Example Org` | Human-readable organisation name written to the root entry (`o` attribute). |
| `OPENLDAP_BOOTSTRAP_SUFFIX` | `dc=example,dc=org` | Base DN (suffix) of the main data directory. All data entries are created under this DN. |
| `OPENLDAP_BOOTSTRAP_MODULES` | `back_mdb.so argon2.so ppolicy.so refint.so syncprov.so` | Space-separated list of module filenames to load into `slapd`. Each entry becomes an `olcModuleload` directive. |
| `OPENLDAP_BOOTSTRAP_SCHEMAS` | `core.ldif cosine.ldif inetorgperson.ldif rfc2307bis.ldif` | Space-separated list of schema LDIF files (relative to `OPENLDAP_SCHEMAS_DIR`) to include during bootstrap. |

### Config database (`cn=config`)

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_CONFIG_ROOT_DN` | `cn=admin,cn=config` | DN of the administrative account for the `cn=config` database. |
| `OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED` | *(empty — auto-generated)* | Pre-hashed password for `OPENLDAP_BOOTSTRAP_CONFIG_ROOT_DN`. Leave empty to have the bootstrap script generate and hash a random password automatically. Must be a valid `slappasswd`-compatible hash (e.g. `{ARGON2}...`). |

### Data database

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_DATA_DATABASE_MAX_SIZE` | `1073741824` | Maximum size of the MDB data database in bytes (default: 1 GiB). Maps to the `olcDbMaxSize` attribute. |
| `OPENLDAP_BOOTSTRAP_DATA_ROOT_DN` | `cn=admin,${OPENLDAP_BOOTSTRAP_SUFFIX}` | DN of the administrative account for the main data database. |
| `OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED` | *(empty — auto-generated)* | Pre-hashed password for `OPENLDAP_BOOTSTRAP_DATA_ROOT_DN`. Leave empty to auto-generate. |

### Readonly account

An optional unprivileged account with read-only access to the data database, suitable for application binds.

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_DATA_READONLY` | `false` | Set to `true` to create the readonly account during bootstrap. |
| `OPENLDAP_BOOTSTRAP_DATA_READONLY_DN` | `cn=readonly,${OPENLDAP_BOOTSTRAP_SUFFIX}` | DN of the readonly account. |
| `OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED` | *(empty — auto-generated)* | Pre-hashed password for the readonly account. Leave empty to auto-generate. |

### Monitor backend

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_MONITOR_ENABLED` | `false` | Set to `true` to enable the `monitor` backend (`cn=Monitor`). |
| `OPENLDAP_BOOTSTRAP_MONITOR_READONLY` | `false` | Set to `true` to create a dedicated readonly account for the monitor backend. Requires `OPENLDAP_BOOTSTRAP_MONITOR_ENABLED=true`. |
| `OPENLDAP_BOOTSTRAP_MONITOR_READONLY_DN` | `cn=readonly-monitor,${OPENLDAP_BOOTSTRAP_SUFFIX}` | DN of the monitor readonly account. |
| `OPENLDAP_BOOTSTRAP_MONITOR_READONLY_PASSWORD_HASHED` | *(empty — auto-generated)* | Pre-hashed password for the monitor readonly account. Leave empty to auto-generate. |

### TLS

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_TLS` | `false` | Set to `true` to enable TLS/LDAPS. |
| `OPENLDAP_BOOTSTRAP_TLS_CERT` | `/container/services/openldap/assets/certs/cert.crt` | Path to the PEM-encoded server certificate. |
| `OPENLDAP_BOOTSTRAP_TLS_CERT_KEY` | `/container/services/openldap/assets/certs/cert.key` | Path to the PEM-encoded private key for the server certificate. |
| `OPENLDAP_BOOTSTRAP_TLS_CA_CERT` | `/container/services/openldap/assets/certs/ca.crt` | Path to the PEM-encoded CA certificate used to verify client certificates. |
| `OPENLDAP_BOOTSTRAP_TLS_VERIFY_CLIENT` | `allow` | Client certificate verification policy. Accepted values: `none`, `allow`, `try`, `demand`. Maps to `olcTLSVerifyClient`. |
| `OPENLDAP_BOOTSTRAP_TLS_PROTOCOL_MIN` | `3.3` | Minimum TLS protocol version. `3.3` = TLS 1.2, `3.4` = TLS 1.3. Maps to `olcTLSProtocolMin`. |
| `OPENLDAP_BOOTSTRAP_TLS_REQUIRED` | `false` | Set to `true` to reject plain-text connections (StartTLS / LDAPS only). Also used as the default value for `OPENLDAP_BOOTSTRAP_REPLICATION_TLS`. |

### Replication

Multi-master replication using the `syncprov` overlay. Exactly **two hosts** are required; both must list the hosts in the same order.

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_REPLICATION` | `false` | Set to `true` to enable multi-master replication during bootstrap. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS` | `ldap://ldap1.example.org:3890 ldap://ldap2.example.org:3890` | Space-separated list of LDAP URIs for all replication peers (including the current host). The order must be identical on every node. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_SYNCPROV_CHECKPOINT` | `100 10` | `syncprov` checkpoint expressed as `<ops> <minutes>`. A checkpoint is written after every `<ops>` operations **or** every `<minutes>` minutes, whichever comes first. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_DN` | `cn=config-replicator,${OPENLDAP_BOOTSTRAP_SUFFIX}` | DN of the service account used to replicate the `cn=config` database. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD` | *(empty — auto-generated)* | Plain-text password for the config replication account. Leave empty to auto-generate a random password. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL_TEMPLATE` | *(see `.env.bootstrap`)* | Template string used to generate the `syncrepl` directive for the `cn=config` database. Supports variable interpolation via `container envsubst`. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_LIMITS` | *(see `.env.bootstrap`)* | `olcLimits` value granting unlimited size/time to the config replication account. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_DN` | `cn=data-replicator,${OPENLDAP_BOOTSTRAP_SUFFIX}` | DN of the service account used to replicate the main data database. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD` | *(empty — auto-generated)* | Plain-text password for the data replication account. Leave empty to auto-generate. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_TEMPLATE` | *(see `.env.bootstrap`)* | Template string used to generate the `syncrepl` directive for the data database. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_LIMITS` | *(see `.env.bootstrap`)* | `olcLimits` value granting unlimited size/time to the data replication account. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_TLS` | `${OPENLDAP_BOOTSTRAP_TLS_REQUIRED}` | Set to `true` to append TLS options to every `syncrepl` directive. Defaults to the value of `OPENLDAP_BOOTSTRAP_TLS_REQUIRED`. |
| `OPENLDAP_BOOTSTRAP_REPLICATION_TLS_SYNC_REPL` | `starttls=critical tls_reqcert=demand` | TLS fragment appended to each `syncrepl` directive when `OPENLDAP_BOOTSTRAP_REPLICATION_TLS=true`. |

### Paths

Internal paths used by bootstrap scripts. Override only if you remap container directories.

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_BOOTSTRAP_LDIF_CONFIG_DIR` | `/container/services/openldap-bootstrap/assets/ldif/config` | Directory containing LDIF template files applied to the `cn=config` database during bootstrap. |
| `OPENLDAP_BOOTSTRAP_LDIF_DATA_DIR` | `/container/services/openldap-bootstrap/assets/ldif/data` | Directory containing LDIF template files applied to the data database during bootstrap. |
| `OPENLDAP_BOOTSTRAP_SCRIPTS_DIR` | `/container/services/openldap-bootstrap/assets/scripts` | Directory containing the bootstrap helper scripts. |

---

## Cron (`environment/.env.cron`)

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_CRON_JOB` | `15 2 * * * …` | Full cron entry written to `/etc/crontabs/ldap`. The default schedules a daily backup at 02:15, retaining the last 15 days. The environment is re-sourced from `/run/container/environment.sh` before the command runs so that all container variables are available to the cron context. |

---

## Control tool (`environment/.env.ctl`)

Variables used by the `openldap-ctl` utility (backup, restore, password management, schema conversion).

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_CTL_BACKUP_CONFIG_FILE_SUFFIX` | `-config.gz` | Filename suffix appended to the file prefix when creating a config database backup archive. |
| `OPENLDAP_CTL_BACKUP_DATA_FILE_SUFFIX` | `-data.gz` | Filename suffix appended to the file prefix when creating a data database backup archive. |
| `OPENLDAP_CTL_PASSWORD_GENERATE_CMD` | `slappasswd -n -g; slappasswd -g` | Shell command used to generate a new random password. The first invocation produces the raw secret, the second a hashed form. |
| `OPENLDAP_CTL_PASSWORD_HASH_CMD` | `slappasswd -h {ARGON2} -o module-path=… -o module-load=argon2` | Shell command used to hash a plain-text password using the Argon2 algorithm. The `argon2` module from `OPENLDAP_MODULES_DIR` is loaded inline. |
| `OPENLDAP_CTL_SCHEMA2LDIF_DEPENDENCIES` | `core.schema cosine.schema inetorgperson.schema` | Space-separated list of schema files that must be pre-loaded before converting a custom `.schema` file to LDIF format with the `schema2ldif` subcommand. |

---

## Upgrade (`environment/.env.upgrade`)

Variables that control the automatic migration logic run by the `openldap-upgrade` service on every container start.

| Variable | Default | Description |
|---|---|---|
| `OPENLDAP_UPGRADE_FORCE` | `false` | Set to `true` to bypass safety guards: allows downgrades and skips the pre-upgrade backup check. Use with caution. |
| `OPENLDAP_UPGRADE_MIGRATION_LEVEL` | `minor` | Granularity at which version numbers are compared to decide whether a migration is needed. Accepted values: `patch` (e.g. `2.6.9` → `2.6.10`), `minor` (e.g. `2.5` → `2.6`), `major` (e.g. `2` → `3`). |
| `OPENLDAP_UPGRADE_BACKUP_FILES_PREFIX` | `openldap-upgrade` | Prefix used to locate the pre-upgrade backup archives in `OPENLDAP_BACKUP_DIR`. The service expects files named `<prefix>-<version><suffix>` to exist before performing a restore. |
| `OPENLDAP_UPGRADE_CONF_VERSION_FILE` | `${OPENLDAP_CONF_DIR}/.version` | File that records the OpenLDAP version that last wrote the configuration. Read on startup to detect version changes; updated after a successful migration. |
