OPENLDAP_CTL_PASSWORD_GENERATE_CMD="slappasswd -n -g; slappasswd -g"
OPENLDAP_CTL_PASSWORD_HASH_CMD="slappasswd -h {ARGON2} -o module-path=${OPENLDAP_MODULES_DIR} -o module-load=argon2"

OPENLDAP_CTL_SCHEMA2LDIF_DEPENDENCIES="core.schema cosine.schema inetorgperson.schema"
