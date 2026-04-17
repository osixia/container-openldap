#!/bin/bash

# Sets LDAP* environment variables used by OpenLDAP client tools.
# Command-line flags passed to the tools take precedence over these defaults.

[ -n "${OPENLDAP_CTL_LDAP_URI}" ]    && export LDAPURI="${OPENLDAP_CTL_LDAP_URI}"
[ -n "${OPENLDAP_CTL_LDAP_BINDDN}" ] && export LDAPBINDDN="${OPENLDAP_CTL_LDAP_BINDDN}"
[ -n "${OPENLDAP_CTL_LDAP_BINDPW}" ] && export LDAPBINDPW="${OPENLDAP_CTL_LDAP_BINDPW}"

if [ "${OPENLDAP_BOOTSTRAP_TLS}" = "true" ] || [ "${OPENLDAP_BOOTSTRAP_TLS_REQUIRED}" = "true" ]; then
    [ -n "${OPENLDAP_BOOTSTRAP_TLS_CA_CERT}" ]  && export LDAPTLS_CACERT="${OPENLDAP_BOOTSTRAP_TLS_CA_CERT}"
    [ -n "${OPENLDAP_BOOTSTRAP_TLS_CERT}" ]     && export LDAPTLS_CERT="${OPENLDAP_BOOTSTRAP_TLS_CERT}"
    [ -n "${OPENLDAP_BOOTSTRAP_TLS_CERT_KEY}" ] && export LDAPTLS_KEY="${OPENLDAP_BOOTSTRAP_TLS_CERT_KEY}"
fi
