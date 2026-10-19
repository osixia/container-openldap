#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

OPENLDAP_TLS_RELOAD_STATE_DIR=$(mktemp -d /run/container/tmp/openldap-tls-reload.XXXXXX)
export OPENLDAP_TLS_RELOAD_STATE_DIR
trap 'rm -rf "${OPENLDAP_TLS_RELOAD_STATE_DIR:?}"' EXIT

sha256sum -- "${OPENLDAP_BOOTSTRAP_TLS_CERT}" "${OPENLDAP_BOOTSTRAP_TLS_CERT_KEY}" \
    "${OPENLDAP_BOOTSTRAP_TLS_CA_CERT}" | sha256sum > "${OPENLDAP_TLS_RELOAD_STATE_DIR}/fingerprint"

# Keep this shell to clean up its private state when the watcher exits.
container watch "${OPENLDAP_BOOTSTRAP_TLS_CERT}" "${OPENLDAP_BOOTSTRAP_TLS_CERT_KEY}" \
    "${OPENLDAP_BOOTSTRAP_TLS_CA_CERT}" --exec /container/services/openldap-tls-reload/assets/reload.sh
