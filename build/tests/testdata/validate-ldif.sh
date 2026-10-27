#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

if [ "${TEST_VALIDATE_LDIF_MODE}" = online ] && [ "${1:-}" != --online ]; then
    printf 'bash %q --online\n' "$0" | container --bash
    exit 0
fi

if [ "${TEST_VALIDATE_LDIF_MODE}" = offline ]; then
    expect_rc 0 container --skip-process
else
    eventually has_entry ldap://127.0.0.1:3890 "${TEST_SUFFIX}"
    PID_BEFORE=$(cat /run/container/processes/openldap.pid)
fi

TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR:?}"' EXIT

snapshot() {
    find /etc/openldap/slapd.d -type f -exec sha256sum {} \; | sort
    sha256sum /var/lib/openldap/openldap-data/data.mdb
}
snapshot > "${TEST_DIR}/before"

USER_DN="uid=validate-only,${TEST_SUFFIX}"
cat > "${TEST_DIR}/valid entries.ldif" <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: validate-only
cn: Validate Only
sn: User
LDIF
chmod 400 "${TEST_DIR}/valid entries.ldif"
ln -s 'valid entries.ldif' "${TEST_DIR}/projected.ldif"
expect_rc 0 container run -- openldap-ctl validate-ldif "${TEST_DIR}/projected.ldif"
expect_output 'LDIF validation succeeded'

sed 's/validate-only/validate-second/g' "${TEST_DIR}/valid entries.ldif" > "${TEST_DIR}/second.ldif"
expect_rc 0 container run -- openldap-ctl validate-ldif "${TEST_DIR}/projected.ldif" "${TEST_DIR}/second.ldif"
expect_output 'LDIF validation succeeded: .*projected.ldif$'
expect_output 'LDIF validation succeeded: .*second.ldif$'

mkdir -p "${TEST_DIR}/directory/..revision" "${TEST_DIR}/directory/nested"
cat "${TEST_DIR}/second.ldif" > "${TEST_DIR}/directory/..revision/2-second.ldif"
cat "${TEST_DIR}/valid entries.ldif" > "${TEST_DIR}/directory/..revision/10-last.ldif"
cat "${TEST_DIR}/valid entries.ldif" > "${TEST_DIR}/directory/nested/entry with spaces.ldif"
ln -s ..revision "${TEST_DIR}/directory/..data"
ln -s ..data/2-second.ldif "${TEST_DIR}/directory/2-second.ldif"
ln -s ..data/10-last.ldif "${TEST_DIR}/directory/10-last.ldif"
printf 'invalid LDIF\n' > "${TEST_DIR}/directory/.hidden.ldif"
printf 'invalid LDIF\n' > "${TEST_DIR}/directory/ignored.ldif.template"
expect_rc 0 container run -- openldap-ctl validate-ldif "${TEST_DIR}/directory"
mapfile -t VALIDATED_FILES < <(sed -n 's/.*LDIF validation succeeded: //p' "${OUTPUT_FILE}")
[ "${#VALIDATED_FILES[@]}" -eq 3 ] || fail 'directory entries were skipped or validated twice'
[ "${VALIDATED_FILES[0]}" = "${TEST_DIR}/directory/2-second.ldif" ] || fail 'directory ordering is not numeric'
[ "${VALIDATED_FILES[1]}" = "${TEST_DIR}/directory/10-last.ldif" ] || fail 'directory ordering is not numeric'
[ "${VALIDATED_FILES[2]}" = "${TEST_DIR}/directory/nested/entry with spaces.ldif" ] || fail 'nested LDIF was not validated'
ok 'multiple files, recursive directories and projected-volume symlinks are supported'

sed '/^sn:/d' "${TEST_DIR}/valid entries.ldif" > "${TEST_DIR}/missing-sn.ldif"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/missing-sn.ldif"
expect_output 'requires attribute.*sn'

expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/projected.ldif" "${TEST_DIR}/missing-sn.ldif" "${TEST_DIR}/second.ldif"
expect_output 'LDIF validation succeeded: .*second.ldif$'
expect_output 'One or more LDIF files failed validation'
cat "${TEST_DIR}/missing-sn.ldif" > "${TEST_DIR}/directory/nested/invalid.ldif"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/directory"
expect_output 'requires attribute.*sn'

cat "${TEST_DIR}/valid entries.ldif" > "${TEST_DIR}/unknown-attribute.ldif"
printf 'unknownAttribute: value\n' >> "${TEST_DIR}/unknown-attribute.ldif"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/unknown-attribute.ldif"
expect_output 'attribute type undefined'

cat > "${TEST_DIR}/invalid-value.ldif" <<LDIF
dn: cn=role,${TEST_SUFFIX}
objectClass: organizationalRole
cn: role
roleOccupant: invalid-dn
LDIF
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/invalid-value.ldif"
expect_output 'smr_normalize roleOccupant|invalid.*syntax|value.*invalid'

sed 's/^dn:.*/dn: uid=validate-only,dc=outside/' "${TEST_DIR}/valid entries.ldif" > "${TEST_DIR}/wrong-suffix.ldif"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/wrong-suffix.ldif"
expect_output 'not configured to hold'

printf 'dn: %s\nchangetype: modify\nreplace: cn\ncn: Changed\n' "${USER_DN}" > "${TEST_DIR}/modify.ldif"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/modify.ldif"
printf 'dn: invalid-dn\nobjectClass: inetOrgPerson\n' > "${TEST_DIR}/invalid-dn.ldif"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/invalid-dn.ldif"
ok "LDIF validation (${TEST_VALIDATE_LDIF_MODE}) rejects invalid entries and change records"

expect_fail container run -- openldap-ctl validate-ldif
expect_output 'Usage: openldap-ctl validate-ldif'
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/projected.ldif" extra
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/missing.ldif"
mkdir "${TEST_DIR}/empty"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/empty"
expect_output 'No LDIF files found'
mkdir "${TEST_DIR}/loop"
ln -s . "${TEST_DIR}/loop/cycle"
expect_fail container run -- openldap-ctl validate-ldif "${TEST_DIR}/loop"
expect_fail env OPENLDAP_CONF_DIR="${TEST_DIR}" container run -- openldap-ctl validate-ldif "${TEST_DIR}/projected.ldif"
expect_output 'configuration is not initialized'
expect_rc 0 container run -- openldap-ctl validate-ldif --help

snapshot > "${TEST_DIR}/after"
cmp "${TEST_DIR}/before" "${TEST_DIR}/after" || fail 'validation changed config or data files'
[ -z "$(find /run/container/tmp -maxdepth 1 -name 'openldap-validate.*' -print)" ] || fail 'validation left a temporary file'

if [ "${TEST_VALIDATE_LDIF_MODE}" = online ]; then
    [ "$(cat /run/container/processes/openldap.pid)" = "${PID_BEFORE}" ] || fail 'validation restarted slapd'
    expect_rc 32 bind_search ldap://127.0.0.1:3890 "${ADMIN_DN}" -b "${USER_DN}" -s base dn
    expect_rc 0 bind_search ldap://127.0.0.1:3890 "${ADMIN_DN}" -b "${TEST_SUFFIX}" -s base dn
else
    [ ! -e /run/container/processes/openldap.pid ] || fail 'validation started slapd'
fi
ok "LDIF validation (${TEST_VALIDATE_LDIF_MODE}) leaves configuration, data and process state unchanged"
