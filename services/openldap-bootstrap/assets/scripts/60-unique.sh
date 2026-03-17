#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC1091
# shellcheck disable=SC2153

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_UNIQUE}" = "true" ]; then

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "env" ]; then
        ENV_FILE="$2"

        for uri in ${OPENLDAP_BOOTSTRAP_UNIQUE_URIS}; do
            OPENLDAP_BOOTSTRAP_UNIQUE_URIS_LDIF+="olcUniqueURI: ${uri}"$'\n'
        done

        prepare_env_file "${ENV_FILE}" OPENLDAP_BOOTSTRAP_UNIQUE_URIS_LDIF

    elif [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        prepare_ldif_files "${SOURCE_DIR}/unique" "${OUTPUT_DIR}"
    fi

fi
