#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"
POLICY_DN="cn=default,ou=policies,${TEST_SUFFIX}"

eventually has_entry "${URI}" "${POLICY_DN}"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${POLICY_DN}" -s base pwdMaxIdle
if [ "${TEST_PPOLICY_IDLE_MODE}" = "default" ]; then
    expect_output '^pwdMaxIdle: 0$'
    IDLE_RC=0
else
    expect_output '^pwdMaxIdle: 3600$'
    IDLE_RC=49
fi

for user in active idle never-bound; do
    USER_DN="uid=${user},${TEST_SUFFIX}"
    expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: ${user}
cn: ${user}
sn: User
userPassword: ${TEST_PASSWORD}
LDIF
done

# A newly created account can authenticate and starts recording successful binds.
ACTIVE_DN="uid=active,${TEST_SUFFIX}"
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${ACTIVE_DN}" -w "${TEST_PASSWORD}"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${ACTIVE_DN}" -s base pwdLastSuccess
expect_output '^pwdLastSuccess: [0-9]{14}Z$'
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${ACTIVE_DN}" -w "${TEST_PASSWORD}"
ok 'new and active accounts can authenticate'

# Age operational timestamps with the relax control instead of waiting for expiry.
IDLE_DN="uid=idle,${TEST_SUFFIX}"
expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -e relax <<LDIF
dn: ${IDLE_DN}
changetype: modify
replace: pwdLastSuccess
pwdLastSuccess: 20000101000000Z
LDIF
expect_rc "${IDLE_RC}" ldapwhoami -x -H "${URI}" -D "${IDLE_DN}" -w "${TEST_PASSWORD}"

# Before the first successful bind, ppolicy falls back to pwdChangedTime.
NEVER_BOUND_DN="uid=never-bound,${TEST_SUFFIX}"
expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -e relax <<LDIF
dn: ${NEVER_BOUND_DN}
changetype: modify
replace: pwdChangedTime
pwdChangedTime: 20000101000000Z
LDIF
expect_rc "${IDLE_RC}" ldapwhoami -x -H "${URI}" -D "${NEVER_BOUND_DN}" -w "${TEST_PASSWORD}"
ok "inactivity limit (${TEST_PPOLICY_IDLE_MODE}) applies to idle and never-used accounts"
