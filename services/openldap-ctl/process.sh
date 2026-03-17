#!/bin/bash -e

# if container log level is trace:
# print commands and their arguments as they are executed
container logger level eq trace && set -x

# function to display help
show_help() {
    echo "Usage:"
    echo "  openldap-ctl <command> [args...]"
    echo
    echo "Available commands:"

    # List all .sh files in the scripts directory
    for script in "${SCRIPTS_PATH}"/*.sh; do
        [ -e "$script" ] || continue  # handle empty directory safely
        name="$(basename "$script" .sh)"
        echo "  - $name"
    done
}

# path to the scripts directory
SCRIPTS_PATH="/container/services/openldap-ctl/assets/scripts"

# if no arguments or --help/-h -> show help
if [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    show_help
    exit 0
fi

# first argument is the script name
SCRIPT_NAME="$1"
shift  # Remove the first argument, leaving only the script arguments

# build the full path to the target script
TARGET_SCRIPT="${SCRIPTS_PATH}/${SCRIPT_NAME}.sh"

# check if the script exists
if [ ! -f "${TARGET_SCRIPT}" ]; then
    show_help
    container logger fatal "Command '${SCRIPT_NAME}' not found"
fi

# execute the target script with all remaining arguments
exec "${TARGET_SCRIPT}" "$@"
