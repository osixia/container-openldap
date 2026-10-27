#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# Group file events from the same renewal, then compare contents, not timestamps
# or symlink targets. The baseimage watcher runs callbacks sequentially.
sleep 1
if ! fingerprint=$(sha256sum -- "${OPENLDAP_BOOTSTRAP_TLS_CERT}" "${OPENLDAP_BOOTSTRAP_TLS_CERT_KEY}" \
    "${OPENLDAP_BOOTSTRAP_TLS_CA_CERT}" | sha256sum); then
    container log error "Cannot read TLS files; OpenLDAP was not restarted"
    exit 0
fi

if [ "${fingerprint}" = "$(cat "${OPENLDAP_TLS_RELOAD_STATE_DIR:?}/fingerprint")" ]; then
    container log debug "TLS file contents unchanged; skipping restart"
    exit 0
fi

# Preserve an intentional stop requested through the baseimage CLI.
if [ -e /run/container/processes/openldap.down ] || [ ! -e /run/container/processes/openldap.pid ]; then
    container log warning "TLS files changed but OpenLDAP is not running; skipping restart"
    exit 0
fi

container log info "TLS file contents changed; restarting OpenLDAP ..."
if container processes stop openldap && container processes start openldap; then
    printf '%s\n' "${fingerprint}" > "${OPENLDAP_TLS_RELOAD_STATE_DIR}/fingerprint"
else
    container log error "Failed to restart OpenLDAP after TLS files changed"
fi
