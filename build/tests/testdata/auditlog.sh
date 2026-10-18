#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://127.0.0.1:3890"
USER_DN="uid=audit-user,${TEST_SUFFIX}"
RENAMED_DN="uid=audited-user,${TEST_SUFFIX}"
LOG_FILE="${TEST_AUDITLOG_FILE}"

if ! container --log-level debug --skip-process > /tmp/openldap-auditlog-bootstrap.log 2>&1; then
    tail -60 /tmp/openldap-auditlog-bootstrap.log
    exit 1
fi

start_ldap() {
    slapd -F /etc/openldap/slapd.d -h "${URI}" -d 0 > /tmp/openldap-auditlog-slapd.log 2>&1 &
    SLAPD_PID=$!
    eventually has_entry "${URI}" "${TEST_SUFFIX}"
}

stop_ldap() {
    kill "${SLAPD_PID}"
    wait "${SLAPD_PID}"
}

trap 'kill "${SLAPD_PID}" 2>/dev/null || true' EXIT
start_ldap

expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" \
    -b 'cn=module{0},cn=config' -s base olcModuleLoad
if [ "${TEST_AUDITLOG_MODE}" = "default" ]; then
    expect_no_output 'auditlog\.so'
else
    expect_output 'auditlog\.so$'
fi

expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" \
    -b 'olcDatabase={1}mdb,cn=config' '(objectClass=olcAuditLogConfig)' olcAuditlogFile
if [ "${TEST_AUDITLOG_MODE}" = "default" ]; then
    expect_no_output '^olcAuditlogFile:'
else
    expect_output "^olcAuditlogFile: \"?${LOG_FILE}\"?$"
fi

expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: audit-user
cn: Audit User
sn: User
LDIF

if [ "${TEST_AUDITLOG_MODE}" = "default" ]; then
    [ ! -e "${LOG_FILE}" ] || fail 'audit file created while disabled'
    ok 'auditlog is disabled by default'
    exit 0
fi

[ -s "${LOG_FILE}" ] || fail 'audit file is missing or empty'
grep -qE "^# add [0-9]+ ${TEST_SUFFIX} ${ADMIN_DN} " "${LOG_FILE}"
grep -qFx "dn: ${USER_DN}" "${LOG_FILE}"
ok "auditlog (${TEST_AUDITLOG_MODE}) records additions with the actor and target DN"

expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: description
description: Audited change
LDIF
grep -qE '^# modify ' "${LOG_FILE}"
grep -qFx 'description: Audited change' "${LOG_FILE}"

expect_rc 0 ldapmodrdn -x -H "${URI}" -D "${ADMIN_DN}" -w "${TEST_PASSWORD}" \
    -r "${USER_DN}" uid=audited-user
grep -qE '^# modrdn ' "${LOG_FILE}"
grep -qFx 'newrdn: uid=audited-user' "${LOG_FILE}"
ok 'auditlog records modifications and renames'

BEFORE=$(wc -c < "${LOG_FILE}")
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${RENAMED_DN}" -s base dn
expect_rc 68 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${RENAMED_DN}
objectClass: inetOrgPerson
uid: audited-user
cn: Duplicate
sn: User
LDIF
[ "$(wc -c < "${LOG_FILE}")" = "${BEFORE}" ] || fail 'reads or failed operations were audited'
ok 'auditlog only records successful writes'

mv "${LOG_FILE}" "${LOG_FILE}.1"
expect_rc 0 ldapdelete -x -H "${URI}" -D "${ADMIN_DN}" -w "${TEST_PASSWORD}" "${RENAMED_DN}"
grep -qE '^# delete ' "${LOG_FILE}"
grep -qFx "dn: ${RENAMED_DN}" "${LOG_FILE}"
[ "$(wc -c < "${LOG_FILE}.1")" = "${BEFORE}" ] || fail 'rotated log was modified'
ok 'auditlog recreates its file after rotation without restarting slapd'

BEFORE=$(wc -c < "${LOG_FILE}")
stop_ldap
start_ldap
expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: audit-user
cn: Audit User After Restart
sn: User
LDIF
grep -qE '^# delete ' "${LOG_FILE}"
grep -qFx 'cn: Audit User After Restart' "${LOG_FILE}"
[ "$(wc -c < "${LOG_FILE}")" -gt "${BEFORE}" ] || fail 'audit file was not appended after restart'
ok 'auditlog appends to the existing file after restart'
