#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"
USER_DN="uid=lastbind-user,${TEST_SUFFIX}"

eventually has_entry "${URI}" "${TEST_SUFFIX}"
expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" \
    -b 'olcDatabase={1}mdb,cn=config' -s base olcLastBind olcLastBindPrecision

if [ "${TEST_LAST_BIND_MODE}" = "default" ]; then
    expect_output '^olcLastBind: FALSE$'
else
    expect_output '^olcLastBind: TRUE$'
fi
if [ "${TEST_LAST_BIND_MODE}" = "precise" ]; then
    expect_output '^olcLastBindPrecision: 0$'
else
    expect_output '^olcLastBindPrecision: 3600$'
fi

expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: lastbind-user
cn: Last Bind User
sn: User
userPassword: ${TEST_PASSWORD}
LDIF

expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdLastSuccess
expect_no_output '^pwdLastSuccess:'
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${TEST_PASSWORD}"

expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdLastSuccess
if [ "${TEST_LAST_BIND_MODE}" = "default" ]; then
    expect_no_output '^pwdLastSuccess:'
    ok 'successful binds are not tracked by default'
    exit 0
fi
expect_output '^pwdLastSuccess: [0-9]{14}Z$'
FIRST_SUCCESS=$(sed -n 's/^pwdLastSuccess: //p' "${OUTPUT_FILE}")

sleep 2
expect_rc 49 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w incorrect-password
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdLastSuccess
expect_output "^pwdLastSuccess: ${FIRST_SUCCESS}$"
ok 'failed binds do not update pwdLastSuccess'

expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${TEST_PASSWORD}"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdLastSuccess
expect_output '^pwdLastSuccess: [0-9]{14}Z$'
if [ "${TEST_LAST_BIND_MODE}" = "precise" ]; then
    expect_no_output "^pwdLastSuccess: ${FIRST_SUCCESS}$"
    ok 'zero precision records the next successful bind'
else
    expect_output "^pwdLastSuccess: ${FIRST_SUCCESS}$"
    ok "last bind (${TEST_LAST_BIND_MODE}) tracks success and throttles updates"
fi
