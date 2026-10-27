#!/bin/bash

set -euo pipefail

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

generate() {
  eval "${OPENLDAP_CTL_PASSWORD_GENERATE_CMD}"
}

hash() {
    local password_file

    case "${1:-}" in
        --file)
            if [ "$#" -ne 2 ] || [ -z "$2" ]; then
                usage
                container log fatal "--file requires exactly one password file"
            fi
            password_file="$2"
            if [ ! -f "${password_file}" ] || [ ! -r "${password_file}" ] || [ ! -s "${password_file}" ]; then
                container log fatal "Password file must be a readable non-empty file: ${password_file}"
            fi
            eval "${OPENLDAP_CTL_PASSWORD_HASH_CMD}"' -T "${password_file}"'
            return
            ;;
        --stdin)
            if [ "$#" -ne 1 ]; then
                usage
                container log fatal "--stdin does not accept additional arguments"
            fi
            eval "${OPENLDAP_CTL_PASSWORD_HASH_CMD}"' -T /dev/stdin'
            return
            ;;
        --)
            shift
            ;;
    esac

    if [ "$#" -ne 1 ]; then
        usage
        container log fatal "Exactly one password argument is required"
    fi

    local password="$1"

    if [ -z "${password}" ]; then
        container log fatal "Missing password argument"
    fi

    eval "${OPENLDAP_CTL_PASSWORD_HASH_CMD}"' -s "${password}"'
}

usage() {
  echo "Usage: openldap-ctl password generate"
  echo "Usage: openldap-ctl password hash [--] password | --file path | --stdin"
}

main() {
    local cmd="${1:-}"

    case "$cmd" in
        generate)
            generate
            ;;
        hash)
            shift
            hash "$@"
            ;;
        ""|-h|--help)
            usage
            ;;
        *)
            usage
            container log fatal "Unknown command '${cmd}'"
            ;;
    esac
}

main "$@"
