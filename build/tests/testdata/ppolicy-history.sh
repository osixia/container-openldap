#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

read -ra NODES <<< "${TEST_NODES}"
FIRST="ldap://${NODES[0]}:3890"
USER_DN="uid=history-user,${TEST_SUFFIX}"
OBSERVER_DN="uid=history-observer,${TEST_SUFFIX}"
READONLY_DN="cn=readonly,${TEST_SUFFIX}"
REPLICATOR_DN="cn=replicator,${TEST_SUFFIX}"
NEW_PASSWORD="Changed-passw0rd-2026"

eventually has_entry "${FIRST}" "${TEST_SUFFIX}"
for user in history-user history-observer; do
    expect_rc 0 bind_modify "${FIRST}" "${ADMIN_DN}" -a <<LDIF
dn: uid=${user},${TEST_SUFFIX}
objectClass: inetOrgPerson
uid: ${user}
cn: ${user}
sn: User
userPassword: ${TEST_PASSWORD}
LDIF
done

expect_rc 0 ldappasswd -x -H "${FIRST}" -D "${USER_DN}" -w "${TEST_PASSWORD}" -a "${TEST_PASSWORD}" -s "${NEW_PASSWORD}"
expect_rc 0 bind_search "${FIRST}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdHistory
expect_output '^pwdHistory:'
EXPECTED_HISTORY=$(sed -n '/^pwdHistory:/p' "${OUTPUT_FILE}" | sort)
ok 'a self-service password change creates history readable by the database administrator'

history_matches() {
    local actual
    actual=$(bind_search "$1" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdHistory | sed -n '/^pwdHistory:/p' | sort)
    [ "${actual}" = "${EXPECTED_HISTORY}" ]
}

for node in "${NODES[@]}"; do
    uri="ldap://${node}:3890"
    eventually history_matches "${uri}"
    eventually has_entry "${uri}" "${OBSERVER_DN}"

    expect_rc 0 bind_search "${uri}" "${READONLY_DN}" -b "${USER_DN}" -s base cn userPassword pwdHistory
    expect_output '^cn: history-user$'
    expect_no_output '^userPassword:'
    if [ "${TEST_HISTORY_READONLY_ACCESS:-false}" = "true" ]; then
        expect_output '^pwdHistory:'
    else
        expect_no_output '^pwdHistory:'
    fi

    expect_rc 0 bind_search "${uri}" "${OBSERVER_DN}" -b "${USER_DN}" -s base cn pwdHistory
    expect_output '^cn: history-user$'
    if [ "${TEST_HISTORY_CUSTOM:-false}" = "true" ]; then
        expect_output '^pwdHistory:'
    else
        expect_no_output '^pwdHistory:'
    fi

    expect_rc 0 ldapsearch -LLL -x -H "${uri}" -D "${USER_DN}" -w "${NEW_PASSWORD}" -b "${USER_DN}" -s base cn pwdHistory
    expect_output '^cn: history-user$'
    expect_no_output '^pwdHistory:'

    expect_rc 32 ldapsearch -LLL -x -H "${uri}" -b "${USER_DN}" -s base pwdHistory
    expect_no_output '^pwdHistory:'

    if [ "${TEST_HISTORY_REPLICATION}" = "true" ]; then
        expect_rc 0 bind_search "${uri}" "${REPLICATOR_DN}" -b "${USER_DN}" -s base pwdHistory
        expect_output '^pwdHistory:'
    fi

    expect_fail ldappasswd -x -H "${uri}" -D "${USER_DN}" -w "${NEW_PASSWORD}" -a "${NEW_PASSWORD}" -s "${TEST_PASSWORD}"
    expect_output 'history'
done
ok 'history access follows the readonly restriction, later custom grants and fragment overrides'
ok 'history remains hidden from its owner and anonymous users by default'
ok 'history is preserved across nodes and prevents password reuse'
