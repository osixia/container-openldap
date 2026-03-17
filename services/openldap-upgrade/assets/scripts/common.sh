#!/bin/bash -e

extract_version() {
    local version=$1
    case "${OPENLDAP_UPGRADE_MIGRATION_LEVEL}" in
        patch) echo "${version}" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' ;;
        minor) echo "${version}" | grep -oE '^[0-9]+\.[0-9]+' ;;
        major) echo "${version}" | grep -oE '^[0-9]+' ;;
        *) container logger fatal "Unknow OPENLDAP_UPGRADE_MIGRATION_LEVEL: ${OPENLDAP_UPGRADE_MIGRATION_LEVEL}. Must be patch, minor or major" ;;
    esac
}

version_lt() {
    local IFS=.
    local -a v1=("$1") v2=("$2")
    for i in 0 1 2; do
        local a=${v1[i]:-0} b=${v2[i]:-0}
        (( 10#$a < 10#$b )) && return 0
        (( 10#$a > 10#$b )) && return 1
    done
    return 1
}

write_version() {
    container logger info "Writing OpenLDAP version ${OPENLDAP_VERSION} to ${OPENLDAP_UPGRADE_CONF_VERSION_FILE} ..."
    echo "${OPENLDAP_VERSION}" > "${OPENLDAP_UPGRADE_CONF_VERSION_FILE}"
}

backup_files_prefix() {
    echo "${OPENLDAP_UPGRADE_BACKUP_FILES_PREFIX}-${CURRENT_CONF_VERSION_COMPARABLE}"
}
