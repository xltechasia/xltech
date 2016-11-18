#!/usr/bin/env bash
# XLTech Add-PPA
# see <command> -h for info/help

# Constants
declare -Ar XLTAPP=( \
    [NAME]="XLTech Add-PPA" \
    [CMD]="xlt add-ppa" \
    [DESC]="Add a defined repository (or list) to system repository list" \
    [VERSION]="1.0" \
    [REQPKGS]="" \
    [AUTHOR]="Matthew@XLTech.io (Astro7467)" \
    [BUGREPORT]="https://github.com/xltechasia/xltech/issues" \
)
declare -ir TRUE=0
declare -ir FALSE=1
declare -ar CONFINDEX=("FILE" "NAME" "DESC" "VERSION" "TYPE" "SOURCE" "INSTALL" "UPGRADE" "FULLUPGRADE" "SCRIPT")
declare -ar CONFDIR=("/opt/xltech/conf.ppa.d")
declare -ar LISTDIR=("/opt/xltech/conf.ppa.d")
# end / Constants


# Initialize / Defaults
decalre     ACTION=""
declare -A  CONF # init array
for INDEX in ${CONFINDEX[@]}; do
    CONF[$INDEX]=""
done
declare -i  VERBOSE=0
declare     PPAREQUEST=""
declare -i  DOLIST=$FALSE
declare -i  DOUPGRADE=$TRUE
# end / Initialize


show_help() {
    cat << EOF
NAME
    ${XLTAPP[NAME]} v${XLTAPP[VERSION]} - ${XLTAPP[DESC]}

SYNOPSIS
    ${XLTAPP[CMD]} [-h|--help] [-l|--list] [-n|-noupgrade] [-a|-i|-add|--install <name>]

DESCRIPTION
    Add a pre-defined PPA (or repository list file) to system repository database

OPTIONS
    -h|--help       Display this help

AUTHOR
    ${XLTAPP[AUTHOR]}

REPORTING BUGS
    ${XLTAPP[BUGREPORT]}

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


load_conf() {
    declare CONFLINE
    declare CONFVAR
    IFS=$'\n'
    for CONFLINE in $(grep -E -e "^[[:alnum:]]+=.*" "${CONF[FILE]}"); do
        CONFVAR="$(echo "$CONFLINE" | cut -d '=' -f 1)"
        CONF[$CONFVAR]="$(echo "$CONFLINE" | cut -d '=' -f 2- )"
    done
    unset IFS
} #load_conf()


print_conf() {
    declare INDEX
    for INDEX in ${CONFINDEX[@]}; do
        log 1 "$INDEX = ${CONF[$INDEX]}"
    done

} #print_conf()


confirm_ppa() {
echo "$0 Placeholder"

} #confirm_ppa()


list_ppa() {
echo "$0 Placeholder"

} #list_ppa()


add_ppa() {
echo "$0 Placeholder"
    #CONFINDEX="FILE NAME DESC VERSION TYPE SOURCE INSTALL UPGRADE FULLUPGRADE SCRIPT"

} #add_ppa()


# main()
log 1 "${XLTAPP[CMD]} v${XLTAPP[VERSION]}"

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

while :; do
    case $1 in
        -h|-\?|--help)  # Call a "show_help" function to display a synopsis, then exit.
            ACTION="HELP"
            exit 0
            ;;
        -v|--verbose)   # Add/Increase verbosity to output
            VERBOSE=$((VERBOSE + 1))    # Each -v argument adds 1 to verbosity.
            log 1 "Verbosity increased to $VERBOSE"
            shift
            ;;
        -l|--list)
            if [ -z "$ACTION" ]; then
                ACTION="LIST"
            fi
            shift
            ;;
        -n|--noupgrade)
            DOUPGRADE=$FALSE
            shift
            ;;
        -a|--add|i|--install)
            if [ -n "$2" ]; then
                PPAREQUEST="$2"
            else
                errwarn 1 "No PPA given after $1 option"
            fi
            CONF[FILE]="$2"
            if [ -z "$ACTION" ]; then
                ACTION="INSTALL"
            fi
            shift
            shift
            ;;
        --)             # End of all options.
            shift
            break
            ;;
        -?*)            # Undefined options
            errwarn 1 'Unknown option : $1'
            ;;
        *)              # Default case: If no more options then break out of the loop.
            break
    esac
done

case $ACTION in
    HELP)
        show_help
        exit 0
        ;;
    LIST)
        list_ppa
        exit 0
        ;;
    INSTALL)
        confirm_ppa
        load_conf
        print_conf
        add_ppa
        ;;
    *)
        show_help
        exit 0
        ;;
esac

exit 0

# end / main()
