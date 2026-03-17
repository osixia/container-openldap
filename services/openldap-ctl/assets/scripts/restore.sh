#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

set -o pipefail

restore_database() {
    local db_number="$1"
    local filename="$2"
    local backup_file="${OPENLDAP_BACKUP_DIR}/${filename}"

    [ -f "${backup_file}" ] || {
        container logger fatal "Backup file not found: ${backup_file}"
    }

    gzip -dc "${backup_file}" | /usr/sbin/slapadd -F "${OPENLDAP_CONF_DIR}" -n "${db_number}"
}
