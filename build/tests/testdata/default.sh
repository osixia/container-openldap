#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1091
source /tmp/openldap-test-lib.sh

URI="ldap://${TEST_NODES}:3890"

eventually has_entry "${URI}" "${TEST_SUFFIX}"
ok "admin can read the database"

expect_rc 32 ldapsearch -x -H "${URI}" -b "${TEST_SUFFIX}" -s base dn
ok "anonymous users cannot read the database"

expect_rc 0 bind_modify "${URI}" "${ADMIN_DN}" -a <<LDIF
dn: ou=people,${TEST_SUFFIX}
objectClass: organizationalUnit
ou: people

dn: uid=alice,ou=people,${TEST_SUFFIX}
objectClass: inetOrgPerson
uid: alice
cn: Alice
sn: Liddell
mail: alice@example.org
userPassword: ${TEST_PASSWORD}
LDIF
ok "admin can write the database"

expect_rc 0 bind_search "${URI}" "uid=alice,ou=people,${TEST_SUFFIX}" -b "ou=people,${TEST_SUFFIX}" -s one cn mail
expect_output "^mail: alice@example.org$"
ok "authenticated users can read allowed attributes"

expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" -b "cn=config" -s base dn
ok "config admin can read cn=config"

expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" -b "cn=config" '(olcDatabase=monitor)' olcMonitoring
expect_output '^olcMonitoring: FALSE$'
ok "monitoring is disabled by default"

expect_rc 0 bind_search "${URI}" "${CONFIG_ADMIN_DN}" -b "cn=schema,cn=config" -s one cn
for schema in ${TEST_SCHEMAS}; do
    expect_output "^cn: \{[0-9]+\}${schema%.ldif}$"
done
ok "schemas loaded: ${TEST_SCHEMAS}"
