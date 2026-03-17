#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC1091
# shellcheck disable=SC2153

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_REFINT}" = "true" ]; then

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "env" ]; then
        ENV_FILE="$2"

        for attribute in ${OPENLDAP_BOOTSTRAP_REFINT_ATTRIBUTES}; do
            OPENLDAP_BOOTSTRAP_REFINT_ATTRIBUTES_LDIF+="olcRefintAttribute: ${attribute}"$'\n'
        done

        prepare_env_file "${ENV_FILE}" OPENLDAP_BOOTSTRAP_REFINT_ATTRIBUTES_LDIF

    elif [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        prepare_ldif_files "${SOURCE_DIR}/refint" "${OUTPUT_DIR}"
    fi

fi
