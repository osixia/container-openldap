#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# skip bootstrapping if config or data directory is not empty
if [ -n "$(find "${OPENLDAP_CONF_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ] || \
   [ -n "$(find "${OPENLDAP_DATA_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ]; then
    container log debug "Existing data detected in ${OPENLDAP_CONF_DIR} or ${OPENLDAP_DATA_DIR}"
    container log info "Skipping OpenLDAP bootstrapping ..."
    exit 0
fi

container log info "Bootstrapping OpenLDAP ..."

BOOTSTRAP_TMP_DIR="$(mktemp -d /run/container/tmp/openldap-bootstrap.XXXXXX)"
trap 'rm -rf "${BOOTSTRAP_TMP_DIR}"' EXIT

bootstrap_env() {
    local tmp_file

    tmp_file="$(mktemp -p "${BOOTSTRAP_TMP_DIR}")"

    for script in "${OPENLDAP_BOOTSTRAP_SCRIPTS_DIR}"/*.sh; do
        "${script}" "env" "${tmp_file}"
    done

    container log debug < "${tmp_file}"

    # shellcheck disable=SC1090
    source "${tmp_file}"
}

bootstrap_ldif() {
    local source_dir="$1"
    local tmp_file="$2"
    local tmp_dir
    local tmp

    tmp_dir=$(mktemp -d -p "${BOOTSTRAP_TMP_DIR}")

    for script in "${OPENLDAP_BOOTSTRAP_SCRIPTS_DIR}"/*.sh; do
        "${script}" "ldif" "${source_dir}" "${tmp_dir}"
    done

    local prev_group=""
    local filename prefix group
    while IFS= read -r file; do

        container log debug "Adding ${file} ..."

        filename=$(basename "${file}")

        if [[ "${filename}" =~ ^([0-9]+)- ]]; then
            prefix="${BASH_REMATCH[1]}"
            group="n:$((10#${prefix} / 10))"
        else
            group="f:${filename}"
        fi

        # group files by tens with no empty lines within a group.
        # add a blank line between each group (e.g., between 49 and 50).
        if [ -n "${prev_group}" ] && [ "${group}" != "${prev_group}" ]; then
            echo >> "${tmp_file}" # add empty line
        fi

        # remove leading and trailing empty lines
        tmp=$(mktemp -p "${BOOTSTRAP_TMP_DIR}")
        awk '
        { lines[NR] = $0 }
        $0 ~ /[^[:space:]]/ {
            if (!first) first = NR
            last = NR
        }
        END {
            if (first) for (i = first; i <= last; i++) print lines[i]
        }
        ' "${file}" > "${tmp}"

        mv -v "${tmp}" "${file}" 2>&1 | container log debug

        cat "${file}" >> "${tmp_file}"

        prev_group="${group}"

    done < <(find "${tmp_dir}" -type f -name "*.ldif" | sort -V)
}

bootstrap_database() {
    local source_dir="$1"
    local db_number="$2"
    local tmp_file

    tmp_file="$(mktemp -p "${BOOTSTRAP_TMP_DIR}")"

    bootstrap_ldif "${source_dir}" "${tmp_file}"

    container log debug < "${tmp_file}"

    slapadd -n "${db_number}" -F "${OPENLDAP_CONF_DIR}" -l "${tmp_file}" 2>&1 | container log debug
}

container log info "Setting bootstrapping environment variables ..."
bootstrap_env

container log info "Creating OpenLDAP config ..."
bootstrap_database "${OPENLDAP_BOOTSTRAP_LDIF_CONFIG_DIR}" 0

container log info "Adding OpenLDAP data ..."
bootstrap_database "${OPENLDAP_BOOTSTRAP_LDIF_DATA_DIR}" 1
