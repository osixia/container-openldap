#!/bin/bash

generate_password() {
    container entrypoint --quiet -x openldap-ctl -- password generate
}

hash_password() {
    if [ -z "$1" ]; then
        container logger fatal "password to hash required"
    fi
    container entrypoint --quiet -x openldap-ctl -- password hash "$1"
}

ensure_hashed_password() {
    local hashed_var="$1"
    local label="$2"

    [ -n "${!hashed_var}" ] && return 0

    local plain_var
    plain_var=$(generate_password) 

    container logger warning "Generated ${label} password: ${plain_var}"

    printf -v "${hashed_var}" '%s' "$(hash_password "${plain_var}")"
}
