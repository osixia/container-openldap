# Changelog

Project-specific changes only. See upstream [OpenLDAP release notes](https://www.openldap.org/software/release/changes_lts.html).

## 2.6.15-beta

### Changed

- Add the Postfix Book schema in both OpenLDAP `.schema` and `cn=config` `.ldif` formats.
- Improve debug logging for file moves and schema conversion, including a check that the generated LDIF file exists.
- Update the base image to `osixia/baseimage:alpine-2.0.0`.
- Build the CI/CD tool with `osixia/dagger-build` (replaces `osixia/container-baseimage/build`) and Go 1.26.9.
- Add integration tests: default bootstrap, all compatible modules and schemas, every bootstrap feature on a 3-node replicated cluster with TLS required, backup/restore and upgrades (simulated and from previous releases).
- Harden the CI workflow: read-only default permissions, actions pinned by commit SHA, images only published from tags, Dependabot updates.
- Build and test each architecture natively on its own runner instead of under QEMU, including the integration tests on arm64, and publish them together as a single multi-arch image.
- Allow authenticated users to read `entry`, `objectClass`, `ou`, `o` and `dc` in addition to `cn`, `sn`, `givenName`, `mail` and `uid` in the default database ACL (new bootstraps only).
- Set `OPENLDAP_BOOTSTRAP_PPOLICY_DEFAULT_CHECK_QUALITY` to `1` (was `0`) so `pwdMinLength` is enforced on clear text password changes; pre-hashed passwords are still accepted (new bootstraps only).
- Fail bootstrap with an explicit error when `OPENLDAP_BOOTSTRAP_SUFFIX` does not start with `dc=`, instead of creating a root entry with an empty `dc`.
- Fail bootstrap with an explicit error when `OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS` contains more than 9 hosts.
- Check that backup files exist and are valid gzip archives before `openldap-ctl restore` stops OpenLDAP or deletes existing data.
- Roll back to the previous config and data, and restart OpenLDAP if it was running, when `openldap-ctl restore` fails. Existing data is moved to a hidden `.restore-previous` directory in the same volume until the restore succeeds.
- Print usage when `openldap-ctl schema2ldif` is called without arguments.
- `openldap-ctl backup --clean` only removes backup files, and the new `--clean-prefix` option limits it to backups starting with a prefix. Cron backups are now named `openldap-cron-<date>-<version>` and only clean these files, manual and upgrade backups are kept. Cron backups named with the previous format are no longer removed automatically.

### Fixed

- Fix downgrade detection at the `minor` and `patch` migration levels.
- Fix `openldap-ctl password hash` for passwords containing spaces or shell special characters.
- Fix the default database ACL so authenticated users can actually read the allowed attributes.
- Remove bootstrap temporary files, including on failure.
- Fix bootstrap failing with `Argument list too long` when the schemas listed in `OPENLDAP_BOOTSTRAP_SCHEMAS` exceed 128 KiB: schemas are now loaded with LDIF `include:` lines instead of being copied into an environment variable.
- Fail bootstrap with an explicit error when a schema listed in `OPENLDAP_BOOTSTRAP_SCHEMAS` does not exist.
- Fix replication bootstrap failing when `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD` contains spaces: the default `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_TEMPLATE` now quotes `credentials`. Passwords containing double quotes, which `olcSyncRepl` cannot store, are rejected with an explicit error.
- Strip leading and trailing empty lines from every bootstrap LDIF fragment, including the first file of each prefix group.

### Documentation

- Pin documentation commands and Compose examples to `osixia/openldap:2.6.15-beta`.

- Document the Postfix Book schema and its incompatibility with the `virtualMail` schema.
- Improve the schema conversion example for local files and non-root execution.
- List the schemas and modules available in the image, with their incompatibilities.


## 2.6.15-alpha

### Changed

- Upgrade OpenLDAP from 2.6.10 to 2.6.15.
- Upgrade base image to `osixia/baseimage:alpine-2.0.0-rc2`.
- Update `osixia/container-baseimage/build` and Go dependencies.
- Update GitHub Actions dependencies and use Go 1.26.1 in CI.

### Fixed

- Adjust SBOM attestation generation to use Cosign's `spdxjson` predicate type.

### Documentation

- Expand custom bootstrap LDIF documentation with volume mounts, template usage, and examples for adding, replacing, or removing built-in fragments.
- Clarify LDIF prefix grouping rules, including filenames without numeric prefixes and prefixes with leading zeros.
- Clarify that the cron service is disabled by default and document scheduled backups using a separate container.


## 2.6.10-alpha

⚠️ Breaking change: this version is a complete rewrite with a new base image and is not backward compatible. Please refer to the [README](README.md) for the new usage.

### Changed
  - Upgrade OpenLDAP version to 2.6.15
  - Upgrade base image to osixia/baseimage:alpine-2.0.0-rc2
  - Use GitHub action for CI/CD and osixia/container-baseimage/build tool

For previous releases, see the GitHub [releases page](https://github.com/osixia/container-openldap/releases).
