#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

set -o pipefail

# skip bootstrapping if config or data directory is not empty
if [ -n "$(find "${OPENLDAP_CONF_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ] || \
   [ -n "$(find "${OPENLDAP_DATA_DIR}" -mindepth 1 -maxdepth 1 ! -name "lost+found" ! -name ".*")" ]; then
    container logger debug "Existing data detected in ${OPENLDAP_CONF_DIR} or ${OPENLDAP_DATA_DIR}"
    container logger info "Skipping OpenLDAP bootstrapping ..."
    return 0
fi

container logger info "Bootstrapping OpenLDAP ..."

bootstrap_env() {
    local tmp_file

    tmp_file="$(mktemp)"
    trap 'rm -f "${tmp_file}"' RETURN

    for script in "${OPENLDAP_BOOTSTRAP_SCRIPTS_DIR}"/*.sh; do
        "${script}" "env" "${tmp_file}"
    done

    container logger debug < "${tmp_file}"

    # shellcheck disable=SC1090
    source "${tmp_file}"
}

bootstrap_ldif() {
    local source_dir="$1"
    local tmp_file="$2"
    local tmp_dir

    tmp_dir=$(mktemp -d)
    trap 'rm -rf "${tmp_dir}"' RETURN

    for script in "${OPENLDAP_BOOTSTRAP_SCRIPTS_DIR}"/*.sh; do
        "${script}" "ldif" "${source_dir}" "${tmp_dir}"
    done

    local prev_group=""
    local filename prefix group
    for file in $(find "${tmp_dir}" -type f -name \*.ldif | sort); do

        container logger debug "Adding ${file} ..."
        
        filename=$(basename "${file}")
        prefix=${filename%%-*}
        group=$((10#${prefix} / 10))

        # group files by tens with no empty lines within a group.
        # add a blank line between each group (e.g., between 120 and 200).
        if [ -n "${prev_group}" ] && [ "${group}" -ne "${prev_group}" ]; then
            echo >> "${tmp_file}" # add empty line
        else
            # remove trailing empty lines
            tmp=$(mktemp)
            awk '
            { lines[NR] = $0 }
            $0 ~ /[^[:space:]]/ {
                if (!first) first = NR
                last = NR
            }
            END {
                for (i = first; i <= last; i++) print lines[i]
            }
            ' "${file}" > "${tmp}"

            mv "${tmp}" "${file}"
        fi

        cat "${file}" >> "${tmp_file}"

        prev_group="${group}"
    done
}

bootstrap_database() {
    local source_dir="$1"
    local db_number="$2"
    local tmp_file

    tmp_file="$(mktemp)"
    trap 'rm -f "${tmp_file}"' RETURN

    bootstrap_ldif "${source_dir}" "${tmp_file}"

    container logger debug < "${tmp_file}"

    slapadd -n "${db_number}" -F "${OPENLDAP_CONF_DIR}" -l "${tmp_file}" 2>&1 | container logger debug
}

container logger info "Setting bootstrapping environment variables ..."
bootstrap_env

container logger info "Creating OpenLDAP config ..."
bootstrap_database "${OPENLDAP_BOOTSTRAP_LDIF_CONFIG_DIR}" 0

container logger info "Adding OpenLDAP data ..."
bootstrap_database "${OPENLDAP_BOOTSTRAP_LDIF_DATA_DIR}" 1
