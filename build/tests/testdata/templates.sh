#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# shellcheck disable=SC1090
source "${OPENLDAP_TEST_HELPER:-/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh}"

test_dir=$(mktemp -d)
trap 'chmod -R u+rwX "${test_dir:?}"; rm -rf "${test_dir:?}"' EXIT

mkdir -p "${test_dir}/source/..revision" "${test_dir}/output" "${test_dir}/custom"
printf 'dn: %s\n' "\${OPENLDAP_TEST_DN}" > "${test_dir}/source/..revision/10-entry.ldif.template"
printf 'description: original\n' > "${test_dir}/source/..revision/20-plain.ldif"
ln -s ..revision "${test_dir}/source/..data"
ln -s ..data/10-entry.ldif.template "${test_dir}/source/10-entry.ldif.template"
ln -s ..data/20-plain.ldif "${test_dir}/source/20-plain.ldif"
chmod -R a-w "${test_dir}/source"
export OPENLDAP_TEST_DN='dc=example,dc=org'

prepare_ldif_files "${test_dir}/source" "${test_dir}/output"
test "$(cat "${test_dir}/output/10-entry.ldif")" = "dn: ${OPENLDAP_TEST_DN}"
test "$(cat "${test_dir}/output/20-plain.ldif")" = 'description: original'
test ! -e "${test_dir}/source/10-entry.ldif"
test "$(cat "${test_dir}/source/10-entry.ldif.template")" = "dn: \${OPENLDAP_TEST_DN}"
test -L "${test_dir}/source/10-entry.ldif.template"
test -z "$(find "${test_dir}/output" -name '.templates.*')"

printf 'description: custom\n' > "${test_dir}/custom/20-plain.ldif"
prepare_ldif_files "${test_dir}/custom" "${test_dir}/output"
test "$(cat "${test_dir}/output/20-plain.ldif")" = 'description: custom'

printf 'dn: %s\ndescription: custom template\n' "\${OPENLDAP_TEST_DN}" > "${test_dir}/custom/10-entry.ldif.template"
prepare_ldif_files "${test_dir}/custom" "${test_dir}/output"
test "$(cat "${test_dir}/output/10-entry.ldif")" = "$(printf 'dn: %s\ndescription: custom template' "${OPENLDAP_TEST_DN}")"
test ! -e "${test_dir}/custom/10-entry.ldif"

# On failure, the bootstrap's global EXIT trap removes the working directory.
mkdir "${test_dir}/failure"
(
    # Invoked by the child Bash process through the exported function.
    # shellcheck disable=SC2329
    container() {
        if [ "${1}" = envsubst ]; then
            return 1
        fi
        return 0
    }
    export -f container
    if bash -c 'set -euo pipefail; cleanup_dir=${3}; trap '\''rm -rf "${cleanup_dir:?}"'\'' EXIT; source "${1}"; prepare_ldif_files "${2}" "${3}"' -- \
        "${OPENLDAP_TEST_HELPER:-/container/services/openldap-bootstrap/assets/scripts/helpers/common.sh}" \
        "${test_dir}/source" "${test_dir}/failure"; then
        exit 1
    fi
)
test ! -e "${test_dir}/failure"
test -z "$(find "${test_dir}/output" -name '.templates.*')"
