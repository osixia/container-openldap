# Bootstrap Scripts

Shell scripts that prepare environment variables and LDIF files for the OpenLDAP bootstrap process. Each script supports two operations:

- **`env`** – exports variables needed by LDIF templates (passwords, computed values, etc.)
- **`ldif`** – copies and renders LDIF templates from `../ldif/` into the bootstrap working directory

Scripts are executed in numeric order. Most are feature-gated by an environment variable and skip themselves when their feature is disabled.

## Scripts

| Script | Trigger | Description |
|--------|---------|-------------|
| `00-base.sh` | always | Core bootstrap: password hashing for root DNs, module and schema setup, base LDIF files |
| `10-tls.sh` | `OPENLDAP_BOOTSTRAP_TLS=true` | Applies TLS certificate and protocol configuration |
| `15-tls-required.sh` | `OPENLDAP_BOOTSTRAP_TLS_REQUIRED=true` | Enforces minimum 128-bit SSF (warns if TLS is not also enabled) |
| `20-database-readonly.sh` | `OPENLDAP_BOOTSTRAP_DATA_READONLY=true` | Creates a read-only service account for the data database |
| `30-monitor-readonly.sh` | `OPENLDAP_BOOTSTRAP_MONITOR_READONLY=true` | Creates a read-only service account for the monitor database |
| `40-refint.sh` | `OPENLDAP_BOOTSTRAP_REFINT=true` | Configures the referential integrity overlay |
| `50-ppolicy.sh` | `OPENLDAP_BOOTSTRAP_PPOLICY=true` | Configures the password policy overlay and default policy entry |
| `60-unique.sh` | `OPENLDAP_BOOTSTRAP_UNIQUE=true` | Configures the unique attributes overlay |
| `70-memberof.sh` | `OPENLDAP_BOOTSTRAP_MEMBEROF=true` | Configures the memberof overlay |
| `80-replication.sh` | `OPENLDAP_BOOTSTRAP_REPLICATION=true` | Sets up multi-provider syncrepl replication (requires ≥ 2 hosts) |
| `90-custom.sh` | always | Applies user-provided custom LDIF files from the `custom/` directories |

## Helpers

Utility functions shared across the bootstrap scripts.

### `helpers/common.sh`

| Function | Description |
|----------|-------------|
| `check_args` | Validates that a script was called with the expected operation (`env`/`ldif`) and argument count |
| `prepare_env_file` | Appends exported variable assignments (safely shell-quoted) to an env file |
| `prepare_ldif_files` | Renders `.ldif.template` files via `container envsubst templates` and copies all resulting `.ldif` files (sorted) to the output directory |
| `get_dn_attr` | Extracts the value of a named attribute from a DN string (e.g. `cn` from `cn=admin,dc=example,dc=com`) |

### `helpers/password.sh`

| Function | Description |
|----------|-------------|
| `generate_password` | Generates a random password using `openldap-ctl password generate` |
| `hash_password` | Hashes a plaintext password using `openldap-ctl password hash` |
| `ensure_hashed_password` | Returns the input unchanged if already hashed; otherwise generates and hashes a new password and logs that a random one was created |

## Adding a new feature

1. Create a numbered script (e.g. `55-myfeature.sh`) that accepts `env` and `ldif` arguments.
2. Guard execution with the appropriate environment variable check.
3. Add the corresponding LDIF templates under `../ldif/config/` and/or `../ldif/data/`.
4. Source `helpers/common.sh` and `helpers/password.sh` as needed.
