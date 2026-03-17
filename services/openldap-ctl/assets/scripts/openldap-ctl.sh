#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container log level eq trace && set -x

# function to display help
show_help() {
    echo "Usage:"
    echo "  openldap-ctl command [args]..."
    echo
    echo "Available commands:"

    # List all .sh files in the commands directory
    for command in "${COMMANDS_PATH}"/*.sh; do
        [ -e "${command}" ] || continue  # handle empty directory safely
        name="$(basename "${command}" .sh)"
        echo "  - $name"
    done
}

# path to the commands directory
COMMANDS_PATH="/container/services/openldap-ctl/assets/scripts/commands"

# if no arguments or --help/-h -> show help
if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_help
    exit 0
fi

# first argument is the command name
COMMAND_NAME="$1"
shift  # Remove the first argument, leaving only the command arguments

# build the full path to the target command
TARGET_COMMAND="${COMMANDS_PATH}/${COMMAND_NAME}.sh"

# check if the command exists
if [ ! -f "${TARGET_COMMAND}" ]; then
    show_help
    container log fatal "Command '${COMMAND_NAME}' not found"
fi

# execute the target command with all remaining arguments
exec "${TARGET_COMMAND}" "$@"
