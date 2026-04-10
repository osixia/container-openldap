# osixia/openldap

[![Docker Pulls](https://img.shields.io/docker/pulls/osixia/openldap.svg)](https://hub.docker.com/r/osixia/openldap/)
[![Docker Stars](https://img.shields.io/docker/stars/osixia/openldap.svg)](https://hub.docker.com/r/osixia/openldap/)

**A docker image to run OpenLDAP.**

> OpenLDAP website : [www.openldap.org](https://www.openldap.org/)

## Table of Contents

- [Quick Start](#quick-start)
- [Enable the readonly account](#enable-the-readonly-account)
- [Enable TLS](#enable-tls)
- [Enable replication](#enable-replication)
- [Environment variables reference](#environment-variables-reference)

---

## Quick Start

### docker run

```bash
docker run -d \
  --name openldap \
  -p 3890:3890 \
  -e OPENLDAP_BOOTSTRAP_ORGANIZATION="My Company" \
  -e OPENLDAP_BOOTSTRAP_SUFFIX="dc=mycompany,dc=com" \
  osixia/openldap:latest
```

The admin passwords for `cn=config` and the data database are **auto-generated** on first boot when the `*_PASSWORD_HASHED` variables are left empty. Retrieve them from the container logs:

```bash
docker logs openldap 2>&1 | grep -i password
```

To set your own passwords, generate a hash first then pass it as an environment variable:

```bash
# Generate a hash inside the container
docker run --rm osixia/openldap:latest \
  container entrypoint openldap-ctl -- password hash

# Then start the container with the hashed value
docker run -d \
  --name openldap \
  -p 3890:3890 \
  -e OPENLDAP_BOOTSTRAP_ORGANIZATION="My Company" \
  -e OPENLDAP_BOOTSTRAP_SUFFIX="dc=mycompany,dc=com" \
  -e OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED="{ARGON2}..." \
  osixia/openldap:latest
```

### docker compose

```yaml
services:
  openldap:
    image: osixia/openldap:latest
    ports:
      - "3890:3890"
    environment:
      OPENLDAP_BOOTSTRAP_ORGANIZATION: "My Company"
      OPENLDAP_BOOTSTRAP_SUFFIX: "dc=mycompany,dc=com"
    volumes:
      - openldap-config:/etc/openldap/slapd.d
      - openldap-data:/var/lib/openldap/openldap-data

volumes:
  openldap-config:
  openldap-data:
```

> Persisting `OPENLDAP_CONF_DIR` and `OPENLDAP_DATA_DIR` via volumes ensures data survives container restarts. Bootstrap only runs when the config directory is empty.

---

## Enable the readonly account

The readonly account is an unprivileged entry that can bind and search the data database. It is useful for applications that only need to perform lookups.

Set `OPENLDAP_BOOTSTRAP_DATA_READONLY=true` to create it during bootstrap:

```yaml
services:
  openldap:
    image: osixia/openldap:latest
    ports:
      - "3890:3890"
    environment:
      OPENLDAP_BOOTSTRAP_ORGANIZATION: "My Company"
      OPENLDAP_BOOTSTRAP_SUFFIX: "dc=mycompany,dc=com"
      # Enable the readonly account
      OPENLDAP_BOOTSTRAP_DATA_READONLY: "true"
      OPENLDAP_BOOTSTRAP_DATA_READONLY_DN: "cn=readonly,dc=mycompany,dc=com"
      # Leave empty to auto-generate, or provide a pre-hashed password
      OPENLDAP_BOOTSTRAP_DATA_READONLY_PASSWORD_HASHED: ""
    volumes:
      - openldap-config:/etc/openldap/slapd.d
      - openldap-data:/var/lib/openldap/openldap-data

volumes:
  openldap-config:
  openldap-data:
```

The readonly DN defaults to `cn=readonly,<suffix>` and its password is auto-generated if left empty (check the container logs to retrieve it).

---

## Enable TLS

TLS requires a certificate, a private key, and a CA certificate mounted into the container. The default paths expected by the container are:

| File | Default path in container |
|---|---|
| Server certificate | `/container/services/openldap/assets/certs/cert.crt` |
| Private key | `/container/services/openldap/assets/certs/cert.key` |
| CA certificate | `/container/services/openldap/assets/certs/ca.crt` |

```yaml
services:
  openldap:
    image: osixia/openldap:latest
    ports:
      - "3890:3890"   # LDAP + StartTLS
      - "6360:6360"   # LDAPS
    environment:
      OPENLDAP_BOOTSTRAP_ORGANIZATION: "My Company"
      OPENLDAP_BOOTSTRAP_SUFFIX: "dc=mycompany,dc=com"
      # Enable TLS
      OPENLDAP_BOOTSTRAP_TLS: "true"
      # Reject plain-text connections (optional)
      OPENLDAP_BOOTSTRAP_TLS_REQUIRED: "true"
      # Client certificate policy: none | allow | try | demand
      OPENLDAP_BOOTSTRAP_TLS_VERIFY_CLIENT: "allow"
      # Minimum protocol version: 3.3 = TLS 1.2, 3.4 = TLS 1.3
      OPENLDAP_BOOTSTRAP_TLS_PROTOCOL_MIN: "3.3"
    volumes:
      - openldap-config:/etc/openldap/slapd.d
      - openldap-data:/var/lib/openldap/openldap-data
      # Mount your certificates into the expected paths
      - ./certs/cert.crt:/container/services/openldap/assets/certs/cert.crt:ro
      - ./certs/cert.key:/container/services/openldap/assets/certs/cert.key:ro
      - ./certs/ca.crt:/container/services/openldap/assets/certs/ca.crt:ro

volumes:
  openldap-config:
  openldap-data:
```

You can override the default certificate paths using `OPENLDAP_BOOTSTRAP_TLS_CERT`, `OPENLDAP_BOOTSTRAP_TLS_CERT_KEY`, and `OPENLDAP_BOOTSTRAP_TLS_CA_CERT` if you prefer to mount your files elsewhere.

---

## Enable replication

The container supports **multi-master replication** via the `syncprov` overlay. Exactly two nodes are supported. Both nodes must declare the same host list in the same order in `OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS`.

The bootstrap script automatically determines which node it is by matching the container hostname against the host list, then derives the `serverID` and `syncrepl` RIDs accordingly.

```yaml
services:
  ldap1:
    image: osixia/openldap:latest
    hostname: ldap1.example.org
    ports:
      - "3891:3890"
    environment:
      OPENLDAP_BOOTSTRAP_ORGANIZATION: "My Company"
      OPENLDAP_BOOTSTRAP_SUFFIX: "dc=mycompany,dc=com"
      # Enable replication
      OPENLDAP_BOOTSTRAP_REPLICATION: "true"
      OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS: "ldap://ldap1.example.org:3890 ldap://ldap2.example.org:3890"
      # Replication service accounts (passwords auto-generated if left empty)
      OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD: ""
      OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD: ""
    volumes:
      - ldap1-config:/etc/openldap/slapd.d
      - ldap1-data:/var/lib/openldap/openldap-data

  ldap2:
    image: osixia/openldap:latest
    hostname: ldap2.example.org
    ports:
      - "3892:3890"
    environment:
      OPENLDAP_BOOTSTRAP_ORGANIZATION: "My Company"
      OPENLDAP_BOOTSTRAP_SUFFIX: "dc=mycompany,dc=com"
      # Same replication config on both nodes
      OPENLDAP_BOOTSTRAP_REPLICATION: "true"
      OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS: "ldap://ldap1.example.org:3890 ldap://ldap2.example.org:3890"
      # Must match the passwords set on ldap1
      OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD: ""
      OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD: ""
    volumes:
      - ldap2-config:/etc/openldap/slapd.d
      - ldap2-data:/var/lib/openldap/openldap-data

volumes:
  ldap1-config:
  ldap1-data:
  ldap2-config:
  ldap2-data:
```

> **Important:** the replication service account passwords must be identical on both nodes. Either set them explicitly via `OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD` and `OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD`, or bootstrap both nodes from the same backup so that the auto-generated passwords match.

To also encrypt replication traffic, enable TLS on both nodes (see [Enable TLS](#enable-tls)) and set:

```yaml
OPENLDAP_BOOTSTRAP_REPLICATION_TLS: "true"
```

---

## Environment variables reference

Full documentation for all available environment variables is in [`docs/environment-variables.md`](docs/environment-variables.md).
