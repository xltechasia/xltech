#!/bin/bash
# mkzfsonlinux.sh
# see mkzfsonlinux.sh -h for info/help

# TODO: --bootstrap option(s) to install minimal bootable environment as alternative to --cp or --install opts
# TODO: --uefi untested/unfinished
# TODO: --cp untested..

# Constants
readonly VERSION="0.1 Alpha"
readonly TRUE=0
readonly FALSE=1
readonly REQPKGS="debootstrap gdisk zfs zfs-initramfs"
readonly ZFSPOOL="rpool"
readonly ZFSMNTPOINT="/mnt"
readonly UBIQUITYCMD="ubiquity"
readonly UBIQUITYARGS="gtk_ui"
readonly UBIQUITYZFSSET="ubuntu-install"
readonly UBIQUITYDEVICE="/dev/zd0"
readonly UBIQUITYPART="/dev/zd0p1"
readonly UBIQUITYMNTPOINT="/ubuntu-install"
# end / Constants

# Initialize / Defaults
VERBOSE=0
UEFI=$FALSE
CPWRKENV=$FALSE
CPWRKENVPATH=""
CANEXECUTE=$FALSE
DRYRUN=$FALSE
ZFSMINDISK=2
ZFSTYPE="mirror"
ZFSDISKCOUNT=0
ZFSDISKLIST[0]=""
UBIQUITY=$FALSE
CONTINUEMODE=$FALSE
# end / Initialize


show_help() {
    cat << EOF
NAME
    mkzfsonlinux.sh v$VERSION - Make ZFS on Linux for Ubuntu / Ubuntu MATE 16.04 / 16.10 Bootable USB Installer

SYNOPSIS
    mkzfsonlinux.sh [-h] [-u] -z <mirror|raidz|raidz2|zraid3> -d <disk0> [...-d <diskn>]
                    [-c <path>|--install] [--uefi] [--yes|dry]

DESCRIPTION
    mkzfsonlinux is based on https://github.com/zfsonlinux/zfs/wiki/Ubuntu%2016.04%20Root%20on%20ZFS

    *** WILL DESTROY DATA - Use at own risk - Only tested in limited scenarios with Ubuntu MATE 16.04.1

    Builds a ZFS pool on supplied disks, creating a minimal bootable environment or copying an existing working install

OPTIONS
    -h|--help   -   Display this help & exit
    -u          -   unmount all ZFS partitions under $ZFSMNTPOINT & exit
    -z <opt>    -   ZFS RAID level to build pool
                        mirror  similiar to RAID1 - minimum of 2 drives required
                                (>2 results in all drives being a mirror of smallest drive size, ie. 4 drives <> RAID10)
                        raidz   similiar to RAID5 - n + 1 drives - minimum of 2 drives, >=3 recommended
                                maximum 1 drive failure for functioning pool
                        raidz2  similiar to RAID6 - n + 2 drives - minimum of 3 drives, >=4 recommended
                                maximum 2 drive failures for functioning pool
                        raidz3  n + 3 drives - minimum of 4 drives, >=5 recommended
                                maximum 3 drive failures for functioning pool
    -d <disk0>  -   Valid drives in /dev/disks/by-id/ to use for ZFS pool
        ...             eg. ata-Samsung_SSD_850_EVO_M.2_250GB_S24BNX0H812345M
    -d <diskn>          or  ata-ST4000DM000-2AE123_ZDH123AA
                    *** All drives passed will be reformatted - ALL partitions & data will be destroyed
    --cp <path> -   Source of working system to copy to new ZFS pool (rsync -avxHAX <path> /mnt) after pool creation
    --install   -   Create /dev/zd0 and launch Ubiquity installer after pool creation
    --uefi      -   Add partition and GRUB support for UEFI boot
    --yes       -   Required to execute repartitioning & ZFS pool build
    --dry       -   Semi-safe execution - will do as much as possible that is non-destructive. Overrides --yes
    --continue  -   Skip all steps (partitioning etc) and go straight to --install or --cp processing

If --yes or --dry are missing, after parsing options, will terminate without deleting anything
If --cp <path> and --install are mutually exclusive, passing both will cause an error
If --continue is used, the ZFS Pool, Disks and/or previously used paramaters must be exactly the same (no checking done)

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


bootstrap_placeholder() {
    # Following is a dump from ZFS on Linux Wiki for future implementation
    ###############

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
    echo $HOSTNAME > /mnt/etc/hostname
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
    locale-gen en_US.UTF-8
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale
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
    #grub-install $DISK1
    #grub-install $DISK2

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

} # bootstrap_placeholder()


install_deps() {
    local APTPKGNAME
    apt-add-repository universe
    apt update
    for APTPKGNAME in $REQPKGS; do
        apt --yes install $APTPKGNAME
    done
} # install_deps()


unmount_zfs() {
    # Unmount filesystems
    printf "/nUnmounting All attached to %s & %s..." "$ZFSMNTPOINT" "$UBIQUITYMNTPOINT"

    # TODO: Change to ZFSMNTPOINT
    mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}

    # TODO: Change to UBIQUITYMNTPOINT
    mount | grep -v zfs | tac | awk '/\/ubuntu-install/ {print $3}' | xargs -i{} umount -lf {}

    zpool export $ZFSPOOL
    printf "Done\n"
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
        partprobe /dev/disk/by-id/$ZFSDISK
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
        partprobe /dev/disk/by-id/$ZFSDISK
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
            partprobe /dev/disk/by-id/$ZFSDISK
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
        partprobe /dev/disk/by-id/$ZFSDISK
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
        partprobe /dev/disk/by-id/$ZFSDISK
        printf "Done\n"
    done
} # partition_tables()


create_pool() {
    local ZPOOLPARAMS=""

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
zpool create -f -o ashift=12 \\
                -O atime=off \\
                -O canmount=off \\
                -O compression=lz4 \\
                -O normalization=formD \\
                -O mountpoint=/ \\
                -R $ZFSMNTPOINT \\
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
        zfs create                  -o setuid=off               $ZFSPOOL/home
        zfs create -o mountpoint=/root                          $ZFSPOOL/home/root
        zfs create -o canmount=off  -o setuid=off   -o exec=off $ZFSPOOL/var
        zfs create -o com.sun:auto-snapshot=false               $ZFSPOOL/var/cache
        zfs create                                              $ZFSPOOL/var/log
        zfs create                                              $ZFSPOOL/var/spool
        zfs create -o com.sun:auto-snapshot=false   -o exec=on  $ZFSPOOL/var/tmp

        ### Optional sets - Comment out ZFS Sets not wanted
        # If you use /srv on this system
        zfs create                                              $ZFSPOOL/srv

        # If you prefer /opt as a set on this system
        zfs create                                              $ZFSPOOL/opt

        # If this system will have games installed:
        zfs create												$ZFSPOOL/var/games

        # If this system will store local email in /var/mail:
        zfs create												$ZFSPOOL/var/mail

        # If this system will use NFS (locking):
        zfs create 	-o com.sun:auto-snapshot=false \
                    -o mountpoint=/var/lib/nfs					$ZFSPOOL/var/nfs
    fi
    printf "Done\n"
} # create_sets()


start_ubiquity() {
    cat << EOF

***********************************************************
UBIQUITY Installer is about to be launched.

*IMPORTANT* Note the following Instructions to correctly install Ubuntu;

    - Choose any options you want
    - When you get to the "Installation Type" screen and select "Something Else"
    - Listed in the drive section, you will see "$UBIQUITYDEVICE" (probably at the bottom)
    - Select it and choose "New Partition Table"
    - Select $UBIQUITYDEVICE Free Space and press the "+" button
    - Select EXT4 and mountpoint=/ In the Bootloader dropdown
    - Select "$UBIQUITYDEVICE" Press "Install Now"
    - Complete the screens for timezone and user account creation etc with your information
    - Near the end of the install, you will get an error about the bootloader not being able to be installed
    - Choose "Continue without a bootloader"
    - At the end of the install select "Continue testing"
***********************************************************
EOF
    read -n 1 -p "Press ENTER to continue..."

    printf "Preparing Environment for Ubiquity Installer..."
    zfs create -V 10G $ZFSPOOL/$UBIQUITYZFSSET
    printf "Done\n"

    printf "Launching Ubiquity Installer...\n"

    $UBIQUITYCMD $UBIQUITYARGS

    printf "Mounting Ubiquity Install Target (%s) to %s..." "$UBIQUITYDEVICE" "$UBIQUITYMNTPOINT"
    sync # Flush writes to disk
    partprobe $UBIQUITYDEVICE
    mkdir -p "$UBIQUITYMNTPOINT"
    mount "$UBIQUITYPART" "$UBIQUITYMNTPOINT"
    if [ $? -ne 0 ]; then
        printf '\nERROR: Failed to Mount Ubiquity Target Partition "%s" to "%s"\n' "$UBIQUITYPART" "$UBIQUITYMNTPOINT" >&2
        exit 1
    fi
    printf "Done\n"

    printf "Transferring Ubiquity Installation to Standard ZFS Pool...\n"
    rsync -avxHAX "$UBIQUITYMNTPOINT/." "$ZFSMNTPOINT/."
        # Options used;
        #   -a  all files, with permissions etc
        #   -v  verbose
        #   -x  stay on one filesystem
        #   -H  preserve hardlinks
        #   -A  preserve ACLs/permissions
        #   -X  preserve extended attributes
    printf "chrooting into environment to update for ZFS support...see you on the other side...\n"
    for d in proc sys dev; do mount --bind /$d $ZFSMNTPOINT/$d; done
    cat << EOF | chroot $ZFSMNTPOINT
echo "nameserver 8.8.8.8" | tee -a /etc/resolv.conf
apt update
apt install --yes zfs zfs-initramfs
sed -i 's|^GRUB_CMDLINE_LINUX=""|GRUB_CMDLINE_LINUX="boot=zfs rpool=$ZFSPOOL bootfs=$ZFSPOOL/ROOT/ubuntu"|' /etc/default/grub
sed -i 's|^\(UUID=.*[[:space:]]/[[:space:]]\)|#\1|' /etc/fstab
exit
EOF
    for ZFSDISK in ${ZFSDISKLIST[@]}; do
        cat << EOF | chroot $ZFSMNTPOINT
        ln -sf "/dev/$ZFSDISK-part1" "/dev/$ZFSDISK"
        update-grub
        grub-install /dev/disk/by-id/$ZFSDISK
        exit
EOF
    done
    printf "\nFinished choot process\n"

    printf "Cleaning up and Creating a snapshot before finishing up..."

    zfs snapshot $ZFSPOOL/ROOT/ubuntu@pre-reboot

    printf "Done\n"

} # start_ubiquity()


copy_source() {
    rsync -avxHAX "$CPWRKENVPATH/." "$ZFSMNTPOINT/."
        # Options used;
        #   -a  all files, with permissions etc
        #   -v  verbose
        #   -x  stay on one filesystem
        #   -H  preserve hardlinks
        #   -A  preserve ACLs/permissions
        #   -X  preserve extended attributes
} # copy_source()


# main()
printf "\nmkZFSonLinux.sh v%s\n" "$VERSION"

while :; do
    case $1 in
        -h|-\?|--help)  # Call a "show_help" function to display a synopsis, then exit.
            show_help
            exit 0
            ;;
        -u|--umount)    # Unmount ZFS from /mnt
            printf "Unmounting ZFS from %s\n" "$ZFSMNTPOINT"
            unmount_zfs
            exit 0
            ;;
        --cp)           # Copy Working Environment - Takes an argument - ensuring it has been specified.
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
            if [ $DRYRUN -eq $TRUE ]; then
                CANEXECUTE=$FALSE
                printf "\tINFO: --dry already specified and overrides --yes\n"
            fi
            shift
            ;;
        --dry)
            printf "\tDry Run Mode Active\n"
            CANEXECUTE=$FALSE
            DRYRUN=$TRUE
            shift
            ;;
        --install)      # Launch Ubiquity Installer
            printf "\tInstall Target /dev/zd0 & Ubiquity will be created & launched\n"
            UBIQUITY=$TRUE
            if [ ! -x "$(which $UBIQUITYCMD)" ]; then
                printf "/tERROR: Ubiquity Command not found (%s %s)\n" "$UBIQUITYCMD" "$UBIQUITYARGS"
                exit 1
            fi
            shift
            ;;
        -z|--zfs)       # ZFS paramenters
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
        -d|--disk)  # Specify a disk/drive to use for ZFS pool
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
        --continue) # Set continue flag to skip partioning and ZFS pool creation
            printf "\tContinue Mode Active - Assuming Mounts, Disks, Partitions & Pools Match 100\% paramaters passed\n"
            CONTINUEMODE=$TRUE
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
    read -n 1 -p "Press ENTER to continue..."
fi

if [ $DRYRUN -eq $FALSE -a $CANEXECUTE -eq $FALSE ]; then
    printf "\nExiting: --yes or --dry not specified"
    exit 0
fi

if [ $CONTINUEMODE -eq $FALSE ]; then
    install_deps
    unmount_zfs
    partition_disks
    create_pool
    create_sets
fi

if [ $UBIQUITY -eq $TRUE ]; then
    start_ubiquity
elif [ $CPWRKENV -eq $TRUE ]; then
    copy_source
fi

unmount_zfs

exit 0

# end / main()
