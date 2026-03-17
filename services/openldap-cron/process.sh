#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

if [ "$(id -u)" -ne 0 ]; then
    container logger fatal "openldap-cron service must be run as root"
fi

exec crond -f "$@"
