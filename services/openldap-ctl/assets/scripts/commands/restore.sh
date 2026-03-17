#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

set -o pipefail

CONFIG=false
DATA=false
FORCE=false
RESTART=false
FILE_PREFIX=""

usage() {
    echo "Usage: file-prefix [--config] [--data]"
}

restore_database() {
    local filename="$1"
    local db_number="$2"
    local backup_file="${OPENLDAP_BACKUP_DIR}/${filename}"

    if [ ! -f "${backup_file}" ]; then
        container log fatal "Backup file not found: ${backup_file}"
    fi

    gzip -dc "${backup_file}" | slapadd -F "${OPENLDAP_CONF_DIR}" -n "${db_number}" 2>&1 | container log debug

    if [ "${db_number}" -gt 0 ]; then
        slapindex -F "${OPENLDAP_CONF_DIR}" -n "${db_number}" 2>&1 | container log debug
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --config)
            CONFIG=true
            shift
            ;;
        --data)
            DATA=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --*)
            usage
            container log fatal "Unknown option: $1"
            ;;
        *)
            if [ -z "${FILE_PREFIX}" ]; then
                FILE_PREFIX="$1"
            else
                usage
                container log fatal "Too many arguments"
            fi
            shift
            ;;
    esac
done

if [ -z "${FILE_PREFIX}" ]; then
    usage
    container log fatal "Missing file-prefix"
fi

if [ "${CONFIG}" = false ] && [ "${DATA}" = false ]; then
    CONFIG=true
    DATA=true
fi

if [ -e "/run/container/processes/openldap.pid" ]; then

    if [ "${FORCE}" != true ]; then
        container log fatal "OpenLDAP is currently running. Restore cannot proceed. Use --force to stop the service."
    fi

    container log warning "Stopping OpenLDAP ..."
    container processes stop openldap

    RESTART=true

fi

if [ -n "$(find "${OPENLDAP_CONF_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ] || \
   [ -n "$(find "${OPENLDAP_DATA_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ]; then

    if [ "${FORCE}" != true ]; then
        container log fatal "Existing data detected in ${OPENLDAP_CONF_DIR} or ${OPENLDAP_DATA_DIR}. Restore cannot proceed. Use --force to delete existing data, but make sure to back it up first."
    fi

fi

if [ "${CONFIG}" = true ]; then

    if [ -n "$(find "${OPENLDAP_CONF_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ]; then
        container log warning "Deleting data in ${OPENLDAP_CONF_DIR} ..."
        rm -fr "${OPENLDAP_CONF_DIR:?}"/*
    fi

    container log info "Restoring OpenLDAP config ..."
    restore_database "${FILE_PREFIX}${OPENLDAP_CTL_BACKUP_CONFIG_FILE_SUFFIX}" 0
fi

if [ "${DATA}" = true ]; then

    if [ -n "$(find "${OPENLDAP_DATA_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ]; then
        container log warning "Deleting data in ${OPENLDAP_DATA_DIR} ..."
        rm -fr "${OPENLDAP_DATA_DIR:?}"/*
    fi

    container log info "Restoring OpenLDAP data ..."
    restore_database "${FILE_PREFIX}${OPENLDAP_CTL_BACKUP_DATA_FILE_SUFFIX}" 1
fi

if [ "${RESTART}" = true ]; then
    container log warning "Restarting OpenLDAP ..."
    container processes start openldap
fi
