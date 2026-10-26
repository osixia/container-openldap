#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC1091
# shellcheck disable=SC2153

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT}" = "true" ]; then

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "env" ]; then
        ENV_FILE="$2"

        source "/container/services/openldap-bootstrap/assets/scripts/helpers/password.sh"

        OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_CN=$(get_dn_attr cn "${OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_DN}")

        ensure_hashed_password OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_PASSWORD_HASHED "database management user"

        OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_HIDDEN_ATTRIBUTES="userPassword,shadowLastChange"
        if [ "${OPENLDAP_BOOTSTRAP_PPOLICY}" = "true" ]; then
            OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_HIDDEN_ATTRIBUTES+=",pwdHistory"
        fi

        prepare_env_file "${ENV_FILE}" OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_CN OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_DATA_MANAGEMENT_HIDDEN_ATTRIBUTES

    elif [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        prepare_ldif_files "${SOURCE_DIR}/data-management" "${OUTPUT_DIR}"
    fi

fi
