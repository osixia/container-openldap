#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

# si version courante data != version courante image et si fichier upgrade -> restore backup upgrade ->
# -> set la nouvelle version de data -> on sort
echo "oui"