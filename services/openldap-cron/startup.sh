#!/bin/bash -e

container logger debug "Creating ${OPENLDAP_CRON_DIR} ..."
mkdir -p "${OPENLDAP_CRON_DIR}"

OPENLDAP_CRON_DIR=$(dirname "${OPENLDAP_CRON_FILE}")

container logger debug "Creating ${OPENLDAP_CRON_DIR} ..."
mkdir -p "${OPENLDAP_CRON_DIR}"

container logger debug "Adding cron job to ${OPENLDAP_CRON_FILE} ..."
echo "${OPENLDAP_CRON_SCHEDULE} ${OPENLDAP_CRON_JOB}" > "${OPENLDAP_CRON_FILE}"

container envrionment export
