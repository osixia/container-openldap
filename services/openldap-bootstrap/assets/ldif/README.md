# LDIF Templates

This directory contains LDAP Data Interchange Format (LDIF) files used to bootstrap the OpenLDAP configuration and data during container initialization.

Files with a `.template` extension use `${VARIABLE}` placeholders that are substituted with environment variables at runtime. Static `.ldif` files are applied as-is.

Rendered LDIF files are assembled in version-sort order (`sort -V`); numerical prefixes control ordering.

Conditional templates use `.ldif.optional.template`. They render to `.ldif.optional`
in the temporary output directory. The owning feature script activates them with
`mv` to `.ldif` when needed; final assembly ignores files still ending in `.optional`.
Sources stay unchanged, including on read-only volumes.

## Structure

```
ldif/
├── config/          # OpenLDAP configuration database (cn=config)
│   ├── base/                  # Core configuration (always applied)
│   ├── tls/                   # TLS settings (OPENLDAP_BOOTSTRAP_TLS=true)
│   ├── tls-required/          # Enforce TLS (OPENLDAP_BOOTSTRAP_TLS_REQUIRED=true)
│   ├── database-readonly/     # Read-only data DB user (OPENLDAP_BOOTSTRAP_DATA_READONLY=true)
│   ├── database-admin/        # Scoped users/groups administrator (OPENLDAP_BOOTSTRAP_DATA_ADMIN=true)
│   ├── database-management/   # Scoped application account ACLs (OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT=true)
│   ├── monitor-readonly/      # Read-only monitor user (OPENLDAP_BOOTSTRAP_MONITOR_READONLY=true)
│   ├── auditlog/              # Audit file (OPENLDAP_BOOTSTRAP_AUDITLOG=true)
│   ├── ppolicy/               # Password policy overlay (OPENLDAP_BOOTSTRAP_PPOLICY=true)
│   ├── refint/                # Referential integrity overlay (OPENLDAP_BOOTSTRAP_REFINT=true)
│   ├── unique/                # Unique attributes overlay (OPENLDAP_BOOTSTRAP_UNIQUE=true)
│   ├── memberof/              # Memberof overlay (OPENLDAP_BOOTSTRAP_MEMBEROF=true)
│   ├── replication/           # Replication (OPENLDAP_BOOTSTRAP_REPLICATION=true)
│   └── custom/                # User-provided config LDIF files
└── data/            # LDAP directory data (populated on first bootstrap)
    ├── base/                  # Root organization entry (always applied)
    ├── data-tree/             # Users, groups and services OUs (OPENLDAP_BOOTSTRAP_DATA_TREE=true)
    ├── database-admin/        # Directory administrator (OPENLDAP_BOOTSTRAP_DATA_ADMIN=true)
    ├── database-management/   # Application account (OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT=true)
    ├── database-readonly/     # Read-only account entry (OPENLDAP_BOOTSTRAP_DATA_READONLY=true)
    ├── monitor-readonly/      # Read-only monitor account (OPENLDAP_BOOTSTRAP_MONITOR_READONLY=true)
    ├── ppolicy/               # Password policy group and default policy (OPENLDAP_BOOTSTRAP_PPOLICY=true)
    ├── refint-nothing/        # Passwordless replacement role (REFINT enabled and NOTHING_DN set)
    ├── replication/           # Replication service accounts (OPENLDAP_BOOTSTRAP_REPLICATION=true)
    └── custom/                # User-provided data LDIF files
```

## Numbered prefix grouping behavior

During bootstrap, files are also grouped by **tens** based on their numeric prefix (`00`, `01`, ..., `99`, etc.), as implemented in `services/openldap-bootstrap/startup.sh`.

- Files in the **same ten-group** (for example `40-*` and `49-*`) are concatenated **without a blank line** between them.
- When switching to a **different ten-group** (for example `49-*` to `50-*`), bootstrap inserts **one blank line**.
- Leading and trailing empty lines are removed from every file before it is concatenated.

This matters because, in LDIF parsing, a blank line separates records:

- **No blank line** => content is treated as one logical LDIF record/entry stream.
- **Blank line present** => starts a new LDIF record/entry.

Examples:

- `40-a.ldif` + `49-b.ldif` => same ten-group (`4x`), concatenated directly.
- `49-b.ldif` + `50-c.ldif` => group change (`4x` -> `5x`), one empty line inserted.

Numeric prefixes are optional: names such as `schema.ldif` and `database.ldif` are accepted. Each file without a numeric prefix forms its own group, separated from other files by a blank line. Prefixes with leading zeros, such as `01-`, `08-`, and `09-`, are interpreted as decimal numbers.

## config/base

Core OpenLDAP configuration applied on every bootstrap. Files are numbered to control load order:

| File | Description |
|------|-------------|
| `00-global.ldif.template` | Global search limits, idle/write timeouts, pending requests and incoming message sizes |
| `10-module.ldif.template` | Module path and module list (`auto` or explicit order) |
| `20-schema.ldif` | Schema configuration container |
| `30-schema-import.ldif.template` | Additional schemas to load |
| `40-frontend.ldif.template` | Frontend database (password hash algorithm) |
| `50-config.ldif.template` | Config database (`olcDatabase=config`) with root DN and credentials |
| `59-config-acl-close.ldif` | Closes config ACLs (deny all) |
| `60-database.ldif.template` | Main data database (MDB backend) with indexes and last successful bind settings |
| `65-database-acl.ldif.template` | Data database ACLs (password self-service, basic attributes readable by authenticated users) |
| `69-database-acl-close.ldif` | Closes data ACLs (deny all) |
| `70-monitor.ldif.template` | Monitor database configuration |
| `75-monitor-acl.ldif.template` | Monitor database ACLs |
| `79-monitor-acl-close.ldif` | Closes monitor ACLs (deny all) |

ACL files ending in `-close.ldif` append a final `access to * by * none` rule to deny any unmatched access, ensuring a safe default.

## Root, admin and management accounts

A DN identifies an LDAP account or entry. These accounts serve different purposes:

| Account | Default DN | Purpose and permissions |
|---|---|---|
| Data root | `cn=admin,<suffix>` | Maintenance superuser for the data database; bypasses that database's ACLs and administrative limits |
| Config root | `cn=admin,cn=config` | Server configuration superuser; can change schemas, ACLs, root passwords and other settings in `cn=config` |
| Directory admin | `cn=admin,ou=services,<suffix>` | Day-to-day user/group administration, for example through phpLDAPadmin; obeys the scoped ACLs |
| Management | `cn=management,ou=services,<suffix>` | Application account, for example Authelia; reads users/groups and resets user passwords |

The two root DNs are configured through `OPENLDAP_BOOTSTRAP_DATA_ROOT_*` and
`OPENLDAP_BOOTSTRAP_CONFIG_ROOT_*`. Each bypasses ACLs only in its own database:
the data root is not automatically the configuration root. Config root can change
the data database's ACLs and root password, so reserve it for server maintenance.
Here, "root" means an LDAP superuser, not the Linux user running the container.

Root DNs can authenticate without a directory entry. The optional directory admin
has a real entry so clients such as phpLDAPadmin 2 can retrieve it after login.
Its DN and password are separate from the root credentials. Use it for routine
administration and keep root credentials for maintenance/recovery.

## data/database-admin and config/database-admin

Enable the standard branches and scoped administrator on a new installation:

```bash
OPENLDAP_BOOTSTRAP_DATA_TREE=true
OPENLDAP_BOOTSTRAP_DATA_ADMIN=true
OPENLDAP_BOOTSTRAP_DATA_ADMIN_PASSWORD_HASHED="{ARGON2}..."
```

An empty hash generates a password and prints it in the bootstrap logs, as for
the other accounts. `OPENLDAP_BOOTSTRAP_DATA_ADMIN_DN` defaults to
`cn=admin,${OPENLDAP_BOOTSTRAP_DATA_TREE_SERVICES_DN}`; use a DN starting with `cn=`.
Keep administrator and application accounts outside the writable users/groups
branches, normally in the separate services branch.
The parent OUs must exist: enable tree creation or supply custom LDIFs before
`70-database-admin-account.ldif`. Enabling this option does not modify an existing
database.

`62-database-admin-acl.ldif.template` lets the administrator create, read, edit,
rename and delete entries in the configured users/groups branches, and reset user
passwords. It denies password hash read/compare and access to `shadowLastChange`;
with ppolicy, `61-database-admin-ppolicy-acl.ldif.optional.template` also denies access to
`pwdHistory`. The administrator can read its own non-secret attributes, including
its identifier, but cannot modify, rename, delete or reset its own account.
Other service accounts, entries outside users/groups and `cn=config` stay protected.
Use data root to rotate the directory administrator's password.

Password resets use the same write/manage privileges as management resets. With ppolicy,
these administrative resets bypass quality, history-reuse and minimum-age checks;
the application performing them must enforce the required password rules.
This remains a powerful identity-management account: it can reset users' passwords
and change group memberships, but it cannot grant itself configuration access.

For phpLDAPadmin 2, configure DN login (`LDAP_LOGIN_ATTR=dn`) and accept this
entry's object class (`LDAP_LOGIN_OBJECTCLASS=organizationalRole`). Configure its
LDAP connection/search credentials and TLS separately.

## data/data-tree and data/database-management

`OPENLDAP_BOOTSTRAP_DATA_TREE=true` creates `ou=users`, `ou=groups` and `ou=services`
below the suffix. `OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT=true` creates one account,
by default `cn=management,ou=services,<suffix>`, to read users/groups and reset user
passwords. By default, it cannot edit profiles or groups or read password hashes/history.
Both options are independent and disabled by default.

The OU DNs, account DN and password hash are configurable through the matching
`OPENLDAP_BOOTSTRAP_DATA_TREE_*_DN` and `OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_*` variables.
If custom LDIFs supply the OUs, leave tree creation disabled and load them before
`80-database-management-account.ldif`. Do not duplicate automatically created OUs.

## config/database-management

`OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_HIDDEN_ATTRIBUTES` lists comma-separated
attributes hidden from the management account (default `userPassword,shadowLastChange`).
When ppolicy is enabled, `OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_HIDDEN_PPOLICY_ATTRIBUTES`
is added (default `pwdHistory`). The combined list must not be empty.

`63-database-management-acl.ldif.template` limits password writes to the users branch.
Its `=wmx` privileges allow administrative resets without the old password and
password changes that supply the old password, as Authelia does. The auth (`x`)
bit lets OpenLDAP verify that password without granting hash read/compare.
With ppolicy, these operations bypass quality, history-reuse and
minimum-age checks: enforce password requirements in the application.
Service accounts and configuration remain protected; other identities keep their
usual ACLs.

## config/database-readonly

`64-database-readonly-ppolicy-acl.ldif.optional.template` denies `pwdHistory` access to the data
read-only account before its general read grant. It is loaded only when ppolicy
and the data read-only account are both enabled, by `20-database-readonly.sh`.
Its final `by * break` lets other
identities follow the usual database ACLs, including administrator and replication
access and any custom grants before the final deny-all. Provide
`64-database-readonly-ppolicy-acl.ldif` or its `.ldif.template` variant through
the custom config directory to override the read-only restriction.

## data/ppolicy

`50-ppolicy-policy.ldif.template` sets the default password policy, including
`pwdMaxIdle` in seconds (`0`: disabled). Positive values require
`OPENLDAP_BOOTSTRAP_DATA_LAST_BIND=true` and `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_LOCKOUT=true`.

`pwdMinDelay` and `pwdMaxDelay` configure progressive per-account lockouts after
failed binds (`0`/`0`: disabled). Successful authentication resets the progression;
`pwdMaxFailure` and `pwdLockoutDuration` still apply when the failure threshold is reached.

## config/replication

Syncrepl-based multi-provider replication. Applied when `OPENLDAP_BOOTSTRAP_REPLICATION=true`.

| File | Description |
|------|-------------|
| `03-global-replication.ldif.template` | Server IDs for each replication node |
| `61-database-replication.ldif.template` | Syncrepl consumer on the data database |
| `67-database-replication-acl.ldif.template` | ACLs for data replication account |
| `180-overlays-replication-database.ldif.template` | Syncprov provider on the data database |

Overlay load order matters for all overlays (not only replication). Keep dependencies in mind when choosing numeric prefixes. For replication specifically, keep Syncprov overlays loaded last (highest numeric prefixes, as in `180-...`) so they are initialized after other overlays.

## Custom directories

Use these directories to customize the first initialization without rebuilding the image:

| Directory inside the container | Content |
|-------------------------------|---------|
| `/container/services/openldap-bootstrap/assets/ldif/config/custom` | Configuration (`cn=config`): ACLs, indexes, overlays, and other settings |
| `/container/services/openldap-bootstrap/assets/ldif/data/custom` | Initial directory entries: users, groups, and other LDAP data |

Create local directories and mount them into the container:

```bash
mkdir -p custom-config custom-data
```

```bash
docker run --name openldap \
  -v "$(pwd)/custom-config:/container/services/openldap-bootstrap/assets/ldif/config/custom" \
  -v "$(pwd)/custom-data:/container/services/openldap-bootstrap/assets/ldif/data/custom" \
  osixia/openldap:2.6.15-beta
```

Put `.ldif` files in these directories, or use `.ldif.template` files with `${VARIABLE}` placeholders to substitute environment variables. The mounts may be read-only: bootstrap renders templates in a temporary writable copy.

There are three ways to customize the bootstrap:

- **Add content:** use a new filename. For example, `custom-data/70-users.ldif` can contain user entries. Include a `dn:` and the required attributes for each entry, with a blank line between entries. Parent entries must come before their children.
- **Replace a built-in fragment:** copy its file into the matching custom directory, keep the filename, and edit it. For example, copy `config/base/65-database-acl.ldif.template` into `custom-config/` to change the default ACLs, or `config/base/60-database.ldif.template` to change database settings and indexes.
- **Remove a built-in fragment:** provide an empty `.ldif` file with the same output filename. For example, an empty `custom-config/65-database-acl.ldif` removes the rules from `65-database-acl.ldif.template`.

Custom files are copied after built-in files, replacing files with the same output filename after template substitution. The resulting files are then assembled in numerical order, using the [prefix grouping rules](#numbered-prefix-grouping-behavior) above. For configuration, a fragment in the same ten-group can add attributes to an existing entry; a different group starts a new entry.

Bootstrap imports the assembled entries with `slapadd`. Use entry attributes, without modification instructions such as `changetype: modify` or `replace: olcAccess`.

Replacing one fragment leaves the others in place. For example, replacing `65-database-acl.ldif.template` keeps the final deny-all rule in `69-database-acl-close.ldif` and any ACLs added by enabled features such as read-only accounts or replication.

Bootstrap runs only when both configuration and data directories are empty. This does not change an existing database.
