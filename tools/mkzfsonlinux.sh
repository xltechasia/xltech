#!/bin/bash
# mkzfsonlinux.sh
# see mkzfsonlinux.sh -h for info/help

# Constants
readonly VERSION="0.1 Alpha"
readonly TRUE=0
readonly FALSE=1
# end / Constants

# Initialize / Defaults
ZFSPOOL="rpool"
VERBOSE=0
ZFSMNTPOINT="/mnt"
UEFI=$FALSE
CPWRKENV=$FALSE
CPWRKENVPATH=""
CANEXECUTE=$FALSE
DRYRUN=$FALSE
REQPKGS="debootstrap gdisk zfs zfs-initramfs"
ZFSMINDISK=2
ZFSTYPE="mirror"
ZFSDISKCOUNT=0
ZFSDISKLIST[0]=""
# end / Initialize


show_help() {
    cat << EOF
NAME
    mkzfsonlinux.sh v$VERSION - Make ZFS on Linux for Ubuntu 16.04

SYNOPSIS
    mkzfsonlinux.sh [-h] [-u] -z <mirror|raidz|raidz2|zraid3> -d <disk0> [...-d <disk9>] [-c <path>] [--uefi] [--yes|dry]

DESCRIPTION
    mkzfsonlinux is based on https://github.com/zfsonlinux/zfs/wiki/Ubuntu%2016.04%20Root%20on%20ZFS

    *** WILL DESTROY DATA - Use at own risk - Only tested in limited scenarios with Ubuntu MATE 16.04.1

    Builds a ZFS pool on supplied disks, creating a minimal bootable environment or copying an existing working install

OPTIONS
    -h|--help   - Display this help & exit
    -u          - unmount all ZFS partitions & exit
    -z <opt>    - ZFS RAID level to build pool
                    mirror  similiar to RAID1 - minimum of 2 drives required
                            (>2 results in all drives being a mirror of smallest drive size, ie. 4 drives <> RAID10)
                    raidz   similiar to RAID5 - n + 1 drives - minimum of 2 drives, >=3 recommended
                            maximum 1 drive failure for functioning pool
                    raidz2  similiar to RAID6 - n + 2 drives - minimum of 3 drives, >=4 recommended
                            maximum 2 drive failures for functioning pool
                    raidz3  n + 3 drives - minimum of 4 drives, >=5 recommended
                            maximum 3 drive failures for functioning pool
    <disk0>
    ...<disk9>  - Valid drives in /dev/disks/by-id/ to use for ZFS pool
                    eg. ata-Samsung_SSD_850_EVO_M.2_250GB_S24BNX0H812345M
                    or  ata-ST4000DM000-2AE123_ZDH123AA
                  *** All drives passed will be reformatted - ALL partitions & data will be destroyed
    -c <path>   - Source of working system to copy to new ZFS pool (rsync -avxHAX <path> /mnt)
                  If absent, then 'debootstrap xenial /mnt' & 'apt install --yes ubuntu-minimal'
    --uefi      - Add partition and GRUB support for UEFI boot
    --yes       - Required to execute ZFS pool build
                  If absent, after parsing options, will terminate without deleting anything

AUTHOR
    Matthew@XLTech.io

REPORTING BUGS
    https://github.com/XLTech-Asia/xltech/issues

COPYRIGHT
    Copyright © 2016 XLTech  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.

EOF
} # show_help()


install_deps() {
    local APTPKGNAME
    apt-add-repository universe
    apt update
    for APTPKGNAME in REQPKGS; do
        apt --yes install $APTPKGNAME
    done
} # install_deps()


unmount_zfs() {
    # Unmount filesystems
    # TODO: Change to ZFSMNTPOINT
    mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
    zpool export $ZFSPOOL
} #unmount_zfs()


partition_disks() {
    for ZFSDISK in ${ZFSDISKLIST[@]}; do
        printf "\nPartitioning %s :\n" "$ZFSDISK"

        printf "\tKill all existing disk partition table..."
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk --zap-all /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to kill partitions on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        printf "Done\n"

        printf "\tAdding common UEFI & Legacy BIOS partition..."
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk -a1  -n2:34:2047 -t2:EF02 /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to add partition 2 on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        printf "Done\n"

        # UEFI Handling
        if [ $UEFI -eq $TRUE ]; then
            printf "\tAdding UEFI partition..."
            if [ $DRYRUN -eq $FALSE ]; then
                sgdisk -n3:1M:+512M -t3:EF00 /dev/disk/by-id/$ZFSDISK
                if [ $? -ne 0 ]; then
                    printf '\nERROR: Failed to add partition 3 UEFI on disk %s\n' "$ZFSDISK" >&2
                    exit 1
                fi
            fi
            sync # Flush writes to disk
            printf "Done\n"
        else
            printf "\tSkipping UEFI Parition Creation\n"
        fi

        # UEFI & Legacy BIOS partition
        printf "\tAdding ZFS Reserve partition..."
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk      -n9:-8M:0   -t9:BF07 /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to add partition 9 on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        printf "Done\n"

        # UEFI & Legacy BIOS partition
        printf "\tAdding ZFS Pool partition..."
        if [ $DRYRUN -eq $FALSE ]; then
            sgdisk      -n1:0:0     -t1:BF01 /dev/disk/by-id/$ZFSDISK
            if [ $? -ne 0 ]; then
                printf '\nERROR: Failed to add partition 1 on disk %s\n' "$ZFSDISK" >&2
                exit 1
            fi
        fi
        sync # Flush writes to disk
        printf "Done\n"
    done
} # partition_tables()


create_pool() {
    locale ZPOOLPARAMS=""

    printf "\nCreating ZFS Pool %s as %s..." "$ZFSPOOL" "$ZFSTYPE"

    for ZFSDISK in ${ZFSDISKLIST[@]}; do
        ZPOOLPARAMS="$ZPOOLPARAMS $ZFSDISK-part1"
    done

    if [ $DRYRUN -eq $FALSE ]; then
        zpool create -f -o ashift=12 \
                        -O atime=off \
                        -O canmount=off \
                        -O compression=lz4 \
                        -O normalization=formD \
                        -O mountpoint=/ \
                        -R $ZFSMNTPOINT \
                        $ZFSPOOL $ZFSTYPE $ZPOOLPARAMS
        if [ $? -ne 0 ]; then
            printf '\nERROR: Failed to create ZFS Pool\n' >&2
            exit 1
        fi
    else
        cat << EOF
zpool create -f -o ashift=12 \
                -O atime=off \
                -O canmount=off \
                -O compression=lz4 \
                -O normalization=formD \
                -O mountpoint=/ \
                -R $ZFSMNTPOINT \
                $ZFSPOOL $ZFSTYPE $ZPOOLPARAMS
EOF
    fi
    printf "Done\n"
} # create_pool()


create_sets(){
    # Sets below cover most typical desktop & server scenarios

    printf "\nCreating ZFS Datasets on %s..." "$ZFSPOOL"

    if [ $DRYRUN -eq $FALSE ]; then
        # Filesystem Dataset
        zfs create -o canmount=off -o mountpoint=none $ZFSPOOL/ROOT

        # Root Filesystem Dataset for Ubuntu
        zfs create -o canmount=noauto -o mountpoint=/ $ZFSPOOL/ROOT/ubuntu
        zfs mount $ZFSPOOL/ROOT/ubuntu

        # Core OS Datasets
        zfs create                  -o setuid=off               rpool/home
        zfs create -o mountpoint=/root                          rpool/home/root
        zfs create -o canmount=off  -o setuid=off   -o exec=off rpool/var
        zfs create -o com.sun:auto-snapshot=false               rpool/var/cache
        zfs create                                              rpool/var/log
        zfs create                                              rpool/var/spool
        zfs create -o com.sun:auto-snapshot=false   -o exec=on  rpool/var/tmp

        ### Optional sets - Comment out ZFS Sets not wanted
        # If you use /srv on this system
        zfs create                                              rpool/srv

        # If you prefer /opt as a set on this system
        zfs create                                              rpool/opt

        # If this system will have games installed:
        zfs create												rpool/var/games

        # If this system will store local email in /var/mail:
        zfs create												rpool/var/mail

        # If this system will use NFS (locking):
        zfs create 	-o com.sun:auto-snapshot=false \
                    -o mountpoint=/var/lib/nfs					rpool/var/nfs
    fi
    printf "Done\n"
} # create_sets()


junk() {
    # build basic Ubuntu environment
    chmod 1777 /mnt/var/tmp
    debootstrap xenial /mnt

    ## Copy current working system over to new ZFS pool
    rsync -avxHAX / /mnt
    # Options used;
    #   -a  all files, with permissions etc
    #   -v  verbose
    #   -x  stay on one filesystem
    #   -H  preserve hardlinks
    #   -A  preserve ACLs/permissions
    #   -X  preserve extended attributes

    zfs set devices=off rpool


    #################################
    ## Yet to clean-up/do ###########
    #echo $HOSTNAME > /mnt/etc/hostname
    # Use "127.0.1.1       FQDN $HOSTNAME" if the system has a real name in DN
    #echo "127.0.1.1       $HOSTNAME" >>/mnt/etc/hosts

    #################################
    ## Yet to clean-up/do ###########
    #Configure the network interface:
    #Find the interface name:
    #       ifconfig -a
    # vi /mnt/etc/network/interfaces.d/NAME
    #       auto NAME
    #       iface NAME inet dhcp
    ################################


    mount --rbind /dev  /mnt/dev
    mount --rbind /proc /mnt/proc
    mount --rbind /sys  /mnt/sys
    chroot /mnt /bin/bash --login


    #################################
    ## Yet to clean-up/do ###########
    #locale-gen en_US.UTF-8
    #echo 'LANG="en_US.UTF-8"' > /etc/default/locale
    dpkg-reconfigure tzdata

    #vi /etc/apt/sources.list
    #   deb http://archive.ubuntu.com/ubuntu xenial main universe
    #   deb-src http://archive.ubuntu.com/ubuntu xenial main universe
    #   deb http://security.ubuntu.com/ubuntu xenial-security main universe
    #   deb-src http://security.ubuntu.com/ubuntu xenial-security main universe

    #   deb http://archive.ubuntu.com/ubuntu xenial-updates main universe
    #   deb-src http://archive.ubuntu.com/ubuntu xenial-updates main universe
    #ln -s /proc/self/mounts /etc/mtab
    #apt update
    #apt install --yes ubuntu-minimal

    #Install ZFS in the chroot environment for the new system:
    apt install --yes --no-install-recommends linux-image-generic
    apt install --yes zfs zfs-initramfs

    # For Legacy BIOS only system - Install GRUB for legacy (MBR) booting
    apt install --yes grub-pc

    # Else use following for UEFI system
    #apt install dosfstools
    #mkdosfs -F 32 -n EFI /dev/disk/by-id/scsi-SATA_disk1-part3
    #mkdir /boot/efi
    #echo PARTUUID=$(blkid -s PARTUUID -o value \
    #     /dev/disk/by-id/scsi-SATA_disk1-part3) \
    #     /boot/efi vfat defaults 0 1 >> /etc/fstab
    #mount /boot/efi
    #apt install --yes grub-efi-amd64

    # Setup system groups:
    addgroup --system lpadmin
    addgroup --system sambashare

    # Verify that the ZFS root filesystem is recognized:
    #grub-probe /
    #   zfs   <-- Expected result

    # Refresh the initrd files:
    update-initramfs -c -k all

    # Optional (but highly recommended): Make debugging GRUB easier:
    #vi /etc/default/grub
    #   - Comment out: GRUB_HIDDEN_TIMEOUT=0
    #   - Remove quiet and splash from: GRUB_CMDLINE_LINUX_DEFAULT
    #   - Uncomment: GRUB_TERMINAL=console
    #   - Save and quit.

    # Update the boot configuration:
    update-grub

    # Install the boot loader
    # For legacy (MBR) booting, install GRUB to the MBR:
    grub-install $DISK1
    grub-install $DISK2

    # Else for UEFI:
    #grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy

    # To Verify that the ZFS module is installed:
    #ls /boot/grub/*/zfs.mod

    #Snapshot the initial installation:
    zfs snapshot rpool/ROOT/ubuntu@install

    # exit chroot
    exit

    # Unmount filesystems
    mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
    zpool export rpool

    echo "Finished ZFS build on:"
    echo "  - $DISK1"
    echo "  - $DISK2"
    echo ""
    echo "You can reboot the system now"
} # junk()


# main()
printf "\nmkZFSonLinux.sh v%s\n" "$VERSION"

while :; do
    case $1 in
        -h|-\?|--help)  # Call a "show_help" function to display a synopsis, then exit.
            show_help
            exit 0
            ;;
        -u)             # Unmount ZFS from /mnt
            printf "Unmounting ZFS from %s\n" "$ZFSMNTPOINT"
            unmount_zfs
            exit 0
            ;;
        -c)             # Copy Working Environment - Takes an argument - ensuring it has been specified.
            printf "\tCOPY working environment"
            shift
            if [ -n "$1" -a -d "$1" ]; then
                CPWRKENV=$TRUE
                CPWRKENVPATH="$1"
                printf " - transferring %s\n" "$CPWRKENVPATH"
                shift
            else
                printf '\nERROR: "-c" requires a valid non-empty path argument : %s\n' "$1" >&2
                exit 1
            fi
            ;;
        --uefi)         # Support UEFI
            printf "\tUEFI support enabled\n"
            $UEFI=$TRUE
            shift
            ;;
        -v|--verbose)   # Add/Increase verbosity to output
            VERBOSE=$((VERBOSE + 1))    # Each -v argument adds 1 to verbosity.
            printf "\tVerbosity increased to %s\n" "$VERBOSE"
            shift
            ;;
        --yes)
            printf "\tEXECUTION ON - DATA will be DESTROYED\n"
            CANEXECUTE=$TRUE
            shift
            ;;
        --dry)
            printf "\tDry Run Mode Active\n"
            CANEXECUTE=$FALSE
            DRYRUN=$TRUE
            shift
            ;;
        -z)             # ZFS paramenters
            printf "\tZFS pool type : "
            shift
            ZFSTYPE="$1"
            case $ZFSTYPE in
                mirror|raidz)
                    ZFSMINDISK=2
                    ;;
                raidz2)
                    ZFSMINDISK=3
                    ;;
                raidz3)
                    ZFSMINDISK=4
                    ;;
                *)  # Undefined options
                    printf '\nERROR: Unknown ZFS type : %s\n' "$1" >&2
                    exit 1
                    ;;
            esac
            printf "%s requiring a minimum of %d disks\n" "$ZFSTYPE" $ZFSMINDISK
            shift
            ;;
        -d)             # Specify a disk/drive to use for ZFS pool
            printf "\tAdding disk to pool : "
            shift
            if [ -n "$1" ]; then
                ZFSDISKCOUNT=$((ZFSDISKCOUNT + 1 )) # Adding a drive
                ZFSDISKLIST[$ZFSDISKCOUNT]="$(basename "$1")"
                if [ -L "/dev/disk/by-id/${ZFSDISKLIST[$ZFSDISKCOUNT]}" ]; then # Has to exist in disk/by-id
                    printf "Disk %d - %s : confirmed\n" $ZFSDISKCOUNT "${ZFSDISKLIST[$ZFSDISKCOUNT]}"
                else
                    printf '\nERROR: Invalid Disk By-ID Specified : %s (%s)\n' "$1" "/dev/disk/by-id/${ZFSDISKLIST[$ZFSDISKCOUNT]}" >&2
                    exit 1
                fi
            fi
            shift
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

if [ $DRYRUN -eq $TRUE ]; then
    printf "\n >>> Dry Run Mode Selected - Execution Flag Overide In Effect\n"
    CANEXECUTE=$FALSE
fi

if [ $CANEXECUTE -eq $TRUE ]; then
    printf "\n *** EXECUTION FLAG ON - DATA will be DESTROYED - CTRL-C now to terminate\n"
    sleep 5
fi

if [ $DRYRUN -eq $TRUE -o $CANEXECUTE -eq $TRUE ]; then
    install_deps
    partition_disks
    create_pool
    create_sets
fi

exit 0

# end / main()
