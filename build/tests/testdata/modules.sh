#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

if [ "${OPENLDAP_BOOTSTRAP_REPLICATION:-false}" = "true" ]; then
    OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS="ldap://$(hostname -f):3890 ldap://other:3890"
    export OPENLDAP_BOOTSTRAP_REPLICATION_HOSTS
fi

if container --log-level debug --skip-process > /tmp/openldap-modules-bootstrap.log 2>&1; then
    [ "${TEST_BOOTSTRAP_FAILS}" = "false" ] || fail 'missing explicit module was automatically added'
else
    if [ "${TEST_BOOTSTRAP_FAILS}" = "true" ]; then
        if ! grep -q 'str2ad(olcUniqueURI): attribute type undefined' /tmp/openldap-modules-bootstrap.log; then
            tail -60 /tmp/openldap-modules-bootstrap.log
            fail 'bootstrap did not fail for the missing unique module'
        fi
        ok 'explicit module lists do not add missing feature modules'
        exit 0
    fi
    tail -60 /tmp/openldap-modules-bootstrap.log
    exit 1
fi

expect_rc 0 container run -- slapcat -n 0 -a '(objectClass=olcModuleList)' -o ldif_wrap=no
ACTUAL_MODULES=$(sed -n 's/^olcModuleLoad: {[0-9]*}//p' "${OUTPUT_FILE}")
read -ra EXPECTED_MODULES <<< "${TEST_MODULES}"
EXPECTED_ORDER=$(printf '%s\n' "${EXPECTED_MODULES[@]}")
if [ "${ACTUAL_MODULES}" != "${EXPECTED_ORDER}" ]; then
    cat "${OUTPUT_FILE}" >&2
    fail "expected modules in order: ${TEST_MODULES}"
fi
ok "loaded modules in order: ${TEST_MODULES}"
