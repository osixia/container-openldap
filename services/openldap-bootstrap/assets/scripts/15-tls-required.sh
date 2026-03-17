#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_TLS_REQUIRED}" = "true" ]; then

    # shellcheck disable=SC1091
    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        if [ "${OPENLDAP_BOOTSTRAP_TLS}" = "true" ]; then
            container logger warning "tls-required is enabled but tls is not"
        fi

        prepare_ldif_files "${SOURCE_DIR}/tls-required" "${OUTPUT_DIR}"
    fi

fi
