#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

# shellcheck disable=SC1091
source "/container/services/openldap-upgrade/assets/scripts/common.sh"

OPENLDAP_VERSION_COMPARABLE=$(extract_version "${OPENLDAP_VERSION}")
CURRENT_CONF_VERSION_COMPARABLE=$(extract_version "$(cat "${OPENLDAP_UPGRADE_CONF_VERSION_FILE}")")

if [ "${OPENLDAP_VERSION_COMPARABLE}" != "${CURRENT_CONF_VERSION_COMPARABLE}" ]; then
    container logger info "No pre-upgrade backup needed"
    container logger debug "OpenLDAP version: ${OPENLDAP_VERSION_COMPARABLE}, conf version: ${CURRENT_CONF_VERSION_COMPARABLE}"
    exit 0
fi

container entrypoint -x openldap-ctl -- backup "$(backup_files_prefix)"
