#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

set -o pipefail

SCHEMAS=$1
DEPENDENCIES=${2:-${OPENLDAP_CTL_SCHEMA2LDIF_DEPENDENCIES}}

TMP_DIR=$(mktemp -d)
TMP_FILE=$(mktemp)

cleanup() {
  rm -rf "${TMP_DIR}"
  rm -f "${TMP_FILE}"
}

trap cleanup EXIT

for schema in ${DEPENDENCIES}; do

  schema_path="${OPENLDAP_SCHEMAS_DIR}/${schema}"

  if [ ! -e "${schema_path}" ]; then
    container log fatal "File not found: ${schema_path}"
  fi

  echo "include ${schema_path}" >> "${TMP_FILE}"

done

for schema in ${SCHEMAS} ; do
    echo "include ${schema}" >> "${TMP_FILE}"
done

if ! slaptest -f "${TMP_FILE}" -F "${TMP_DIR}" > /dev/null ; then
    container log fatal "Failed do convert ${SCHEMAS} to ldif"
fi

for schema in ${SCHEMAS} ; do

    schema_name=$(basename "${schema%.*}")
    schema_dir=$(dirname "${schema}")
    ldif="${schema_dir}/${schema_name}.ldif"

    if [ -e "${ldif}" ]; then
      container log fatal "${schema_name} ldif file already exists: ${ldif}"
    fi

    find "${TMP_DIR}" | container log debug

    find "${TMP_DIR}" -name "*\}${schema_name,,}.ldif" -exec mv '{}' "${ldif}" \;

    sed -i "s/^dn:.*/dn: cn=${schema_name},cn=schema,cn=config/g" "${ldif}"
    sed -i "s/^cn:.*/cn: ${schema_name}/g" "${ldif}"

    for entry in structuralObjectClass entryUUID creatorsName createTimestamp entryCSN modifiersName modifyTimestamp; do
      sed -i "/${entry}/d" "${ldif}"
    done

    # slapd seems to be very sensitive to how a file ends. There should be no blank lines.
    sed -i "/^ *$/d" "${ldif}"

    cat "${ldif}"

done
