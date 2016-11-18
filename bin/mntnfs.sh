#!/usr/bin/env bash
# <name>
# see <command> -h for info/help
# Derived from original AutoNFS script by Jeroen Hoek <mail@jeroenhoek.nl>

# TODO: Change to be config file driven instead of hardcoded (/etc/defaults/xlt-mntnfs &/or ~/.xlt-mntnfs ?)
# TODO: Consider Merge of CIFS/SMB, SSFS and NFS mounts into single utility

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

# Mount Options (see mount man pages for info).
readonly MOUNTOPTS="-o rw,hard,intr,tcp,actimeo=3"

# Delimeter used for separating fileserver/client shares below:
readonly DELIMITER="|"
readonly MOUNTPOINT="/media"

# end / Constants

# Initialize / Defaults
VERBOSE=0

# The shares that need to be mounted. If the local and remote mount point
# differ, write something like "192.168.0.1|/media/remoteshare|/media/localshare", where "|" is
# the DELIMITER configured above. If the mount points are the same, you can also use
# the short-hand "192.168.0.1|/media/share".

MOUNTS=(
    "<server1>|<nfssharepath1>|<localdirectory1>"
    "<server1>|<nfssharepath2>|<localdirectory2>"
    "<server1>|<nfssharepath3>|<localdirectory3>"
    "<server2>|<nfssharepath4>|<localdirectory4>"
    )
# end / Initialize


# Logging. Set to true for debugging and testing; false when everything works.
LOG=false

# End of configuration


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


function log {
    if $LOG; then
        echo $1
    fi
}


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

log "Automatic NFS mount script started."

declare -a MOUNTP

case "$1" in
    "-u" | "--unmount")
        log "$0 :: Unmount Option Accepted"
        for MOUNT in ${MOUNTS[@]}; do
            # Split up the share into the server, remote and local mount point.
            MOUNTP=(`echo ${MOUNT//$DELIMITER/ }`)

            # The 3rd part of the mount string is the local mount point.
            # If there is no 3rd part, local and remote are mounted on
            # the same location (relative to local mountpoint).
            FILESERVER=${MOUNTP[0]}
            THERE=${MOUNTP[1]}
            HERE=${MOUNTPOINT}/${MOUNTP[${#MOUNTP[@]}-1]}

            if grep -qsE "^([^ ])+ ${HERE}" /proc/mounts; then
            # NFS mount is still mounted; attempt umount
            log "As requested, unmounting NFS share ${HERE}."
            umount -lf "${HERE}"
            rmdir -p "${HERE}"
            fi
        done
        exit
        ;;
    "-l" | "--log")
        LOG=true
        ;;
    *)
        log "$0 - no valid parameters passed"
        ;;
esac


for MOUNT in ${MOUNTS[@]}; do
    # Split up the share into the server, remote and local mount point.
    MOUNTP=(`echo ${MOUNT//$DELIMITER/ }`)

    # The 3rd part of the mount string is the local mount point.
    # If there is no 3rd part, local and remote are mounted on
    # the same location (relative to local mountpoint).
    FILESERVER=${MOUNTP[0]}
    THERE=${MOUNTP[1]}
    HERE=${MOUNTPOINT}/${MOUNTP[${#MOUNTP[@]}-1]}

    # Is the NFS daemon responding?
    rpcinfo -t "$FILESERVER" nfs &>/dev/null
    if [ $? -eq 0 ]; then
        # Fileserver is up.
        log "Fileserver ${FILESERVER} is up."

        if grep -qsE "^([^ ])+ ${HERE}" /proc/mounts; then
            log "${HERE} is already mounted."
        else
            if [ -d "${MOUNTPOINT}" ]; then
                log "Mount Point ${MOUNTPOINT} Exists"
            else
                log "Mount Point ${MOUNTPOINT} being created"
                mkdir -p "${MOUNTPOINT}"
            fi

            # NFS mount not mounted, attempt mount
            log "NFS share not mounted; attempting to mount ${HERE}:"

            if [ -d "${HERE}" ]; then
                log "....${HERE} already exists"
            else
                log "....${HERE} folder is being created"
                mkdir -p "${HERE}"
                chown -R 1000:100 "${HERE}"
                chmod -R +rwxrwxrwx "${HERE}"
            fi

            mount -t nfs ${MOUNTOPTS} ${FILESERVER}:${THERE} ${HERE}
            if [ $? -eq 0 ]; then
                log "....NFS mount of ${FILESERVER}; ${THERE} to ${HERE} successful"
            else
                # NFS mount failed, remove directory
                log "....NFS mount ${FILESERVER}; ${THERE} failed; removing ${HERE}"
                rmdir -p "${HERE}"
            fi
        fi
        else
            # Fileserver is down.
            log "Fileserver $FILESERVER is down."
        if grep -qsE "^([^ ])+ ${HERE}" /proc/mounts; then
            # NFS mount is still mounted; attempt umount
            log "Cannot reach ${FILESERVER}, unmounting NFS share ${HERE}."
            umount -f ${HERE}
            rmdir -p ${HERE}
        fi
    fi
done

exit 0

# end / main()


