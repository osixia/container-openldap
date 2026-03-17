#!/bin/bash

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

sudo ln -s /container/services/openldap-ctl/assets/scripts/openldap-ctl.sh /usr/bin/openldap-ctl
