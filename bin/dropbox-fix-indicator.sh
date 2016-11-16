#!/usr/bin/env bash
# <name>
# see <command> -h for info/help

# Constants
readonly XLTAPPNAME="<name>"
readonly XLTAPPCMD="<command>"
readonly XLTAPPDESC="<desc>"
readonly XLTAPPVER="1.0"
readonly XLTAPPREQPKGS=""
readonly XLTAPPAUTH="Matthew@XLTech.io (Astro7467)"
readonly XLTBUGREPORT="https://github.com/xltechasia/xltech/issues"
readonly TRUE=0
readonly FALSE=1
# end / Constants

# Initialize / Defaults
VERBOSE=0
# end / Initialize


show_help() {
    cat << EOF
NAME
    $XLTAPPNAME v$XLTAPPVER - $XLTAPPDESC

SYNOPSIS
    $XLTAPPCMD [-h|--help] <options>

DESCRIPTION


OPTIONS
    -h|--help       Display this help

AUTHOR
    $XLTAPPAUTH

REPORTING BUGS
    $APPBUGREPORT

COPYRIGHT
    Copyright © 2016 XLTech  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.

EOF
} # show_help()


# main()
printf "\n%s v%s\n" "$XLTAPPCMD" "$XLTAPPVER"

while :; do
    case $1 in
        -h|-\?|--help)  # Call a "show_help" function to display a synopsis, then exit.
            show_help
            exit 0
            ;;
        --)             # End of all options.
            shift
            break
            ;;
        -?*)            # Undefined options
            printf '\nERROR: Unknown option : %s\n' "$1" >&2
            exit 1
            ;;
        *)              # Default case: If no more options then break out of the loop.
            break
    esac
done

dropbox stop && dbus-launch dropbox start

exit 0

# end / main()
