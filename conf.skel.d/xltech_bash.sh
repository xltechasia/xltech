#!/usr/bin/env bash
# <name>
# see <command> -h for info/help

# Constants
declare -r XLTAPPNAME="<name>"
declare -r XLTAPPCMD="<command>"
declare -r XLTAPPDESC="<desc>"
declare -r XLTAPPVER="1.0"
declare -r XLTAPPREQPKGS=""
declare -r XLTAPPAUTH="Matthew@XLTech.io (Astro7467)"
declare -r XLTBUGREPORT="https://github.com/xltechasia/xltech/issues"
declare -ri TRUE=0
declare -ri FALSE=1
# end / Constants

# Initialize / Defaults
declare -i VERBOSE=0
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
    $XLTBUGREPORT

COPYRIGHT
    Copyright © 2016 XLTech  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.

EOF
} # show_help()


# log "<text>" or log <min-verbose> "<text"
# if <min-verbose> is missing then value is 0
log() {
    declare -i LOGLEVEL=0
    declare LOGTEXT=""

    if [ -n "$2" ]; then
        LOGLEVEL=$1
        LOGTEXT="$2"
    else
        LOGTEXT="$1"
    fi

    if [ $VERBOSE -ge 3 ]; then
        LOGTEXT="$(date +"%Y-%m-%d %H:%M:%S") $LOGTEXT"
    fi

    if [ $LOGLEVEL -le $VERBOSE ]; then
        echo -e "$LOGTEXT"
    fi
} # log()


# Any clean exit cleaning up required by the script
cleanup() {
    log 2 "Performing system cleanup..."

    # Cleanup Activities go here
}


# Print Error or Warning NumX
# errwarn "<text>" or errwarn <NumX> "<text"
# if <NumX> is missing then value is 128, which is a generic warning msg only
# if NumX<128  treat as a FATAL ERROR, cleanup() is called and program terminated
# if Numx>=128 treat as a INFORMATIONAL WARNING only, with a msg sent to STDERR and execution continues
# NumX 0, 1, 2, 128, 129 have predefined values
errwarn() {
    declare -i EWNUM=128
    declare EWTITLE=""
    declare EWINFO=""

    if [ -n "$2" ]; then
        EWNUM=$1
        EWINFO="$2"
    else
        EWINFO="$1"
    fi

    case $EWNUM in
        0)      EWTITLE="UNKNOWN" #Should Never Happen
                ;;
        1)      EWTITLE="BAD ARGS"
                ;;
        2)      EWTITLE="FILE NOT FOUND"
                ;;
        127)    EWTITLE="GENERAL"
                ;;
        128)    EWTITLE="GENERAL"
                ;;
        129)    EWTITLE="DEFAULT ASSUMED"
                ;;
        *)      EWTITLE="UNDEFINED"
                break
                ;;
    esac

    if [ $EWNUM -le 127 ]; then
        log 0 "***ERROR $EWNUM $EWTITLE : $EWINFO" >&2
        cleanup
        exit $EWNUM
    else
        log 1 ">WARNING $EWNUM $EWTITLE : $EWINFO" >&2
    fi
} #errwarn()

# main()
log 0 "\n$XLTAPPCMD v$XLTAPPVER\n"

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
            log 0 '\nERROR: Unknown option : $1\n' >&2
            exit 1
            ;;
        *)              # Default case: If no more options then break out of the loop.
            break
    esac
done

exit 0

# end / main()
