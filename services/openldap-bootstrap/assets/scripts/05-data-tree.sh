#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC1091
# shellcheck disable=SC2153

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_DATA_TREE}" = "true" ]; then

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "env" ]; then
        ENV_FILE="$2"

        OPENLDAP_BOOTSTRAP_DATA_TREE_USERS_OU=$(get_dn_attr ou "${OPENLDAP_BOOTSTRAP_DATA_TREE_USERS_DN}")
        OPENLDAP_BOOTSTRAP_DATA_TREE_GROUPS_OU=$(get_dn_attr ou "${OPENLDAP_BOOTSTRAP_DATA_TREE_GROUPS_DN}")
        OPENLDAP_BOOTSTRAP_DATA_TREE_SERVICES_OU=$(get_dn_attr ou "${OPENLDAP_BOOTSTRAP_DATA_TREE_SERVICES_DN}")

        prepare_env_file "${ENV_FILE}" OPENLDAP_BOOTSTRAP_DATA_TREE_USERS_OU OPENLDAP_BOOTSTRAP_DATA_TREE_GROUPS_OU OPENLDAP_BOOTSTRAP_DATA_TREE_SERVICES_OU

    elif [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        prepare_ldif_files "${SOURCE_DIR}/data-tree" "${OUTPUT_DIR}"
    fi

fi
