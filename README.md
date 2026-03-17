# osixia/openldap 🐳🪪🌴

[docker hub]: https://hub.docker.com/r/osixia/openldap
[github]: https://github.com/osixia/container-openldap

[![Docker Pulls](https://img.shields.io/docker/pulls/osixia/openldap.svg?style=flat-square)][docker hub]
[![Docker Stars](https://img.shields.io/docker/stars/osixia/openldap.svg?style=flat-square)][docker hub]
[![GitHub Stars](https://img.shields.io/github/stars/osixia/container-openldap?label=github%20stars&style=flat-square)][github]
[![Contributors](https://img.shields.io/github/contributors/osixia/container-openldap?style=flat-square)](https://github.com/osixia/container-openldap/graphs/contributors)

[OpenLDAP](https://www.openldap.org/) container image with built-in bootstrap, TLS, replication, backup helpers, and upgrade support.

> ⚠️ WARNING
> **v2 is a breaking release.** Existing v1 deployments are **not** migrated automatically and require a **manual migration** to move to v2.
> Automatic upgrade paths are intended only between future v2 versions (for example, v2.x to v2.y).

110M+ pulls 🎉 Thanks to everyone using, testing, reporting issues, and contributing to this image. 🙏

![osixia/openldap logo.](./docs/assets/images/osixia-container-openldap.png)

- [osixia/openldap 🐳🪪🌴](#osixiaopenldap-)
  - [⚡ Quickstart](#-quickstart)
  - [🛟 Backup / Restore](#-backup--restore)
  - [🔐 TLS](#-tls)
  - [🔁 Replication](#-replication)
  - [🛠️ LDAP Toolkit](#️-ldap-toolkit)
    - [OpenLDAP Utilities](#openldap-utilities)
    - [Password Helpers](#password-helpers)
    - [Convert Schema to LDIF](#convert-schema-to-ldif)
  - [🔤 Environment Variables](#-environment-variables)
  - [📄 Documentation](#-documentation)
  - [🔀 Contributing](#-contributing)
  - [🔓 License](#-license)

## ⚡ Quickstart

Run a basic OpenLDAP server:

```bash
docker run --name openldap --hostname ldap.example.org -p 389:3890 -p 636:6360 \
  -e OPENLDAP_BOOTSTRAP_ORGANIZATION="Keycloakers Org" \
  -e OPENLDAP_BOOTSTRAP_SUFFIX="dc=keycloakers,dc=org" \
  osixia/openldap
```

For persistent deployments, mount config, data, and backup directories:

```bash
docker run --name openldap --hostname ldap.example.org -p 389:3890 -p 636:6360 \
  -e OPENLDAP_BOOTSTRAP_ORGANIZATION="Keycloakers Org" \
  -e OPENLDAP_BOOTSTRAP_SUFFIX="dc=keycloakers,dc=org" \
  -v openldap-conf:/etc/openldap/slapd.d \
  -v openldap-data:/var/lib/openldap/openldap-data \
  -v openldap-backups:/var/lib/openldap/openldap-backups \
  osixia/openldap
```

Notes:
- Default internal listener ports are `3890` (LDAP) and `6360` (LDAPS), as defined by `OPENLDAP_URLS`.
- On first start, passwords are generated if hashed values are empty and printed in logs.
- Bootstrap runs only when config/data are empty.

**Verify the server is up**

Retrieve the generated admin password from the container logs:

``` bash
docker logs openldap 2>&1 | grep -i password
```

Then search the base DN to confirm the server is responding:

``` bash
docker exec openldap container run -- \
  ldapsearch -H ldap://localhost:3890 \
  -D "cn=admin,dc=keycloakers,dc=org" -w <database root password> \
  -b "dc=keycloakers,dc=org" "(objectClass=*)"
```

A successful response returns the organization entry and the `cn=admin` account.

**Passing command-line arguments to OpenLDAP**

The `osixia/openldap` container allows you to pass additional command-line arguments directly to the OpenLDAP binary.

Arguments specified after `--` are forwarded to the slapd process inside the container:

``` bash
docker run osixia/openldap -- -d -1
```

**Debugging**

To debug the container manually, you can start it with an interactive shell.

The `--log-level debug --bash` options from `osixia/baseimage` enables debug logging and launches an interactive shell.

If OpenLDAP keeps crashing, you can add `--skip-process` to start the container without launching service processes.

``` bash
docker run -it osixia/openldap --log-level debug --bash
docker run -it osixia/openldap --skip-process --log-level debug --bash
```

You can also increase the OpenLDAP daemon (`slapd`) log level with `OPENLDAP_DEBUG_LEVEL`:
``` bash
docker run -e OPENLDAP_DEBUG_LEVEL=-1 osixia/openldap
```

> `OPENLDAP_DEBUG_LEVEL` only affects OpenLDAP (`slapd`) logging. To increase container/runtime logs, use the baseimage flag `--log-level` (for example `--log-level debug`).

To see all available command-line options:
``` bash
docker run --rm osixia/openldap --help # osixia/baseimage options
docker run --rm osixia/openldap -x openldap -- --help # slapd command-line options
```

## 🛟 Backup / Restore

The image includes the `openldap-ctl` helper with `backup` and `restore` commands.

Create a full backup:

```bash
docker exec openldap container run -- openldap-ctl backup my-backup
```

Create only a data backup and remove files older than 15 days:

```bash
docker exec openldap container run -- openldap-ctl backup my-backup --data --clean 15
```

This creates files in `OPENLDAP_BACKUP_DIR`:

- `my-backup-config.gz`
- `my-backup-data.gz`

Restore a backup:

``` bash
docker exec openldap container run -- openldap-ctl restore my-backup --force
```

`--force` stops the OpenLDAP process if needed, deletes existing data in the target directories, restores the selected databases, then starts OpenLDAP again.

You can also run a cron service to automatically perform regular backups:

``` bash
docker run --name openldap-cron \
  -u root \
  -v openldap-conf:/etc/openldap/slapd.d \
  -v openldap-data:/var/lib/openldap/openldap-data \
  -v openldap-backups:/var/lib/openldap/openldap-backups \
  osixia/openldap -x openldap-cron
```

See the `OPENLDAP_CRON_JOB` environment variable to adjust the cron schedule and behavior.

## 🔐 TLS

Set `OPENLDAP_BOOTSTRAP_TLS=true` to configure TLS during bootstrap.

The default certificate paths are:

- `/container/services/openldap/assets/certs/cert.crt`
- `/container/services/openldap/assets/certs/cert.key`
- `/container/services/openldap/assets/certs/ca.crt`

The simplest way is to mount a directory that contains files with exactly those names:

```bash
docker run --name openldap --hostname ldap.example.org -p 389:3890 -p 636:6360 \
  -e OPENLDAP_BOOTSTRAP_TLS=true \
  -v $PWD/certs:/container/services/openldap/assets/certs \
  osixia/openldap
```

If you also set `OPENLDAP_BOOTSTRAP_TLS_REQUIRED=true`, bootstrap adds TLS-required access rules. That setting is stricter than plain TLS enablement and is intended for deployments where non-TLS client access should be rejected.

## 🔁 Replication

Set `OPENLDAP_BOOTSTRAP_REPLICATION=true` to bootstrap syncrepl replication.

`OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS` must contain at least two hosts, in the same order on every server. The current node FQDN must match one of them.

When replication is enabled, set `OPENLDAP_URLS` with the node hostname in LDAP/LDAPS URLs (for example `ldap://ldap1.example.org:3890 ldaps://ldap1.example.org:6360 ldapi:///`) so advertised endpoints match replication hosts.

For a local Docker setup, put both containers on the same user-defined network so each host can resolve the other one:

```bash
docker network create openldap-net
```

Minimal example for `ldap1.example.org`:

```bash
docker run --name ldap1 --network openldap-net --hostname ldap1.example.org \
  -e OPENLDAP_URLS="ldap://ldap1.example.org:3890 ldaps://ldap1.example.org:6360 ldapi:///" \
  -e OPENLDAP_BOOTSTRAP_ORGANIZATION="Keycloakers Org" \
  -e OPENLDAP_BOOTSTRAP_SUFFIX="dc=keycloakers,dc=org" \
  -e OPENLDAP_BOOTSTRAP_REPLICATION=true \
  -e OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS="ldap://ldap1.example.org:3890 ldap://ldap2.example.org:3890" \
  -e OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD="passw0rd" \
  osixia/openldap
```

Minimal example for `ldap2.example.org`:

```bash
docker run --name ldap2 --network openldap-net --hostname ldap2.example.org \
  -e OPENLDAP_URLS="ldap://ldap2.example.org:3890 ldaps://ldap2.example.org:6360 ldapi:///" \
  -e OPENLDAP_BOOTSTRAP_ORGANIZATION="Keycloakers Org" \
  -e OPENLDAP_BOOTSTRAP_SUFFIX="dc=keycloakers,dc=org" \
  -e OPENLDAP_BOOTSTRAP_REPLICATION=true \
  -e OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS="ldap://ldap1.example.org:3890 ldap://ldap2.example.org:3890" \
  -e OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD="passw0rd" \
  osixia/openldap
```

If TLS is required for replication, set `OPENLDAP_BOOTSTRAP_REPLICATION_TLS=true` or rely on its default value from `OPENLDAP_BOOTSTRAP_TLS_REQUIRED`.

## 🛠️ LDAP Toolkit

### OpenLDAP Utilities

This image ships with the full suite of OpenLDAP utilities — both server-side database tools and LDAP client tools.

**Database tools**

`slapcat`, `slapadd`, `slapindex`, and `slaptest` operate directly on the local database files and must run inside the container.

Export the data database to LDIF:

``` bash
docker exec openldap container run -- slapcat -n 1
```

Export the config database (`cn=config`):

``` bash
docker exec openldap container run -- slapcat -n 0
```

> **Note:** `slapadd` and `slapindex` require OpenLDAP to be stopped first. Use `docker exec openldap container processes stop openldap` to stop OpenLDAP and `docker exec openldap container processes start openldap` to restart OpenLDAP.

**LDAP client tools**

`ldapsearch`, `ldapwhoami`, `ldapadd`, `ldapmodify`, `ldapdelete`, and `ldappasswd` connect to any LDAP server over the network.

Search for all entries under a base DN:

``` bash
docker run --rm osixia/openldap run -- \
  ldapsearch -H ldap://172.16.0.1 \
  -D "cn=admin,dc=example,dc=org" -w passw0rd \
  -b "dc=example,dc=org" "(objectClass=*)"
```

Verify bind credentials:

``` bash
docker run --rm osixia/openldap run -- \
  ldapwhoami -H ldap://172.16.0.1 \
  -D "cn=admin,dc=example,dc=org" -w passw0rd
```

Add entries from a local LDIF file:

``` bash
docker run --rm -v /path/to/entries.ldif:/tmp/entries.ldif \
  osixia/openldap run -- \
  ldapadd -H ldap://172.16.0.1 \
  -D "cn=admin,dc=example,dc=org" -w passw0rd \
  -f /tmp/entries.ldif
```

Change a user's password:

``` bash
docker run --rm osixia/openldap run -- \
  ldappasswd -H ldap://172.16.0.1 \
  -D "cn=admin,dc=example,dc=org" -w passw0rd \
  -s newpassword "uid=jdoe,ou=people,dc=example,dc=org"
```

### Password Helpers

Generate a random password:

``` bash
docker run --rm osixia/openldap run -- openldap-ctl password generate
```

Hash a password:

``` bash
docker run --rm osixia/openldap run -- openldap-ctl password hash passw0rd
```

### Convert Schema to LDIF

``` bash
docker run --rm -v schema:/data \
  osixia/openldap run -- openldap-ctl schema2ldif /data/test.schema
```

## 🔤 Environment Variables

**Core**

| Variable                      | Description                                           | Default                                      |
| ----------------------------- | ----------------------------------------------------- | -------------------------------------------- |
| `OPENLDAP_CONF_DIR`           | OpenLDAP configuration directory (`slapd.d`)          | `/etc/openldap/slapd.d`                      |
| `OPENLDAP_DATA_DIR`           | OpenLDAP data directory                               | `/var/lib/openldap/openldap-data`            |
| `OPENLDAP_BACKUP_DIR`         | Backup directory used by `openldap-ctl backup`        | `/var/lib/openldap/openldap-backups`         |
| `OPENLDAP_MODULES_DIR`        | Directory used by OpenLDAP dynamic modules            | `/usr/lib/openldap`                          |
| `OPENLDAP_SCHEMAS_DIR`        | Directory containing LDIF schemas loaded at bootstrap | `/etc/openldap/schema`                       |
| `OPENLDAP_CUSTOM_MODULES_DIR` | Custom modules copied at startup                      | `/container/services/openldap/assets/module` |
| `OPENLDAP_CUSTOM_SCHEMAS_DIR` | Custom schemas copied at startup                      | `/container/services/openldap/assets/schema` |
| `OPENLDAP_NOFILE`             | `ulimit -n` value before starting `slapd`             | `65536`                                      |
| `OPENLDAP_DEBUG_LEVEL`        | Default `slapd` debug level                           | `256`                                        |
| `OPENLDAP_URLS`               | Listener URLs passed to `slapd -h`                    | `ldap://:3890 ldaps://:6360 ldapi:///`      |

**Bootstrap**

| Variable                                              | Description                                                                       | Default                                                     |
| ----------------------------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `OPENLDAP_BOOTSTRAP_ORGANIZATION`                     | Organization name used in bootstrap data                                          | `Example Org`                                               |
| `OPENLDAP_BOOTSTRAP_SUFFIX`                           | Base LDAP suffix                                                                  | `dc=example,dc=org`                                         |
| `OPENLDAP_BOOTSTRAP_MODULES`                          | OpenLDAP modules loaded during bootstrap                                          | `back_mdb.so argon2.so refint.so ppolicy.so unique.so memberof.so syncprov.so` |
| `OPENLDAP_BOOTSTRAP_SCHEMAS`                          | LDIF schemas imported during bootstrap                                            | `core.ldif cosine.ldif inetorgperson.ldif rfc2307bis.ldif`  |
| `OPENLDAP_BOOTSTRAP_GLOBAL_SIZE_LIMIT`                         | Global LDAP size limit                                                            | `500`                                                       |
| `OPENLDAP_BOOTSTRAP_GLOBAL_TIME_LIMIT`                         | Global LDAP time limit                                                            | `120`                                                       |
| `OPENLDAP_BOOTSTRAP_GLOBAL_IDLE_TIMEOUT`                       | Global LDAP idle timeout                                                          | `3600`                                                      |
| `OPENLDAP_BOOTSTRAP_CONFIG_PASSWORD_HASH`                      | Password hash scheme configured in `olcPasswordHash`                              | `{ARGON2}`                                                  |
| `OPENLDAP_BOOTSTRAP_CONFIG_ROOT_DN`                   | Root DN for `cn=config`                                                           | `cn=admin,cn=config`                                        |
| `OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED`      | Hashed password for `cn=config`; generated if empty                               | ``                                                          |
| `OPENLDAP_BOOTSTRAP_DATA_DATABASE_MAX_SIZE`           | MDB max size for main database                                                    | `10737418240`                                               |
| `OPENLDAP_BOOTSTRAP_DATA_ROOT_DN`                     | Root DN for main database                                                         | `cn=admin,${OPENLDAP_BOOTSTRAP_SUFFIX}`                     |
| `OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED`        | Hashed password for main database root DN; generated if empty                     | ``                                                          |
| `OPENLDAP_BOOTSTRAP_DATA_READONLY`                    | Enable read-only data account creation                                            | `false`                                                     |
| `OPENLDAP_BOOTSTRAP_DATA_READONLY_DN`                 | DN of the read-only data account                                                  | `cn=readonly,${OPENLDAP_BOOTSTRAP_SUFFIX}`                  |
| `OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED`    | Hashed password of the read-only data account; generated if empty when enabled    | ``                                                          |
| `OPENLDAP_BOOTSTRAP_MONITOR_ENABLED`                  | Enable monitor backend                                                            | `false`                                                     |
| `OPENLDAP_BOOTSTRAP_MONITOR_READONLY`                 | Enable read-only monitor account creation                                         | `false`                                                     |
| `OPENLDAP_BOOTSTRAP_MONITOR_READONLY_DN`              | DN of the read-only monitor account                                               | `cn=readonly-monitor,${OPENLDAP_BOOTSTRAP_SUFFIX}`          |
| `OPENLDAP_BOOTSTRAP_MONITOR_READONLY_PASSWORD_HASHED` | Hashed password of the read-only monitor account; generated if empty when enabled | ``                                                          |
| `OPENLDAP_BOOTSTRAP_LDIF_CONFIG_DIR`                  | Source directory for config LDIF bootstrap files                                  | `/container/services/openldap-bootstrap/assets/ldif/config` |
| `OPENLDAP_BOOTSTRAP_LDIF_DATA_DIR`                    | Source directory for data LDIF bootstrap files                                    | `/container/services/openldap-bootstrap/assets/ldif/data`   |
| `OPENLDAP_BOOTSTRAP_SCRIPTS_DIR`                      | Source directory for bootstrap scripts                                            | `/container/services/openldap-bootstrap/assets/scripts`     |

**TLS**

| Variable                               | Description                                    | Default                                              |
| -------------------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| `OPENLDAP_BOOTSTRAP_TLS`               | Enable TLS configuration during bootstrap      | `false`                                              |
| `OPENLDAP_BOOTSTRAP_TLS_CERT`          | Server certificate path                        | `/container/services/openldap/assets/certs/cert.crt` |
| `OPENLDAP_BOOTSTRAP_TLS_CERT_KEY`      | Server private key path                        | `/container/services/openldap/assets/certs/cert.key` |
| `OPENLDAP_BOOTSTRAP_TLS_CA_CERT`       | CA certificate path                            | `/container/services/openldap/assets/certs/ca.crt`   |
| `OPENLDAP_BOOTSTRAP_TLS_VERIFY_CLIENT` | Value for `olcTLSVerifyClient`                 | `allow`                                              |
| `OPENLDAP_BOOTSTRAP_TLS_PROTOCOL_MIN`  | Value for `olcTLSProtocolMin`                  | `3.4`                                                |
| `OPENLDAP_BOOTSTRAP_TLS_REQUIRED`      | Enforce TLS-only access rules during bootstrap | `false`                                              |

**RefInt**

| Variable                               | Description                                   | Default                             |
| -------------------------------------- | --------------------------------------------- | ----------------------------------- |
| `OPENLDAP_BOOTSTRAP_REFINT`            | Enable the `refint` overlay during bootstrap  | `false`                             |
| `OPENLDAP_BOOTSTRAP_REFINT_ATTRIBUTES` | Attributes maintained by the `refint` overlay | `member uniqueMember manager owner` |

**PPolicy**

| Variable                                                    | Description                                             | Default                                            |
| ----------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------- |
| `OPENLDAP_BOOTSTRAP_PPOLICY`                                | Enable the password policy overlay during bootstrap     | `false`                                            |
| `OPENLDAP_BOOTSTRAP_PPOLICY_HASH_CLEAR_TEXT`                | Value for `olcPPolicyHashCleartext`                     | `true`                                             |
| `OPENLDAP_BOOTSTRAP_PPOLICY_USE_LOCKOUT`                    | Value for `olcPPolicyUseLockout`                        | `true`                                             |
| `OPENLDAP_BOOTSTRAP_PPOLICY_CHECK_MODULE`                   | Optional value for `olcPPolicyCheckModule`              | ``                                                 |
| `OPENLDAP_BOOTSTRAP_PPOLICY_GROUP_DN`                       | DN of the policy container created in the main database | `ou=Policies,${OPENLDAP_BOOTSTRAP_SUFFIX}`         |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_POLICY_DN`              | DN of the default password policy                       | `cn=default,${OPENLDAP_BOOTSTRAP_PPOLICY_GROUP_DN}` |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MIN_LENGTH`             | Value for `pwdMinLength`                                | `12`                                               |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_CHECK_QUALITY`          | Value for `pwdCheckQuality`                             | `0`                                                |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_IN_HISTORY`             | Value for `pwdInHistory`                                | `12`                                               |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_ALLOW_USER_CHANGE`      | Value for `pwdAllowUserChange`                          | `true`                                             |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_SAFE_MODIFY`            | Value for `pwdSafeModify`                               | `true`                                             |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MUST_CHANGE`            | Value for `pwdMustChange`                               | `false`                                            |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MIN_AGE`                | Value for `pwdMinAge`                                   | `0`                                                |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_FAILURE`            | Value for `pwdMaxFailure`                               | `5`                                                |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_FAILURE_COUNT_INTERVAL` | Value for `pwdFailureCountInterval`                     | `300`                                              |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_LOCKOUT`                | Value for `pwdLockout`                                  | `true`                                             |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_LOCKOUT_DURATION`       | Value for `pwdLockoutDuration`                          | `900`                                              |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_MAX_AGE`                | Value for `pwdMaxAge`                                   | `7776000`                                          |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_EXPIRE_WARNING`         | Value for `pwdExpireWarning`                            | `1209600`                                          |
| `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_GRACE_AUTH_NLIMIT`      | Value for `pwdGraceAuthNLimit`                          | `3`                                                |

**Unique**

| Variable                         | Description                                   | Default                              |
| -------------------------------- | --------------------------------------------- | ------------------------------------ |
| `OPENLDAP_BOOTSTRAP_UNIQUE`      | Enable the `unique` overlay during bootstrap  | `false`                              |
| `OPENLDAP_BOOTSTRAP_UNIQUE_URIS` | URIs enforced by the `unique` overlay         | `ldap:///?uid?sub ldap:///?mail?sub` |

**MemberOf**

| Variable                                  | Description                                           | Default        |
| ----------------------------------------- | ----------------------------------------------------- | -------------- |
| `OPENLDAP_BOOTSTRAP_MEMBEROF`             | Enable the `memberof` overlay during bootstrap        | `false`        |
| `OPENLDAP_BOOTSTRAP_MEMBEROF_GROUP_OC`    | ObjectClass treated as a group by `memberof`          | `groupOfNames` |
| `OPENLDAP_BOOTSTRAP_MEMBEROF_MEMBER_AD`   | Group membership attribute watched by `memberof`      | `member`       |
| `OPENLDAP_BOOTSTRAP_MEMBEROF_MEMBEROF_AD` | Reverse membership attribute maintained by `memberof` | `memberOf`     |
| `OPENLDAP_BOOTSTRAP_MEMBEROF_ADD_CHECK`   | Check new entries against existing groups on Add      | `true`         |
| `OPENLDAP_BOOTSTRAP_MEMBEROF_DANGLING`    | Handling of group members that do not exist yet       | `ignore`       |

**Replication**

| Variable                                                   | Description                                                                | Default                                                               |
| ---------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `OPENLDAP_BOOTSTRAP_REPLICATION`                           | Enable replication bootstrap                                               | `false`                                                               |
| `OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS`                     | Replication endpoints list; at least two, same order on every server       | `ldap://ldap1.example.org:3890 ldap://ldap2.example.org:3890`         |
| `OPENLDAP_BOOTSTRAP_REPLICATION_SYNCPROV_CHECKPOINT`       | `syncprov` checkpoint configuration                                        | `100 10`                                                              |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_DN`          | Replication account DN for the main database                               | `cn=data-replicator,${OPENLDAP_BOOTSTRAP_SUFFIX}`                     |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD`    | Plain password for the data replication account; generated if empty        | ``                                                                    |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_TEMPLATE`   | Template used to generate data `olcSyncRepl`                               | `rid=\${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_RID} ...`       |
| `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_LIMITS`               | Limits ACL for the data replication account                                | `dn.exact="${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_DN}" ...`   |
| `OPENLDAP_BOOTSTRAP_REPLICATION_TLS`                       | Enable TLS settings in generated replication config                        | `${OPENLDAP_BOOTSTRAP_TLS_REQUIRED}`                                  |
| `OPENLDAP_BOOTSTRAP_REPLICATION_TLS_SYNC_REPL`             | Extra `syncrepl` TLS options                                               | `starttls=critical tls_reqcert=demand`                                |
| `OPENLDAP_BOOTSTRAP_REPLICATION_MEMBEROF`                  | Enable memberof settings in generated replication config               | `${OPENLDAP_BOOTSTRAP_MEMBEROF}`                                      |
| `OPENLDAP_BOOTSTRAP_REPLICATION_MEMBEROF_SYNC_REPL`        | Extra `syncrepl` option used when `memberof` replication handling is enabled | `exattrs=${OPENLDAP_BOOTSTRAP_MEMBEROF_MEMBEROF_AD}`                  |

**Helpers and Maintenance**

| Variable                                 | Description                                                 | Default                                                                                                                                                                          |
| ---------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OPENLDAP_CTL_BACKUP_CONFIG_FILE_SUFFIX` | Suffix used for config backups                              | `-config.gz`                                                                                                                                                                     |
| `OPENLDAP_CTL_BACKUP_DATA_FILE_SUFFIX`   | Suffix used for data backups                                | `-data.gz`                                                                                                                                                                       |
| `OPENLDAP_CTL_PASSWORD_GENERATE_CMD`     | Command used by `openldap-ctl password generate`            | `slappasswd -n -g; slappasswd -g`                                                                                                                                                |
| `OPENLDAP_CTL_PASSWORD_HASH_CMD`         | Command used by `openldap-ctl password hash`                | `slappasswd -h {ARGON2} -o module-path=${OPENLDAP_MODULES_DIR} -o module-load=argon2`                                                                                            |
| `OPENLDAP_CTL_SCHEMA2LDIF_DEPENDENCIES`  | Default schema dependencies for `schema2ldif`               | `core.schema cosine.schema inetorgperson.schema`                                                                                                                                 |
| `OPENLDAP_CRON_JOB`                      | Cron job used by the backup service                         | `15 2 * * * PATH=${PATH} container run -- openldap-ctl backup "$(date -I)-${OPENLDAP_VERSION}-openldap-cron" --clean 15` |
| `OPENLDAP_UPGRADE_FORCE`                 | Allow upgrade bypasses, including forced downgrade handling | `false`                                                                                                                                                                          |
| `OPENLDAP_UPGRADE_MIGRATION_LEVEL`       | Allowed migration level                                     | `minor`                                                                                                                                                                          |
| `OPENLDAP_UPGRADE_BACKUP_FILES_PREFIX`   | Prefix for upgrade backup files                             | `openldap-upgrade`                                                                                                                                                               |
| `OPENLDAP_UPGRADE_CONF_VERSION_FILE`     | File storing the current config version                     | `${OPENLDAP_CONF_DIR}/.version`                                                                                                                                                  |

## 📄 Documentation

See full documentation and complete features list on [osixia/openldap documentation](https://opensource.osixia.net/projects/container-images/openldap/).

This image is based on [osixia/baseimage](https://github.com/osixia/container-baseimage).

## 🔀 Contributing

If you find this project useful here's how you can help:

- Send a pull request with new features and bug fixes.
- Help new users with [issues](https://github.com/osixia/container-openldap/issues) they may encounter.
- Support the development of this image and star [this repo][github] and the image [docker hub repository][docker hub].

This project uses a CI/CD tool to build, test, and deploy images. See the source code and useful command lines in [build directory](build/).

## 🔓 License

This project is licensed under the terms of the MIT license. See [LICENSE.md](LICENSE.md) file for more information.
