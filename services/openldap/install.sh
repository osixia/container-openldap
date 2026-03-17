#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

set -o pipefail

container logger info "Setting container files ownership to ldap user ..."
chown ldap:ldap -Rv /container 2>&1 | container logger debug

container logger info "Copy OpenLDAP container modules to /usr/lib/openldap ..."
cp -frav /container/services/openldap/assets/module/. /usr/lib/openldap 2>&1 | container logger debug

container logger info "Copy OpenLDAP container schemas to ..."
cp -frav /container/services/openldap/assets/schema/. /etc/openldap/schema 2>&1 | container logger debug

container logger info "Creating default config directory /etc/openldap/slapd.d ..."
mkdir -p /etc/openldap/slapd.d
chown ldap:ldap /etc/openldap/slapd.d
chmod 700 /etc/openldap/slapd.d

container logger info "Creating default backup directory /var/lib/openldap/openldap-backups ..."
mkdir -p /var/lib/openldap/openldap-backups
chown ldap:ldap /var/lib/openldap/openldap-backups
chmod 700 /var/lib/openldap/openldap-backups

container logger info "Creating default ldapi socket directory ..."
mkdir -p /var/lib/openldap/run
chown -R ldap:ldap /var/lib/openldap/run
