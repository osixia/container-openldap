#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

echo "${OPENLDAP_CRON_JOB}" > "/etc/crontabs/ldap"
