#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

set -o pipefail

# check required directories
if [ ! -d "${OPENLDAP_CONF_DIR}" ]; then 
    container log fatal "OpenLDAP config directory ${OPENLDAP_CONF_DIR} does not exist"
fi

if [ ! -d "${OPENLDAP_DATA_DIR}" ]; then 
    container log fatal "OpenLDAP data directory ${OPENLDAP_DATA_DIR} does not exist"
fi

# copy modules and schemas to OpenLDAP directories
container log debug "Copy modules to OpenLDAP modules directory ..."

if [ "${OPENLDAP_MODULES_DIR}" != "/usr/lib/openldap" ]; then
    cp -frav /usr/lib/openldap/. "${OPENLDAP_MODULES_DIR}" 2>&1 | container log debug
fi

cp -frav "${OPENLDAP_CUSTOM_MODULES_DIR}"/. "${OPENLDAP_MODULES_DIR}" 2>&1 | container log debug

container log debug "Copy schemas to OpenLDAP schemas directory ..."

if [ "${OPENLDAP_SCHEMAS_DIR}" != "/etc/openldap/schema" ]; then
    cp -frav /etc/openldap/schema/. "${OPENLDAP_SCHEMAS_DIR}" 2>&1 | container log debug
fi

cp -frav "${OPENLDAP_CUSTOM_SCHEMAS_DIR}"/. "${OPENLDAP_SCHEMAS_DIR}" 2>&1 | container log debug
