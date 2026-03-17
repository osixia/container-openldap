# Changelog

Project-specific changes only. See upstream [OpenLDAP release notes](https://www.openldap.org/software/release/changes_lts.html).

## 2.6.10

⚠️ Breaking change: this version is a complete rewrite with a new base image and is not backward compatible. Please refer to the [README](README.md) for the new usage.

### Changed
  - Upgrade OpenLDAP version to 2.6.10
  - Upgrade base image to osixia/baseimage:alpine-2.0.0-beta3
  - Use GitHub action for CI/CD and osixia/container-baseimage/build tool

For previous releases, see the GitHub [releases page](https://github.com/osixia/container-openldap/releases).
