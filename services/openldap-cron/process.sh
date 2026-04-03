#!/bin/bash -e

OPENLDAP_CRON_DIR=$(dirname "${OPENLDAP_CRON_FILE}")

exec crond -f -c "${OPENLDAP_CRON_DIR}" ${OPENLDAP_CRON_CMD_EXTRA_ARGS}
