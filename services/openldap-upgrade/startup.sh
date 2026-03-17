#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source "/container/services/openldap-upgrade/assets/scripts/common.sh"

if [ ! -e "${OPENLDAP_UPGRADE_CONF_VERSION_FILE}" ]; then
    write_version
fi

OPENLDAP_VERSION_COMPARABLE=$(extract_version "${OPENLDAP_VERSION}")
CURRENT_CONF_VERSION=$(cat "${OPENLDAP_UPGRADE_CONF_VERSION_FILE}")
CURRENT_CONF_VERSION_COMPARABLE=$(extract_version "${CURRENT_CONF_VERSION}")

container log info "Migration level set to '${OPENLDAP_UPGRADE_MIGRATION_LEVEL}'"
container log info "OpenLDAP version: ${OPENLDAP_VERSION}, conf version: ${CURRENT_CONF_VERSION}"

if [ "${OPENLDAP_VERSION_COMPARABLE}" = "${CURRENT_CONF_VERSION_COMPARABLE}" ]; then
    container log info "No migration needed at ${OPENLDAP_UPGRADE_MIGRATION_LEVEL} level"
    exit 0
fi

if version_lt "${OPENLDAP_VERSION_COMPARABLE}" "${CURRENT_CONF_VERSION_COMPARABLE}"; then
    if [ "${OPENLDAP_UPGRADE_FORCE}" != "true" ]; then
          container log fatal "Downgrade forbidden: ${CURRENT_CONF_VERSION_COMPARABLE} → ${OPENLDAP_VERSION_COMPARABLE}. Set OPENLDAP_UPGRADE_FORCE=true to bypass."
    fi
    container log warning "Downgrade forced: ${CURRENT_CONF_VERSION_COMPARABLE} → ${OPENLDAP_VERSION_COMPARABLE}"
fi

container log warning "Migration required: ${CURRENT_CONF_VERSION_COMPARABLE} → ${OPENLDAP_VERSION_COMPARABLE}"

UPGRADE_BACKUP_CONFIG_FILE="${OPENLDAP_BACKUP_DIR}/$(backup_files_prefix)${OPENLDAP_CTL_BACKUP_CONFIG_FILE_SUFFIX}"
UPGRADE_BACKUP_DATA_FILE="${OPENLDAP_BACKUP_DIR}/$(backup_files_prefix)${OPENLDAP_CTL_BACKUP_DATA_FILE_SUFFIX}"

if [ ! -e "${UPGRADE_BACKUP_CONFIG_FILE}" ] || [ ! -e "${UPGRADE_BACKUP_DATA_FILE}" ]; then
    if [ "${OPENLDAP_UPGRADE_FORCE}" != "true" ]; then
        container log fatal "Missing ${UPGRADE_BACKUP_CONFIG_FILE} or ${UPGRADE_BACKUP_DATA_FILE}. Set OPENLDAP_UPGRADE_FORCE=true to bypass."
    fi
    container log warning "Missing ${UPGRADE_BACKUP_CONFIG_FILE} or ${UPGRADE_BACKUP_DATA_FILE}. Ignored ..."
    exit 0
fi

openldap-ctl restore "$(backup_files_prefix)" --force

write_version
