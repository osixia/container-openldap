# CI/CD tool

Built with [osixia/dagger-build](https://github.com/osixia/dagger-build).

## Get Help
```
go run main.go --help
```

## Run Tests
```
go mod vendor
go run main.go job test ../Dockerfile
```

Limit a local run with `--arches amd64`. Pass the arch of the host: scenarios run on every
built image, and other arches would be emulated. The CI builds and tests each arch on its
own native runner, then publishes them together from their OCI archives
(`--oci-export-to`, `--oci-import-from`).

After the shared version check, `tests/` runs integration scenarios on each built image:

- default bootstrap;
- standard users/groups/services tree and management account: independent opt-ins,
  custom DNs and supplied OUs, generated passwords, user/group
  reads, password resets including application administrators, ppolicy-safe resets,
  hidden hashes/history, and denied profile, membership, entry and service changes;
- global request limits: native defaults, custom values and incoming message size
  enforcement for anonymous and authenticated connections;
- read-only bootstrap templates with projected-volume symlinks, custom overrides
  and temporary-copy cleanup on success and failure;
- TLS certificate renewals: restart slapd on changed contents, ignore identical
  projected volumes and duplicate events, and preserve intentional service stops;
  run bootstrap, schema conversion and TLS renewals with `/tmp` mounted read-only;
- alternative schemas (`nis`, `virtualMail`);
- automatic modules: feature flags, replication, exact custom ordering and aliases;
- auditlog: automatic module loading, writes, custom paths, rotation and restarts;
- last successful binds: disabled by default, precision throttling, failed binds
  and compatibility with ppolicy;
- password history privacy: hidden from readonly, ordinary users, owner and
  anonymous users by default; retained for administrators and replication, with
  reuse checks on every node, custom ACL grants and fragment replacements, and
  no extra ACL when ppolicy or the read-only account is disabled;
- password policy inactivity: disabled by default, active and idle accounts,
  first logins and missing prerequisites;
- progressive password policy lockouts: disabled by default, doubling and cap,
  recovery, independent accounts and compatibility with the fixed lockout threshold;
- refint empty-group placeholders: default behavior, automatic role creation
  and deletion of the last real group member with memberof enabled;
- all features with 3 replicated nodes: all compatible modules and schemas, TLS required,
  readonly users, monitor, auditlog, ppolicy, unique, refint, memberof and multi-provider replication;
- `openldap-ctl` backup and restore;
- password hashing: arguments, secret files and stdin, exact contents, custom hash
  commands and trace output without file/stdin secrets;
- LDIF validation: syntax, required attributes, value syntax and suffix checks,
  multiple files, recursive directories and projected-volume symlinks, with unchanged
  configuration and data while slapd is stopped or running;
- upgrade: pre-upgrade backup on a simulated N-1 image, restore on N, downgrade refused;
- upgrade from previous published releases (`previousReleases` in `tests/upgrade.go`).

Scenarios are written in Go and run their LDAP checks with the scripts in
`tests/testdata/`. Replication nodes run with root capabilities in derived test containers,
to get their hostname (see `tests/testdata/node.sh`).
