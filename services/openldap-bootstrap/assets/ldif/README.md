# LDIF Templates

This directory contains LDAP Data Interchange Format (LDIF) files used to bootstrap the OpenLDAP configuration and data during container initialization.

Files with a `.template` extension use `${VARIABLE}` placeholders that are substituted with environment variables at runtime. Static `.ldif` files are applied as-is.

Files are processed in lexicographic order within each directory (numerical prefixes control ordering).

## Structure

```
ldif/
├── config/          # OpenLDAP configuration database (cn=config)
│   ├── base/              # Core configuration (always applied)
│   ├── tls/               # TLS settings (OPENLDAP_BOOTSTRAP_TLS=true)
│   ├── tls-required/      # Enforce TLS (OPENLDAP_BOOTSTRAP_TLS_REQUIRED=true)
│   ├── database-readonly/ # Read-only data DB user (OPENLDAP_BOOTSTRAP_DATA_READONLY=true)
│   ├── monitor-readonly/  # Read-only monitor user (OPENLDAP_BOOTSTRAP_MONITOR_READONLY=true)
│   ├── ppolicy/           # Password policy overlay (OPENLDAP_BOOTSTRAP_PPOLICY=true)
│   ├── refint/            # Referential integrity overlay (OPENLDAP_BOOTSTRAP_REFINT=true)
│   ├── unique/            # Unique attributes overlay (OPENLDAP_BOOTSTRAP_UNIQUE=true)
│   ├── memberof/          # Memberof overlay (OPENLDAP_BOOTSTRAP_MEMBEROF=true)
│   ├── replication/       # Replication (OPENLDAP_BOOTSTRAP_REPLICATION=true)
│   └── custom/            # User-provided config LDIF files
└── data/            # LDAP directory data (populated on first bootstrap)
    ├── base/              # Root organization entry (always applied)
    ├── database-readonly/ # Read-only account entry (OPENLDAP_BOOTSTRAP_DATA_READONLY=true)
    ├── monitor-readonly/  # Read-only monitor account (OPENLDAP_BOOTSTRAP_MONITOR_READONLY=true)
    ├── ppolicy/           # Password policy group and default policy (OPENLDAP_BOOTSTRAP_PPOLICY=true)
    ├── replication/       # Replication service accounts (OPENLDAP_BOOTSTRAP_REPLICATION=true)
    └── custom/            # User-provided data LDIF files
```

## Numbered prefix grouping behavior

During bootstrap, files are also grouped by **tens** based on their numeric prefix (`00`, `01`, ..., `99`, etc.), as implemented in `services/openldap-bootstrap/startup.sh`.

- Files in the **same ten-group** (for example `40-*` and `49-*`) are concatenated **without a blank line** between them.
- When switching to a **different ten-group** (for example `49-*` to `50-*`), bootstrap inserts **one blank line**.

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
| `00-global.ldif.template` | Global limits (size, time, idle timeout) |
| `10-module.ldif.template` | Module path and dynamic module list |
| `20-schema.ldif` | Schema configuration container |
| `30-schema-import.ldif.template` | Additional schemas to load |
| `40-frontend.ldif.template` | Frontend database (password hash algorithm) |
| `50-config.ldif.template` | Config database (`olcDatabase=config`) with root DN and credentials |
| `59-config-acl-close.ldif` | Closes config ACLs (deny all) |
| `60-database.ldif.template` | Main data database (MDB backend) with indexes |
| `65-database-acl.ldif.template` | Data database ACLs (user self-service, attribute access) |
| `69-database-acl-close.ldif` | Closes data ACLs (deny all) |
| `70-monitor.ldif.template` | Monitor database configuration |
| `75-monitor-acl.ldif.template` | Monitor database ACLs |
| `79-monitor-acl-close.ldif` | Closes monitor ACLs (deny all) |

ACL files ending in `-close.ldif` append a final `access to * by * none` rule to deny any unmatched access, ensuring a safe default.

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
  osixia/openldap
```

Put `.ldif` files in these directories, or use `.ldif.template` files with `${VARIABLE}` placeholders to substitute environment variables. Leave the mounts writable so bootstrap can convert templates into `.ldif` files.

There are three ways to customize the bootstrap:

- **Add content:** use a new filename. For example, `custom-data/70-users.ldif` can contain user entries. Include a `dn:` and the required attributes for each entry, with a blank line between entries. Parent entries must come before their children.
- **Replace a built-in fragment:** copy its file into the matching custom directory, keep the filename, and edit it. For example, copy `config/base/65-database-acl.ldif.template` into `custom-config/` to change the default ACLs, or `config/base/60-database.ldif.template` to change database settings and indexes.
- **Remove a built-in fragment:** provide an empty `.ldif` file with the same output filename. For example, an empty `custom-config/65-database-acl.ldif` removes the rules from `65-database-acl.ldif.template`.

Custom files are copied after built-in files, replacing files with the same output filename after template substitution. The resulting files are then assembled in numerical order, using the [prefix grouping rules](#numbered-prefix-grouping-behavior) above. For configuration, a fragment in the same ten-group can add attributes to an existing entry; a different group starts a new entry.

Bootstrap imports the assembled entries with `slapadd`. Use entry attributes, without modification instructions such as `changetype: modify` or `replace: olcAccess`.

Replacing one fragment leaves the others in place. For example, replacing `65-database-acl.ldif.template` keeps the final deny-all rule in `69-database-acl-close.ldif` and any ACLs added by enabled features such as read-only accounts or replication.

Bootstrap runs only when both configuration and data directories are empty. This does not change an existing database.
