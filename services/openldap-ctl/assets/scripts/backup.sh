#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

set -o pipefail

backup_database() {
    local db_number="$1"
    local filename="$2"
    local tmp_file

    umask 077

    tmp_file="$(mktemp "${OPENLDAP_BACKUP_DIR}/.tmp.XXXXXX")"
    trap 'rm -f "${tmp_file}"' RETURN

    if ! /usr/sbin/slapcat -F "${OPENLDAP_CONF_DIR}" -n "${db_number}" | gzip > "${tmp_file}"; then
        container logger fatal "Failed to backup database ${db_number} to ${filename}"
    fi

    mv "${tmp_file}" "${OPENLDAP_BACKUP_DIR}/${filename}"

    trap - RETURN
}
