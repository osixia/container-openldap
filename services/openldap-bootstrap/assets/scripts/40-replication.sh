#!/bin/bash -e
# shellcheck disable=SC2034
# shellcheck disable=SC1091
# shellcheck disable=SC2153

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

if [ "${OPENLDAP_BOOTSTRAP_REPLICATION}" = "true" ]; then

    source "/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh"

    check_args "$@"

    TYPE="$1"

    if [ "${TYPE}" = "env" ]; then
        ENV_FILE="$2"

        source "/container/services/openldap-bootstrap/assets/scripts/helpers/password.sh"

        # hosts
        current_fqdn="$(/bin/hostname -f)"
        current_host_id=0

        i=1
        for host in ${OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS}; do

            fqdn="${host#*://}" # remove protocol
            fqdn="${fqdn%%[:/]*}" # remove port

            if [ "${fqdn}" = "${current_fqdn}" ]; then
                current_host_id=$i
                host="ldap://${fqdn}:3890"
            else
                export OPENLDAP_BOOTSTRAP_REPLICATION_SYNC_REPL_PROVIDER="${host}"
            fi

            OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SERVER_IDS_LDIF+="olcServerID: $i ${host}"$'\n'
            ((i++))
        done

        if [ "${i}" -ne 3 ]; then
            container log fatal "OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS must contain exactly 2 hosts, got $((i - 1)) (${OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS})"
        fi

        if [ "${current_host_id}" -eq 0 ]; then
            container log fatal "Current host ${current_fqdn} not found in OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS=${OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS}"
        fi
        export OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL_RID="${current_host_id}00"
        export OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_RID="${current_host_id}01"

        # config readonly account
        OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_CN=$(get_cn "${OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_DN}")

        if [ -z "${OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD}" ]; then
            OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD=$(generate_password)
            container log warning "Generated config replicator user password: ${OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD}"
        fi
        export OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD

        OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD_HASHED=$(hash_password "${OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD}")

        # data readonly account
        OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_CN=$(get_cn "${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_DN}")

        if [ -z "${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD}" ]; then
            OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD=$(generate_password)
            container log warning "Generated data replicator user password: ${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD}"
        fi
        export OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD

        OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD_HASHED=$(hash_password "${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD}")

        OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL=$(container envsubst "${OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL_TEMPLATE}")
        OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL=$(container envsubst "${OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_TEMPLATE}")

        if [ "${OPENLDAP_BOOTSTRAP_REPLICATION_TLS}" = "true" ]; then
            OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL+=" ${OPENLDAP_BOOTSTRAP_REPLICATION_TLS_SYNC_REPL}"
            OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL+=" ${OPENLDAP_BOOTSTRAP_REPLICATION_TLS_SYNC_REPL}"
        fi

        prepare_env_file "${ENV_FILE}" OPENLDAP_BOOTSTRAP_REPLICATION_SYNC_REPL_PROVIDER OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SERVER_IDS_LDIF OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL_RID OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL_RID OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_CN OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_READONLY_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_CN OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD OPENLDAP_BOOTSTRAP_REPLICATION_DATA_READONLY_PASSWORD_HASHED OPENLDAP_BOOTSTRAP_REPLICATION_CONFIG_SYNC_REPL OPENLDAP_BOOTSTRAP_REPLICATION_DATA_SYNC_REPL

    elif [ "${TYPE}" = "ldif" ]; then
        SOURCE_DIR="$2"
        OUTPUT_DIR="$3"

        prepare_ldif_files "${SOURCE_DIR}/replication" "${OUTPUT_DIR}"
    fi
fi
