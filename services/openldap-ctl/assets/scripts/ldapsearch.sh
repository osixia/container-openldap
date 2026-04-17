#!/bin/bash -e

container logger level eq trace && set -x

# shellcheck disable=SC1091
source "$(dirname "$0")/ldap-common.sh"

exec ldapsearch "$@"
