#!/bin/bash

set -euo pipefail

check_args() {
    if [ "$1" = "ldif" ]; then
        if [ "$#" -ne 3 ]; then
            container log fatal "Expected 3 arguments, got $#"
        fi
    elif [ "$1" = "env" ]; then
        if [ "$#" -ne 2 ]; then
            container log fatal "Expected 2 arguments, got $#"
        fi
    else
        container log fatal "Type must be env or ldif: got $1"
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
        container log fatal "Expected 2 arguments, got $#"
    fi

    local source_dir="$1"
    local output_dir="$2"
    local work_dir

    if [ ! -d "${source_dir}" ]; then
        container log debug "Directory not found: ${source_dir}"
        return 0
    fi

    container log info "Load ${source_dir} LDIFs ..."

    work_dir=$(mktemp -d "${output_dir}/.templates.XXXXXX")
    # output_dir is inside BOOTSTRAP_TMP_DIR, whose EXIT trap also cleans up
    # this working copy if any command below fails.

    # Dereference projected-volume symlinks and make read-only sources writable
    # only in the working copy.
    cp -RL "${source_dir}/." "${work_dir}"
    chmod -R u+rwX "${work_dir}"

    container log debug "Converting templates to LDIFs in ${work_dir} ..."
    container envsubst templates "${work_dir}" 2>&1 | container log debug

    while IFS= read -r file; do
        cp -frav "${file}" "${output_dir}" 2>&1 | container log debug
    done < <(find "${work_dir}" -type f -name "*.ldif" | sort -V)

    rm -rf "${work_dir:?}"
}

get_dn_attr() {
    local attr="$1"
    local dn="$2"
    sed -n "s/^${attr}=\([^,]*\).*/\1/p" <<< "$dn"
}
