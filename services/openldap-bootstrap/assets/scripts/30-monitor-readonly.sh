#!/bin/bash -e
# shellcheck disable=SC2034
# shellcheck disable=SC1091
# shellcheck disable=SC2153

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_MONITOR_READONLY}" = "true" ]; then

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "env" ]; then
        ENV_FILE="$2"

        source "/container/services/openldap-bootstrap/assets/scripts/helpers/password.sh"


        OPENLDAP_BOOTSTRAP_MONITOR_READONLY_CN=$(get_cn "${OPENLDAP_BOOTSTRAP_MONITOR_READONLY_DN}")

        ensure_hashed_password OPENLDAP_BOOTSTRAP_MONITOR_READONLY_PASSWORD_HASHED "monitor readonly user"

        prepare_env_file "${ENV_FILE}" OPENLDAP_BOOTSTRAP_MONITOR_READONLY_CN OPENLDAP_BOOTSTRAP_MONITOR_READONLY_PASSWORD_HASHED

    elif [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        prepare_ldif_files "${SOURCE_DIR}/monitor-readonly" "${OUTPUT_DIR}"
    fi

fi
