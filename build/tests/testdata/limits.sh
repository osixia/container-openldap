#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"

eventually has_entry "${URI}" "${TEST_SUFFIX}"
expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" -b cn=config -s base \
    olcWriteTimeout olcConnMaxPending olcConnMaxPendingAuth \
    olcSockbufMaxIncoming olcSockbufMaxIncomingAuth

if [ "${TEST_LIMITS_MODE}" = default ]; then
    expect_output '^olcWriteTimeout: 0$'
    expect_output '^olcConnMaxPending: 100$'
    expect_output '^olcConnMaxPendingAuth: 1000$'
    expect_output '^olcSockbufMaxIncoming: 262143$'
    expect_output '^olcSockbufMaxIncomingAuth: 4194303$'
else
    expect_output '^olcWriteTimeout: 5$'
    expect_output '^olcConnMaxPending: 10$'
    expect_output '^olcConnMaxPendingAuth: 20$'
    expect_output '^olcSockbufMaxIncoming: 1024$'
    expect_output '^olcSockbufMaxIncomingAuth: 2048$'
fi
ok "global limits (${TEST_LIMITS_MODE}) are loaded in cn=config"

# These filters match the root DSE while making each incoming request large enough
# to distinguish the anonymous and authenticated message size limits.
MEDIUM=$(printf '%1400s' '' | tr ' ' x)
LARGE=$(printf '%2800s' '' | tr ' ' x)
MEDIUM_FILTER="(|(objectClass=*)(description=${MEDIUM}))"
LARGE_FILTER="(|(objectClass=*)(description=${LARGE}))"

if [ "${TEST_LIMITS_MODE}" = default ]; then
    expect_rc 0 ldapsearch -LLL -x -H "${URI}" -b '' -s base "${LARGE_FILTER}" namingContexts
    expect_output '^namingContexts:'
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b '' -s base "${LARGE_FILTER}" namingContexts
    expect_output '^namingContexts:'
    ok 'native message size defaults allow ordinary LDAP requests'
    exit 0
fi

expect_rc 0 ldapsearch -LLL -x -H "${URI}" -b '' -s base '(objectClass=*)' namingContexts
expect_output '^namingContexts:'
expect_fail ldapsearch -LLL -x -H "${URI}" -b '' -s base "${MEDIUM_FILTER}" namingContexts
expect_output "Can't contact LDAP server"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b '' -s base "${MEDIUM_FILTER}" namingContexts
expect_output '^namingContexts:'
expect_fail bind_search "${URI}" "${ADMIN_DN}" -b '' -s base "${LARGE_FILTER}" namingContexts
expect_output "Can't contact LDAP server"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${TEST_SUFFIX}" -s base dn
expect_output '^dn:'
ok 'oversized messages close the offending connection and preserve normal access'
