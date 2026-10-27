#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"
POLICY_DN="cn=default,ou=policies,${TEST_SUFFIX}"
USER_DN="uid=delay-user,${TEST_SUFFIX}"
OTHER_DN="uid=other-user,${TEST_SUFFIX}"

eventually has_entry "${URI}" "${POLICY_DN}"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${POLICY_DN}" -s base pwdMinDelay pwdMaxDelay
if [ "${TEST_PPOLICY_DELAY_MODE}" = default ]; then
    expect_output '^pwdMinDelay: 0$'
    expect_output '^pwdMaxDelay: 0$'
else
    expect_output '^pwdMinDelay: 2$'
    expect_output '^pwdMaxDelay: 4$'
fi

for user in delay-user other-user; do
    expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: uid=${user},${TEST_SUFFIX}
objectClass: inetOrgPerson
uid: ${user}
cn: ${user}
sn: User
userPassword: ${TEST_PASSWORD}
LDIF
done

timestamp_epoch() {
    local stamp="$1"
    date -u -d "${stamp:0:4}-${stamp:4:2}-${stamp:6:2} ${stamp:8:2}:${stamp:10:2}:${stamp:12:2}" +%s
}

check_delay() {
    local expected="$1"
    local failure_time lockout_end
    expect_rc 49 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w incorrect-password
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdFailureTime pwdAccountTmpLockoutEnd
    failure_time=$(sed -n 's/^pwdFailureTime: //p' "${OUTPUT_FILE}" | sort | tail -1)
    lockout_end=$(sed -n 's/^pwdAccountTmpLockoutEnd: //p' "${OUTPUT_FILE}")
    [ -n "${failure_time}" ] && [ -n "${lockout_end}" ] || fail 'missing failure or lockout timestamp'
    [ "$(( $(timestamp_epoch "${lockout_end}") - $(timestamp_epoch "${failure_time}") ))" -eq "${expected}" ] || fail "expected ${expected}-second lockout"
    expect_rc 49 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${TEST_PASSWORD}"
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${OTHER_DN}" -w "${TEST_PASSWORD}"
}

expire_delay() {
    # Expire only the temporary lockout, preserving the failure history for progression.
    expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -e relax <<LDIF
dn: ${USER_DN}
changetype: modify
replace: pwdAccountTmpLockoutEnd
pwdAccountTmpLockoutEnd: 20000101000000Z
LDIF
}

if [ "${TEST_PPOLICY_DELAY_MODE}" = default ]; then
    expect_rc 49 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w incorrect-password
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdAccountTmpLockoutEnd
    expect_no_output '^pwdAccountTmpLockoutEnd:'
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${TEST_PASSWORD}"
    ok 'progressive lockouts are disabled by default'
    exit 0
fi

check_delay 2
expire_delay

if [ "${TEST_PPOLICY_DELAY_MODE}" = threshold ]; then
    expect_rc 49 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w incorrect-password
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdAccountLockedTime
    expect_output '^pwdAccountLockedTime: [0-9]{14}Z$'
    expect_rc 49 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${TEST_PASSWORD}"
    ok 'the fixed lockout still applies when pwdMaxFailure is reached'
    exit 0
fi

check_delay 4
expire_delay
check_delay 4
expire_delay
ok 'per-account lockouts double and stop at the configured maximum'

expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${TEST_PASSWORD}"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdFailureTime
expect_no_output '^pwdFailureTime:'
check_delay 2
ok 'successful authentication clears failures and resets the progression'
