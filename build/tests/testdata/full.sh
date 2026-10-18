#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

read -ra NODES <<< "${TEST_NODES}"

PEOPLE_DN="ou=people,${TEST_SUFFIX}"
GROUPS_DN="ou=groups,${TEST_SUFFIX}"
ALICE_DN="uid=alice,${PEOPLE_DN}"
BOB_DN="uid=bob,${PEOPLE_DN}"
CAROL_DN="uid=carol,${PEOPLE_DN}"
TEAM_DN="cn=team,${GROUPS_DN}"

ldaps_uri() {
    echo "ldaps://$1:6360"
}

ldap_uri() {
    echo "ldap://$1:3890"
}

FIRST="$(ldaps_uri "${NODES[0]}")"
LAST="$(ldaps_uri "${NODES[-1]}")"

# nodes
for node in "${NODES[@]}"; do
    eventually has_entry "$(ldaps_uri "${node}")" "${TEST_SUFFIX}"
done
ok "all nodes are up: ${NODES[*]}"

# tls
for node in "${NODES[@]}"; do
    expect_rc 0 bind_search "$(ldap_uri "${node}")" "${ADMIN_DN}" -ZZ -b "${TEST_SUFFIX}" -s base dn
    expect_rc 13 bind_search "$(ldap_uri "${node}")" "${ADMIN_DN}" -b "${TEST_SUFFIX}" -s base dn
done
ok "ldaps and StartTLS work, TLS is required"

expect_rc 32 ldapsearch -x -H "${FIRST}" -b "${TEST_SUFFIX}" -s base dn
ok "anonymous users cannot read the database"

# config
for node in "${NODES[@]}"; do
    uri="$(ldaps_uri "${node}")"

    expect_rc 0 bind_search "${uri}" "${CONFIG_ADMIN_DN}" -b "cn=module{0},cn=config" -s base olcModuleLoad
    for module in ${TEST_MODULES}; do
        expect_output "^olcModuleLoad: \{[0-9]+\}${module}$"
    done

    expect_rc 0 bind_search "${uri}" "${CONFIG_ADMIN_DN}" -b "cn=schema,cn=config" -s one cn
    for schema in ${TEST_SCHEMAS}; do
        expect_output "^cn: \{[0-9]+\}${schema%.ldif}$"
    done

    expect_rc 0 bind_search "${uri}" "${CONFIG_ADMIN_DN}" -b "olcDatabase={1}mdb,cn=config" -s one olcOverlay
    for overlay in ppolicy unique refint memberof auditlog syncprov; do
        expect_output "^olcOverlay: \{[0-9]+\}${overlay}$"
    done
    expect_output "^olcOverlay: \{5\}syncprov$"

    expect_rc 0 bind_search "${uri}" "${CONFIG_ADMIN_DN}" -b "cn=config" -s base olcServerID
    if [ "$(grep -c "^olcServerID: " "${OUTPUT_FILE}")" != "${#NODES[@]}" ]; then
        cat "${OUTPUT_FILE}" >&2
        fail "expected ${#NODES[@]} server IDs on ${node}"
    fi
done
ok "config: modules, schemas, overlays and server IDs loaded on all nodes"

# data
expect_rc 0 bind_modify "${FIRST}" "${ADMIN_DN}" -a <<LDIF
dn: ${PEOPLE_DN}
objectClass: organizationalUnit
ou: people

dn: ${GROUPS_DN}
objectClass: organizationalUnit
ou: groups

dn: ${ALICE_DN}
objectClass: inetOrgPerson
objectClass: posixAccount
uid: alice
cn: Alice
sn: Liddell
mail: alice@example.org
uidNumber: 10001
gidNumber: 10000
homeDirectory: /home/alice
userPassword: ${TEST_PASSWORD}

dn: ${BOB_DN}
objectClass: inetOrgPerson
uid: bob
cn: Bob
sn: Builder
mail: bob@example.org
userPassword: ${TEST_PASSWORD}

dn: ${CAROL_DN}
objectClass: inetOrgPerson
uid: carol
cn: Carol
sn: Danvers
mail: carol@example.org
userPassword: ${TEST_PASSWORD}

dn: ${TEAM_DN}
objectClass: groupOfNames
cn: team
member: ${ALICE_DN}
member: ${BOB_DN}
LDIF
ok "entries added on ${NODES[0]}"

# replication
for node in "${NODES[@]:1}"; do
    eventually has_entry "$(ldaps_uri "${node}")" "${TEAM_DN}"
done
ok "entries replicated from ${NODES[0]} to ${NODES[*]:1}"

expect_rc 0 bind_modify "${LAST}" "${ADMIN_DN}" -a <<LDIF
dn: ou=from-last-node,${TEST_SUFFIX}
objectClass: organizationalUnit
ou: from-last-node
LDIF
for node in "${NODES[@]::${#NODES[@]}-1}"; do
    eventually has_entry "$(ldaps_uri "${node}")" "ou=from-last-node,${TEST_SUFFIX}"
done
ok "entries replicated from ${NODES[-1]} to the other nodes (multi-provider)"

expect_rc 0 ldapsearch -LLL -x -H "${FIRST}" -D "cn=replicator,${TEST_SUFFIX}" -w "${TEST_REPLICATION_PASSWORD}" -b "${TEAM_DN}" -s base dn
ok "replicator user can bind with a password containing spaces, single quotes, backslashes and \$"

# password hashing
expect_rc 0 bind_search "${FIRST}" "${ADMIN_DN}" -b "${ALICE_DN}" -s base userPassword
expect_output "^userPassword:: $(printf '{ARGON2}' | base64 | cut -c1-10)"
expect_rc 0 bind_search "${FIRST}" "${ALICE_DN}" -b "${ALICE_DN}" -s base dn
ok "clear text passwords are hashed with {ARGON2} and users can bind"

# memberof
is_team_member() {
    bind_search "$1" "${ADMIN_DN}" -b "$2" -s base memberOf | grep -qi "^memberOf: ${TEAM_DN}$"
}

for node in "${NODES[@]}"; do
    eventually is_team_member "$(ldaps_uri "${node}")" "${ALICE_DN}"
done
ok "memberOf is maintained on all nodes"

# unique
expect_rc 19 bind_modify "${FIRST}" "${ADMIN_DN}" -a <<LDIF
dn: cn=alice-duplicate,${PEOPLE_DN}
objectClass: inetOrgPerson
uid: alice
cn: alice-duplicate
sn: Duplicate
LDIF
expect_rc 19 bind_modify "${FIRST}" "${ADMIN_DN}" -a <<LDIF
dn: uid=mail-duplicate,${PEOPLE_DN}
objectClass: inetOrgPerson
uid: mail-duplicate
cn: mail-duplicate
sn: Duplicate
mail: alice@example.org
LDIF
ok "uid and mail are unique"

# refint
expect_rc 0 ldapdelete -x -H "${FIRST}" -D "${ADMIN_DN}" -w "${TEST_PASSWORD}" "${BOB_DN}"
bob_removed_from_team() {
    bind_search "$1" "${ADMIN_DN}" -b "${TEAM_DN}" -s base member > "${OUTPUT_FILE}.member"
    grep -qi "^member: ${ALICE_DN}$" "${OUTPUT_FILE}.member" && ! grep -qi "^member: ${BOB_DN}$" "${OUTPUT_FILE}.member"
}

for node in "${NODES[@]}"; do
    eventually bob_removed_from_team "$(ldaps_uri "${node}")"
done
ok "deleted users are removed from groups on all nodes"

# ppolicy
expect_fail ldappasswd -x -H "${FIRST}" -D "${ALICE_DN}" -w "${TEST_PASSWORD}" -a "${TEST_PASSWORD}" -s "short"
expect_output "quality|too short|Constraint violation"
ok "password policy rejects short clear text passwords"

NEW_PASSWORD="Another-passw0rd-2026"
expect_rc 0 bind_modify "${FIRST}" "${ALICE_DN}" <<LDIF
dn: ${ALICE_DN}
changetype: modify
delete: userPassword
userPassword: ${TEST_PASSWORD}
-
add: userPassword
userPassword: $(slappasswd -h '{SSHA}' -s "${NEW_PASSWORD}")
LDIF
expect_rc 0 ldapsearch -x -H "${FIRST}" -D "${ALICE_DN}" -w "${NEW_PASSWORD}" -b "${ALICE_DN}" -s base dn
ok "password policy accepts pre-hashed passwords (pwdCheckQuality: 1)"

for i in 1 2 3 4 5; do
    expect_rc 49 ldapsearch -x -H "${FIRST}" -D "${CAROL_DN}" -w "wrong-password-${i}" -b "${CAROL_DN}" -s base dn
done
expect_rc 49 bind_search "${FIRST}" "${CAROL_DN}" -b "${CAROL_DN}" -s base dn
ok "password policy locks accounts after too many failures"

# readonly
READONLY_DN="cn=readonly,${TEST_SUFFIX}"
expect_rc 0 bind_search "${FIRST}" "${READONLY_DN}" -b "${ALICE_DN}" -s base cn userPassword
expect_output "^cn: Alice$"
expect_no_output "^userPassword"
expect_rc 50 bind_modify "${FIRST}" "${READONLY_DN}" <<LDIF
dn: ${ALICE_DN}
changetype: modify
replace: sn
sn: Changed
LDIF
ok "readonly user can read but not write nor read passwords"

# monitor
expect_rc 0 bind_search "${FIRST}" "cn=readonly-monitor,${TEST_SUFFIX}" -b "cn=monitor" -s base dn
expect_output "^dn: cn=Monitor$"
ok "readonly monitor user can read cn=monitor"
