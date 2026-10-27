#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"
USER_DN="uid=refint-user,${TEST_SUFFIX}"
GROUP_DN="cn=refint-team,${TEST_SUFFIX}"

eventually has_entry "${URI}" "${TEST_SUFFIX}"
expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" \
    -b 'olcDatabase={1}mdb,cn=config' '(objectClass=olcRefintConfig)' olcRefintNothing

if [ "${TEST_REFINT_MODE}" != "create" ]; then
    expect_no_output '^olcRefintNothing:'
    expect_rc 32 bind_search "${URI}" "${ADMIN_DN}" -b "${TEST_NOTHING_DN}" -s base dn
    ok "refint (${TEST_REFINT_MODE}) leaves olcRefintNothing unset and creates no placeholder"
    exit 0
fi

expect_output "^olcRefintNothing: ${TEST_NOTHING_DN}$"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${TEST_NOTHING_DN}" -s base objectClass cn userPassword
expect_output '^objectClass: organizationalRole$'
expect_output "^cn: ${TEST_NOTHING_CN}$"
expect_no_output '^userPassword:'
ok "refint creates the configured role without a password"

expect_rc 49 bind_search "${URI}" "${TEST_NOTHING_DN}" -b "${TEST_NOTHING_DN}" -s base dn

expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: refint-user
cn: Refint User
sn: User

dn: ${GROUP_DN}
objectClass: groupOfNames
cn: refint-team
member: ${USER_DN}
LDIF

expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base memberOf
expect_output "^memberOf: ${GROUP_DN}$"
ok "real group members receive memberOf"

expect_rc 0 ldapdelete -x -H "${URI}" -D "${ADMIN_DN}" -w "${TEST_PASSWORD}" "${USER_DN}"
group_preserved() {
    bind_search "${URI}" "${ADMIN_DN}" -b "${GROUP_DN}" -s base member | grep -qi "^member: ${TEST_NOTHING_DN}$"
}
eventually group_preserved
ok "refint preserves a group after deletion of its last real member"
