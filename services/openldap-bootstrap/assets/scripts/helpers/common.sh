#!/bin/bash -e

set -o pipefail

check_args() {
    if [ "$1" = "ldif" ]; then
        if [ "$#" -ne 3 ]; then
            container logger fatal "Expected 3 arguments, got $#"
        fi
    elif [ "$1" = "env" ]; then
        if [ "$#" -ne 2 ]; then
            container logger fatal "Expected 2 arguments, got $#"
        fi
    else
        container logger fatal "Type must be env or ldif: got $1"
    fi
}

prepare_env_file() {
    local env_file=$1
    shift

    for var in "$@"; do
        printf 'export %s=%q\n' "${var}" "${!var}" >> "${env_file}"
    done
}

prepare_ldif_files() {

    if [ "$#" -ne 2 ]; then
        container logger fatal "Expected 2 arguments, got $#"
    fi

    local source_dir="$1"
    local output_dir="$2"

    if [ ! -d "${source_dir}" ]; then
        container logger warning "Directory not found: ${source_dir}"
        return 0
    fi

    container logger info "Load ${source_dir} LDIFs ..."

    container logger debug "Converting templates to LDIFs in ${source_dir} ..."
    container envsubst templates --quiet "${source_dir}"

    while IFS= read -r file; do
        cp -frav "${file}" "${output_dir}" 2>&1 | container logger debug
    done < <(find "${source_dir}" -type f -name "*.ldif" | sort)

}

get_dc() {
    echo "${1#*dc=}" | cut -d, -f1
}

get_cn() {
    echo "$1" | sed -n 's/^cn=\([^,]*\).*/\1/p'
}
