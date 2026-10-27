#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR:?}"' EXIT

URI="ldap://${TEST_NODES}:3890"
USER_DN="uid=password-helper,${TEST_SUFFIX}"
# shellcheck disable=SC2016
PASSWORD=' Test " $HOME $(touch injected) `touch injected` \ end '
PASSWORD+="'"
PASSWORD_FILE="${TEST_DIR}/secret ' \$(touch injected)"
printf '%s' "${PASSWORD}" > "${PASSWORD_FILE}"
chmod 400 "${PASSWORD_FILE}"
ln -s "${PASSWORD_FILE}" "${TEST_DIR}/projected-secret"

eventually has_entry "${URI}" "${TEST_SUFFIX}"
expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: password-helper
cn: Password Helper
sn: User
LDIF

check_hash() {
    local hash="$1"
    local scheme="$2"
    [ "${hash#"${scheme}"}" != "${hash}" ] || fail "expected ${scheme} hash"
    expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: userPassword
userPassword: ${hash}
LDIF
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${PASSWORD}"
}

HASH=$(container run -- openldap-ctl password hash "${PASSWORD}")
check_hash "${HASH}" '{ARGON2}'

for mode in file stdin; do
    if [ "${mode}" = file ]; then
        container --log-level trace run -- openldap-ctl password hash --file "${TEST_DIR}/projected-secret" > "${TEST_DIR}/trace" 2>&1
    else
        container --log-level trace run -- openldap-ctl password hash --stdin < "${PASSWORD_FILE}" > "${TEST_DIR}/trace" 2>&1
    fi
    HASH=$(sed -n '/^{ARGON2}/p' "${TEST_DIR}/trace")
    check_hash "${HASH}" '{ARGON2}'
    if grep -Fq -- "${PASSWORD}" "${TEST_DIR}/trace"; then
        fail "${mode} password leaked in trace output"
    fi
    ok "${mode} hashes exact special characters without exposing the secret in trace output"
done

# A custom backend must receive a source path, never the file/stdin secret as an argument.
cat > "${TEST_DIR}/hasher.sh" <<'SH'
#!/bin/bash
set -euo pipefail
[ "$#" -eq 2 ] && [ "$1" = -T ] || exit 1
exec slappasswd -h '{SSHA}' "$@"
SH
export OPENLDAP_CTL_PASSWORD_HASH_CMD="bash '${TEST_DIR}/hasher.sh'"
HASH=$(container run -- openldap-ctl password hash --file "${PASSWORD_FILE}")
check_hash "${HASH}" '{SSHA}'
HASH=$(container run -- openldap-ctl password hash --stdin < "${PASSWORD_FILE}")
check_hash "${HASH}" '{SSHA}'
unset OPENLDAP_CTL_PASSWORD_HASH_CMD
ok 'custom hash commands receive the password source without secret arguments'

# Trailing newlines are part of the password for both input sources.
PASSWORD+=$'\n'
chmod 600 "${PASSWORD_FILE}"
printf '%s' "${PASSWORD}" > "${PASSWORD_FILE}"
HASH=$(container run -- openldap-ctl password hash --file "${PASSWORD_FILE}")
check_hash "${HASH}" '{ARGON2}'
HASH=$(container run -- openldap-ctl password hash --stdin < "${PASSWORD_FILE}")
check_hash "${HASH}" '{ARGON2}'
ok 'file and stdin preserve trailing newlines'

for PASSWORD in --file --stdin --; do
    HASH=$(container run -- openldap-ctl password hash -- "${PASSWORD}")
    check_hash "${HASH}" '{ARGON2}'
done
ok 'reserved option names can still be hashed as literal passwords'

expect_fail container run -- openldap-ctl password hash
expect_output 'Usage: openldap-ctl password hash'
expect_fail container run -- openldap-ctl password hash ''
expect_fail container run -- openldap-ctl password hash --file
expect_fail container run -- openldap-ctl password hash --file "${PASSWORD_FILE}" extra
expect_fail container run -- openldap-ctl password hash --stdin extra
expect_fail container run -- openldap-ctl password hash --file "${TEST_DIR}/missing"
expect_fail container run -- openldap-ctl password hash --file "${TEST_DIR}"
touch "${TEST_DIR}/empty"
expect_fail container run -- openldap-ctl password hash --file "${TEST_DIR}/empty"
expect_fail container run -- openldap-ctl password hash --stdin < "${TEST_DIR}/empty"
chmod 000 "${PASSWORD_FILE}"
expect_fail container run -- openldap-ctl password hash --file "${PASSWORD_FILE}"
ok 'invalid arguments and missing, unreadable or empty inputs are rejected'
