#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC1091

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

check_args "$@"

TYPE="$1"

if [ "${TYPE}" = "env" ]; then
    ENV_FILE="$2"

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/password.sh"

    OPENLDAP_GROUP_GID=$(id -g)
    OPENLDAP_USER_UID=$(id -u)

    ensure_hashed_password OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED "config root"
    ensure_hashed_password OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED "database root"

    auditlog_module=false
    for module in ${OPENLDAP_BOOTSTRAP_MODULES}; do
        OPENLDAP_BOOTSTRAP_MODULES_LDIF+="olcModuleload: ${module}"$'\n'
        case "${module##*/}" in
            auditlog|auditlog.so|auditlog.la) auditlog_module=true ;;
        esac
    done

    if [ "${OPENLDAP_BOOTSTRAP_AUDITLOG_ENABLED}" = "true" ] && [ "${auditlog_module}" = "false" ]; then
        OPENLDAP_BOOTSTRAP_MODULES_LDIF+="olcModuleload: auditlog.so"$'\n'
    fi

    # schemas are included by path instead of by content: large schemas (e.g. msuser.ldif)
    # exceed the kernel size limit of a single environment variable and make every
    # following command fail with "Argument list too long"
    for schema in ${OPENLDAP_BOOTSTRAP_SCHEMAS}; do
        if [ ! -f "${OPENLDAP_SCHEMAS_DIR}/${schema}" ]; then
            container log fatal "Schema ${schema} not found in ${OPENLDAP_SCHEMAS_DIR}"
        fi
        OPENLDAP_BOOTSTRAP_SCHEMAS_LDIF+="include: file://${OPENLDAP_SCHEMAS_DIR}/${schema}"$'\n'
    done

    OPENLDAP_BOOTSTRAP_MONITOR_ENABLED=${OPENLDAP_BOOTSTRAP_MONITOR_ENABLED^^}
    OPENLDAP_BOOTSTRAP_DATA_LAST_BIND=${OPENLDAP_BOOTSTRAP_DATA_LAST_BIND^^}

    OPENLDAP_BOOTSTRAP_ORGANIZATION_DC=$(get_dn_attr dc "${OPENLDAP_BOOTSTRAP_SUFFIX}")

    if [ -z "${OPENLDAP_BOOTSTRAP_ORGANIZATION_DC}" ]; then
        container log fatal "OPENLDAP_BOOTSTRAP_SUFFIX must start with dc= (got ${OPENLDAP_BOOTSTRAP_SUFFIX})"
    fi

    prepare_env_file "${ENV_FILE}" OPENLDAP_GROUP_GID OPENLDAP_USER_UID OPENLDAP_BOOTSTRAP_CONFIG_ROOT_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_DATA_ROOT_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_MODULES_LDIF OPENLDAP_BOOTSTRAP_SCHEMAS_LDIF OPENLDAP_BOOTSTRAP_MONITOR_ENABLED OPENLDAP_BOOTSTRAP_DATA_LAST_BIND OPENLDAP_BOOTSTRAP_ORGANIZATION_DC

elif [ "${TYPE}" = "ldif" ]; then
    SOURCE_DIR="$2"
    OUTPUT_DIR="$3"

    prepare_ldif_files "${SOURCE_DIR}/base" "${OUTPUT_DIR}"
fi
