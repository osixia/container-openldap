#!/bin/bash

# set -x (bash debug) if log level is trace
# https://github.com/osixia/docker-light-baseimage/blob/master/image/tool/log-helper
log-helper level eq trace && set -x

SCHEMAS=$1

tmpd=`mktemp -d`
pushd ${tmpd} >>/dev/null

echo "include /etc/ldap/schema/core.schema" >> convert.dat
echo "include /etc/ldap/schema/cosine.schema" >> convert.dat
echo "include /etc/ldap/schema/inetorgperson.schema" >> convert.dat

if [ -e "/etc/ldap/schema/rfc2307bis.schema" ]; then
  echo "include /etc/ldap/schema/rfc2307bis.schema" >> convert.dat
else
  echo "include /etc/ldap/schema/nis.schema" >> convert.dat
fi


for schema in ${SCHEMAS} ; do
    echo "include ${schema}" >> convert.dat
done

slaptest -f convert.dat -F .

if [ $? -ne 0 ] ; then
    log-helper error "slaptest conversion failed"
    exit
fi

for schema in ${SCHEMAS} ; do
    fullpath=${schema}
    schema_name=`basename ${fullpath} .schema`
    schema_dir=`dirname ${fullpath}`
    ldif_file=${schema_name}.ldif

    if [ -e "${schema_dir}/${ldif_file}" ]; then
      log-helper warning "${schema} ldif file ${schema_dir}/${ldif_file} already exists skipping conversion"
      continue
    fi

    find . -name *\}${schema_name}.ldif | xargs -I {} mv '{}' ./${ldif_file}

    # Strip ldif file off export metadata
    sed -e "/dn:/ c dn: cn=${schema_name},cn=schema,cn=config" \
    -e "/cn:/ c cn: ${schema_name}" \
    -e '/structuralObjectClass/ d' \
    -e '/entryUUID/ d' \
    -e '/creatorsName/ d' \
    -e '/createTimestamp/ d' \
    -e '/entryCSN/ d' \
    -e '/modifiersName/ d' \
    -e '/modifyTimestamp/ d' \
    -i ${ldif_file}
    
    # slapd seems to be very sensitive to how a file ends. There should be no blank lines.
    sed -i '/^ *$/d' ${ldif_file}

    mv ${ldif_file} ${schema_dir}
done

popd >>/dev/null
rm -rf $tmpd
