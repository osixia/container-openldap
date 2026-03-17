#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

if [ "$(id -u)" -ne 0 ]; then
    container log fatal "openldap-cron service must be run as root"
fi

echo "${OPENLDAP_CRON_JOB}" > "/etc/crontabs/ldap"

container log debug "Saving environment variables to /run/container/environment.sh ..."
container environment print --shell --clean > /run/container/environment.sh
