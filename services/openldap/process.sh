#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

ulimit -n "${OPENLDAP_NOFILE}"

# determine the fully qualified domain name (FQDN) using hostname
# required to listen on the FQDN when replication is enabled
FQDN="$(/bin/hostname -f)"

exec /usr/sbin/slapd -h "ldap://${FQDN}:3890 ldaps://${FQDN}:6360 ldapi:///" -F "${OPENLDAP_CONF_DIR}" -d "${OPENLDAP_DEBUG_LEVEL}" "$@"
