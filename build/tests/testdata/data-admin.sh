#!/bin/bash
# shellcheck disable=SC2153

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"
DIRECTORY_ADMIN_DN="${TEST_DIRECTORY_ADMIN_DN}"
USER_DN="uid=alice,${TEST_USERS_DN}"
RENAMED_DN="uid=alice-renamed,${TEST_USERS_DN}"
GROUP_DN="cn=team,${TEST_GROUPS_DN}"
RENAMED_GROUP_DN="cn=renamed-team,${TEST_GROUPS_DN}"
SERVICE_DN="cn=other-service,${TEST_SERVICES_DN}"
OUTSIDE_DN="cn=outside,${TEST_SUFFIX}"
NEW_PASSWORD="Changed-passw0rd-2026"

eventually has_entry "${URI}" "${TEST_SUFFIX}"

if [ "${TEST_ADMIN_MODE}" = "disabled" ]; then
    expect_rc 32 bind_search "${URI}" "${ADMIN_DN}" -b "${DIRECTORY_ADMIN_DN}" -s base dn
    expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" -b 'olcDatabase={1}mdb,cn=config' -s base olcAccess
    expect_no_output "${DIRECTORY_ADMIN_DN}"
    ok 'directory administrator and its ACLs are disabled by default'
    exit 0
fi

expect_rc 0 ldapwhoami -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}"
expect_rc 0 bind_search "${URI}" "${DIRECTORY_ADMIN_DN}" -b "${DIRECTORY_ADMIN_DN}" -s base objectClass cn entryUUID userPassword
expect_output '^objectClass: organizationalRole$'
expect_output '^objectClass: simpleSecurityObject$'
expect_output '^entryUUID:'
expect_no_output '^userPassword:'
ok 'directory administrator can bind and read its real entry and identifier'

expect_rc 0 bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" -a <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
uid: alice
cn: Alice
sn: User
displayName: Alice User
mail: alice@example.org
userPassword: ${TEST_PASSWORD_HASHED}

dn: ${GROUP_DN}
objectClass: groupOfNames
cn: team
member: ${USER_DN}
LDIF
expect_rc 0 bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: mail
mail: updated@example.org

dn: ${GROUP_DN}
changetype: modify
replace: description
description: Updated by directory administrator
LDIF
expect_rc 0 bind_search "${URI}" "${DIRECTORY_ADMIN_DN}" -b "${USER_DN}" -s base mail userPassword
expect_output '^mail: updated@example.org$'
expect_no_output '^userPassword:'
expect_rc 0 bind_search "${URI}" "${DIRECTORY_ADMIN_DN}" -b "${GROUP_DN}" -s base description member
expect_output '^description: Updated by directory administrator$'
expect_output "^member: ${USER_DN}$"
expect_rc 50 ldapcompare -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" "${USER_DN}" "userPassword:${TEST_PASSWORD_HASHED}"
ok 'directory administrator creates and edits users/groups without hash read/compare'

expect_rc 0 ldappasswd -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${USER_DN}"
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${NEW_PASSWORD}"
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base userPassword
expect_output '^userPassword:: '

if [ "${TEST_ADMIN_MODE}" = "policy" ]; then
    expect_rc 0 bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: userPassword
userPassword: short
LDIF
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w short
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base pwdHistory
    expect_output '^pwdHistory:'
    expect_rc 0 bind_search "${URI}" "${DIRECTORY_ADMIN_DN}" -b "${USER_DN}" -s base userPassword pwdHistory
    expect_no_output '^(userPassword|pwdHistory):'
    expect_fail bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
delete: pwdHistory
LDIF
    expect_rc 0 bind_search "${URI}" "cn=readonly,${TEST_SUFFIX}" -b "${USER_DN}" -s base cn pwdHistory
    expect_output '^cn: Alice$'
    expect_no_output '^pwdHistory:'
    ok 'policy resets bypass quality checks while password history stays protected'
fi

expect_rc 0 ldappasswd -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${USER_DN}"
expect_rc 0 bind_search "${URI}" "${TEST_MANAGEMENT_DN}" -b "${USER_DN}" -s base mail
expect_output '^mail: updated@example.org$'
expect_rc 50 bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: mail
mail: forbidden@example.org
LDIF
expect_rc 0 ldappasswd -x -H "${URI}" -D "${USER_DN}" -w "${NEW_PASSWORD}" -a "${NEW_PASSWORD}" -s "Another-passw0rd-2026"
ok 'management permissions and normal user password changes remain available'

for dn in "${SERVICE_DN}" "${OUTSIDE_DN}"; do
    cn="${dn%%,*}"
    expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${dn}
objectClass: organizationalRole
objectClass: simpleSecurityObject
cn: ${cn#cn=}
userPassword: ${TEST_PASSWORD_HASHED}
LDIF
done
for dn in "${SERVICE_DN}" "${OUTSIDE_DN}" "${TEST_MANAGEMENT_DN}"; do
    expect_rc 32 bind_search "${URI}" "${DIRECTORY_ADMIN_DN}" -b "${dn}" -s base '*' '+'
done
for dn in "${SERVICE_DN}" "${OUTSIDE_DN}" "${TEST_MANAGEMENT_DN}" "${DIRECTORY_ADMIN_DN}"; do
    expect_fail ldappasswd -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${dn}"
    expect_fail bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" <<LDIF
dn: ${dn}
changetype: modify
replace: description
description: Forbidden change
LDIF
    expect_fail ldapdelete -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" "${dn}"
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${dn}" -w "${TEST_PASSWORD}"
done
expect_fail bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" -a <<LDIF
dn: cn=forbidden,${TEST_SERVICES_DN}
objectClass: organizationalRole
cn: forbidden
LDIF
expect_fail ldapmodrdn -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" -r -s "${TEST_SERVICES_DN}" "${USER_DN}" uid=escaped
expect_fail ldapmodrdn -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" "${DIRECTORY_ADMIN_DN}" cn=renamed-admin
expect_rc 32 bind_search "${URI}" "${DIRECTORY_ADMIN_DN}" -b cn=config -s base '*'
expect_rc 50 bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" <<LDIF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: forbidden
LDIF
ok 'administrator cannot change services, its own account, outside entries or configuration'

expect_rc 0 ldapmodrdn -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" -r "${USER_DN}" uid=alice-renamed
expect_rc 0 ldapmodrdn -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" -r "${GROUP_DN}" cn=renamed-team
expect_rc 0 bind_modify "${URI}" "${DIRECTORY_ADMIN_DN}" <<LDIF
dn: ${RENAMED_GROUP_DN}
changetype: modify
replace: member
member: ${RENAMED_DN}
LDIF
expect_rc 0 ldapdelete -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" "${RENAMED_GROUP_DN}"
expect_rc 0 ldapdelete -x -H "${URI}" -D "${DIRECTORY_ADMIN_DN}" -w "${TEST_PASSWORD}" "${RENAMED_DN}"
expect_rc 32 bind_search "${URI}" "${ADMIN_DN}" -b "${RENAMED_DN}" -s base dn
expect_rc 32 bind_search "${URI}" "${ADMIN_DN}" -b "${RENAMED_GROUP_DN}" -s base dn
expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" -b cn=config -s base dn
expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${SERVICE_DN}" -s base userPassword
expect_output '^userPassword:'
ok 'administrator renames/deletes users and groups; data/config root access stays intact'
