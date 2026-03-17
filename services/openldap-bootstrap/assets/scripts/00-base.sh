#!/bin/bash -e
# shellcheck disable=SC2034
# shellcheck disable=SC1091

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

set -o pipefail

check_args "$@"

TYPE="$1"

if [ "${TYPE}" = "env" ]; then
    ENV_FILE="$2"

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/password.sh"

    OPENLDAP_GROUP_GID=$(id -g)
    OPENLDAP_USER_UID=$(id -u)

    ensure_hashed_password OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED "config root"
    ensure_hashed_password OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED "database root"

    for module in ${OPENLDAP_BOOTSTRAP_MODULES}; do
        OPENLDAP_BOOTSTRAP_MODULES_LDIF+="olcModuleload: ${module}"$'\n'
    done

    for schema in ${OPENLDAP_BOOTSTRAP_SCHEMAS}; do
        OPENLDAP_BOOTSTRAP_SCHEMAS_LDIF+="$(cat "${OPENLDAP_SCHEMAS_DIR}/${schema}")"$'\n\n'
    done

    OPENLDAP_BOOTSTRAP_MONITOR_ENABLED=${OPENLDAP_BOOTSTRAP_MONITOR_ENABLED^^}

    OPENLDAP_BOOTSTRAP_ORGANIZATION_DC=$(get_dc "${OPENLDAP_BOOTSTRAP_SUFFIX}")

    prepare_env_file "${ENV_FILE}" OPENLDAP_GROUP_GID OPENLDAP_USER_UID OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_MODULES_LDIF OPENLDAP_BOOTSTRAP_SCHEMAS_LDIF OPENLDAP_BOOTSTRAP_MONITOR_ENABLED OPENLDAP_BOOTSTRAP_ORGANIZATION_DC

elif [ "${TYPE}" = "ldif" ]; then
    SOURCE_DIR="$2"
    OUTPUT_DIR="$3"

    prepare_ldif_files "${SOURCE_DIR}/base" "${OUTPUT_DIR}"
fi
