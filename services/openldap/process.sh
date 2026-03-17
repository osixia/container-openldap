#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

ulimit -n "${OPENLDAP_NOFILE}"

exec slapd -h "${OPENLDAP_URLS}" -F "${OPENLDAP_CONF_DIR}" -d "${OPENLDAP_DEBUG_LEVEL}" "$@"
