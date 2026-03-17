#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

set -o pipefail

CONFIG=false
DATA=false
CLEAN_DAYS=""
FILE_PREFIX=""

usage() {
    echo "Usage: file-prefix [--config] [--data] [--clean days|--clean=days]"
}

clean() {
    find "${OPENLDAP_BACKUP_DIR}" -type f -mtime "+$1" -print0 | xargs -0 rm -fv | container log info
}

backup_database() {
    local filename="$1"
    local db_number="$2"
    local tmp_file

    umask 077

    tmp_file="$(mktemp "${OPENLDAP_BACKUP_DIR}/.tmp.XXXXXX")"
    trap 'rm -f "${tmp_file}"' RETURN

    if ! slapcat -F "${OPENLDAP_CONF_DIR}" -n "${db_number}" | gzip > "${tmp_file}"; then
        container log fatal "Failed to backup database ${db_number} to ${filename}"
    fi

    mv "${tmp_file}" "${OPENLDAP_BACKUP_DIR}/${filename}"

    trap - RETURN
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
      --clean)
          if [ $# -lt 2 ]; then
              usage
          fi
          CLEAN_DAYS="$2"
          shift 2
          ;;
      --clean=*)
          CLEAN_DAYS="${1#*=}"
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

if [ "${CONFIG}" = true ]; then
    container log info "Backing up OpenLDAP config ..."
    backup_database "${FILE_PREFIX}${OPENLDAP_CTL_BACKUP_CONFIG_FILE_SUFFIX}" 0
fi

if [ "${DATA}" = true ]; then
    container log info "Backing up OpenLDAP data ..."
    backup_database "${FILE_PREFIX}${OPENLDAP_CTL_BACKUP_DATA_FILE_SUFFIX}" 1
fi

if [ -n "${CLEAN_DAYS}" ]; then
    container log info "Cleaning up backups older than ${CLEAN_DAYS} day(s) ..."
    clean "${CLEAN_DAYS}"
fi
