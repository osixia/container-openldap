#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

usage() {
    echo "Usage: openldap-ctl validate-ldif file-or-directory [file-or-directory ...]"
}

if [ "$#" -eq 1 ] && { [ "$1" = --help ] || [ "$1" = -h ]; }; then
    usage
    exit 0
fi

if [ "$#" -eq 0 ]; then
    usage
    container log fatal "At least one LDIF file or directory is required"
fi

if [ ! -f "${OPENLDAP_CONF_DIR}/cn=config.ldif" ]; then
    container log fatal "OpenLDAP configuration is not initialized in ${OPENLDAP_CONF_DIR}"
fi

LDIF_FILES=()
LDIF_LIST_FILE=$(mktemp /run/container/tmp/openldap-validate.XXXXXX)
trap 'rm -f "${LDIF_LIST_FILE}"' EXIT

for path in "$@"; do
    if [ -d "${path}" ]; then
        # Prefix relative paths so find never interprets them as expressions.
        if [[ "${path}" != /* ]]; then
            path="./${path}"
        fi
        # Follow projected-volume symlinks, but skip hidden revision directories
        # to avoid validating their entries twice. Keep traversal errors fatal.
        find -L "${path}" -mindepth 1 -name '.*' -prune -o \
            -type f -name '*.ldif' -print0 | sort -zV > "${LDIF_LIST_FILE}"
        if [ ! -s "${LDIF_LIST_FILE}" ]; then
            container log fatal "No LDIF files found in directory: ${path}"
        fi
        while IFS= read -r -d '' file; do
            LDIF_FILES+=("${file}")
        done < "${LDIF_LIST_FILE}"
    elif [ -f "${path}" ] && [ -r "${path}" ]; then
        LDIF_FILES+=("${path}")
    else
        container log fatal "Path must be a readable LDIF file or directory: ${path}"
    fi
done

FAILED=false
for file in "${LDIF_FILES[@]}"; do
    # Dry-run mode skips database writes; value-check also validates attribute syntax.
    if slapadd -u -o value-check=yes -F "${OPENLDAP_CONF_DIR}" -n 1 -l "${file}"; then
        container log info "LDIF validation succeeded: ${file}"
    else
        container log error "LDIF validation failed: ${file}"
        FAILED=true
    fi
done

if [ "${FAILED}" = true ]; then
    container log fatal "One or more LDIF files failed validation"
fi
