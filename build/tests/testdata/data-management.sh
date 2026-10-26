#!/bin/bash
# shellcheck disable=SC2153

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"
USER_DN="uid=alice,${TEST_USERS_DN}"
APP_ADMIN_DN="uid=alice-admin,${TEST_USERS_DN}"
GROUP_DN="cn=cloud-admins,${TEST_GROUPS_DN}"
SERVICE_DN="cn=other-service,${TEST_SERVICES_DN}"
OUTSIDE_DN="uid=outside,${TEST_SUFFIX}"
NEW_PASSWORD="Changed-passw0rd-2026"
NEXT_PASSWORD="Another-passw0rd-2026"

eventually has_entry "${URI}" "${TEST_SUFFIX}"

if [ "${TEST_MANAGEMENT_MODE}" = "disabled" ]; then
    for dn in "${TEST_USERS_DN}" "${TEST_GROUPS_DN}" "${TEST_SERVICES_DN}" "${TEST_MANAGEMENT_DN}"; do
        expect_rc 32 bind_search "${URI}" "${ADMIN_DN}" -b "${dn}" -s base dn
    done
    ok 'tree and management are disabled by default'
    exit 0
fi

for dn in "${TEST_USERS_DN}" "${TEST_GROUPS_DN}" "${TEST_SERVICES_DN}"; do
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${dn}" -s base objectClass
    expect_output '^objectClass: organizationalUnit$'
done

if [ "${TEST_MANAGEMENT_MODE}" = "tree" ]; then
    expect_rc 32 bind_search "${URI}" "${ADMIN_DN}" -b "${TEST_MANAGEMENT_DN}" -s base dn
    ok 'tree creation does not enable the management account'
    exit 0
fi

expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${TEST_MANAGEMENT_DN}" -s base objectClass userPassword
expect_output '^objectClass: simpleSecurityObject$'
expect_output '^userPassword:'
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}"

for dn in "${USER_DN}" "${APP_ADMIN_DN}" "${OUTSIDE_DN}"; do
    uid="${dn%%,*}"
    expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${dn}
objectClass: inetOrgPerson
uid: ${uid#uid=}
cn: Test User
sn: User
displayName: Test User
mail: ${uid#uid=}@example.org
userPassword: ${TEST_PASSWORD}
LDIF
done

expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ${GROUP_DN}
objectClass: groupOfNames
cn: cloud-admins
member: ${APP_ADMIN_DN}

dn: ${SERVICE_DN}
objectClass: organizationalRole
objectClass: simpleSecurityObject
cn: other-service
userPassword: ${TEST_PASSWORD}
LDIF

# Searches use the same user/group scope and attributes as Authelia.
expect_rc 0 bind_search "${URI}" "${TEST_MANAGEMENT_DN}" -b "${TEST_SUFFIX}" \
    '(&(uid=alice)(objectClass=inetOrgPerson))' uid displayName mail userPassword
expect_output "^dn: ${USER_DN}$"
expect_output '^displayName: Test User$'
expect_output '^mail: alice@example.org$'
expect_no_output '^userPassword:'
expect_rc 0 bind_search "${URI}" "${TEST_MANAGEMENT_DN}" -b "${TEST_GROUPS_DN}" \
    "(&(member=${APP_ADMIN_DN})(objectClass=groupOfNames))" cn member
expect_output '^cn: cloud-admins$'
expect_output "^member: ${APP_ADMIN_DN}$"
ok 'management can read user profiles and group memberships'

# An extended operation hashes server-side, including when ppolicy is disabled.
# Application administrators are ordinary users for password-reset permissions.
for dn in "${USER_DN}" "${APP_ADMIN_DN}"; do
    expect_rc 0 ldappasswd -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${dn}"
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${dn}" -w "${NEW_PASSWORD}"
    expect_rc 49 ldapwhoami -x -H "${URI}" -D "${dn}" -w "${TEST_PASSWORD}"
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${dn}" -s base userPassword
    expect_output '^userPassword:: '
done
ok 'management resets ordinary and application-admin passwords without the old password'

if [ "${TEST_MANAGEMENT_MODE}" = "policy" ]; then
    # Authelia's standard LDAP Modify also needs to work with pwdSafeModify=TRUE.
    expect_rc 0 bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: userPassword
userPassword: ${NEXT_PASSWORD}
LDIF
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${USER_DN}" -w "${NEXT_PASSWORD}"
    expect_rc 0 bind_search "${URI}" "${ADMIN_DN}" -b "${USER_DN}" -s base userPassword pwdHistory
    expect_output '^userPassword:: '
    expect_output '^pwdHistory:'
    expect_rc 0 bind_search "${URI}" "${TEST_MANAGEMENT_DN}" -b "${USER_DN}" -s base userPassword pwdHistory
    expect_no_output '^(userPassword|pwdHistory):'
    expect_rc 0 bind_search "${URI}" "cn=readonly,${TEST_SUFFIX}" -b "${USER_DN}" -s base cn pwdHistory
    expect_no_output '^pwdHistory:'
    expect_fail ldappasswd -x -H "${URI}" -D "cn=readonly,${TEST_SUFFIX}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${USER_DN}"
    expect_fail ldappasswd -x -H "${URI}" -D "${APP_ADMIN_DN}" -w "${NEW_PASSWORD}" -a "${NEW_PASSWORD}" -s short
    expect_output 'quality|too short|Constraint violation'
    ok 'policy-enabled LDAP Modify hashes passwords and keeps history private'
fi

# Write-only password access must not even permit comparison of stored hashes.
expect_rc 50 ldapcompare -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" "${USER_DN}" "userPassword:${NEW_PASSWORD}"

expect_fail bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" <<LDIF
dn: ${USER_DN}
changetype: modify
replace: mail
mail: takeover@example.org
LDIF
expect_fail bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" <<LDIF
dn: ${GROUP_DN}
changetype: modify
add: member
member: ${USER_DN}
LDIF

expect_fail bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" -a <<LDIF
dn: uid=forbidden,${TEST_USERS_DN}
objectClass: inetOrgPerson
uid: forbidden
cn: forbidden
sn: forbidden
LDIF
expect_fail bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" -a <<LDIF
dn: cn=forbidden,${TEST_GROUPS_DN}
objectClass: groupOfNames
cn: forbidden
member: ${USER_DN}
LDIF
expect_fail ldapdelete -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" "${USER_DN}"
expect_fail ldapdelete -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" "${GROUP_DN}"
expect_fail ldapmodrdn -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" "${USER_DN}" uid=renamed
ok 'management cannot edit profiles, memberships, create, delete or rename entries'

for dn in "${SERVICE_DN}" "${TEST_MANAGEMENT_DN}" "${OUTSIDE_DN}"; do
    expect_rc 32 bind_search "${URI}" "${TEST_MANAGEMENT_DN}" -b "${dn}" -s base '*' '+'
    expect_fail ldappasswd -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${dn}"
    expect_rc 0 ldapwhoami -x -H "${URI}" -D "${dn}" -w "${TEST_PASSWORD}"
done
expect_fail bind_modify "${URI}" "${TEST_MANAGEMENT_DN}" <<LDIF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: ${NEW_PASSWORD}
LDIF
expect_fail ldappasswd -x -H "${URI}" -D "${TEST_MANAGEMENT_DN}" -w "${TEST_PASSWORD}" -s "${NEW_PASSWORD}" "${ADMIN_DN}"
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${ADMIN_DN}" -w "${TEST_PASSWORD}"
ok 'service accounts, entries outside users/groups and LDAP configuration remain protected'

expect_rc 0 ldappasswd -x -H "${URI}" -D "${APP_ADMIN_DN}" -w "${NEW_PASSWORD}" -a "${NEW_PASSWORD}" -s "${NEXT_PASSWORD}"
expect_rc 0 ldapwhoami -x -H "${URI}" -D "${APP_ADMIN_DN}" -w "${NEXT_PASSWORD}"
ok 'normal self-service password changes remain available'
