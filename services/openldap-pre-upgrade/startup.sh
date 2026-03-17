#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

# si version courrante data != version courrante image on sort
# sauf si OPENLDAP_PRE_UPGRADE_FORCE

# sinon backup ugrade versions
# backup classique + backup-upgrade
