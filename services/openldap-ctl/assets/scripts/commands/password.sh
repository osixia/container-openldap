#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

generate() {
  eval "${OPENLDAP_CTL_PASSWORD_GENERATE_CMD}"
}

hash() {
    local password="$1"

    if [ -z "${password}" ]; then
        container log fatal "Missing password argument"
        exit 1
    fi

    eval "${OPENLDAP_CTL_PASSWORD_HASH_CMD}" -s "${password}"
}

usage() {
  echo "Usage:"
  echo "  generate"
  echo "  hash \"password\""
}

main() {
    local cmd="$1"

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
