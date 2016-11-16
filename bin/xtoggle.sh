#!/usr/bin/env bash
# xToggle - cycle through different XRandR configs
# see <command> -h for info/help
#
# v0.10
#
# Initial version for LVDS1 & VGA1 only Current state drives next state to select
#
# Cycle;
# 	1. LVDS1 Only
#	2. VGA1 Only
#	3. LVDS1 (Left) & VGA1 (Right) Extended Desktop
#

# TODO: Decide between cycling through attached displays in a predicable manner or through saved configs in ~/.screenlayouts?

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

# Get connected displays
CONNECTED="$(xrandr | grep ' connected ')"

echo "Connected ="
echo $CONNECTED
echo ""
# Get connected & off displays - Has no resolution
CONNECTEDOFF="$(xrandr | grep ' connected (')"

echo "ConnectedOff ="
echo $CONNECTEDOFF
echo ""
 
# Check if VGA1 Connected
if echo $CONNECTED | grep -q "VGA1"; then
	echo "VGA1 confirmed connected"
	# VGA1 Connected & off then VGA1 Only
	if echo $CONNECTED | grep -q "VGA1" && echo $CONNECTEDOFF | grep -q "VGA1"; then
		echo "VGA1 connected & off - Switching to VGA1..."
		xrandr --output VGA1 --auto --preferred --primary --output LVDS1 --off
	# LVDS1 Connected & off then Extended Desktop Only
	elif echo $CONNECTED | grep -q "LVDS1" && echo $CONNECTEDOFF | grep -q "LVDS1"; then
		echo "LVDS1 connected & off - Switching to Extended Desktop..."
		xrandr --output LVDS1 --auto --output VGA1 --auto --primary --preferred --right-of LVDS1
	# Extended Desktop then LVDS1 Only
	elif echo $CONNECTED | grep -qv ' connected ('; then
		echo "Nothing Connected & Off, so switch to LVDS1 Only..."
		xrandr --output LVDS1 --auto --preferred --primary --output VGA1 --off
	fi
# No External VGA1, so assume LVDS1 only
else
	echo "No external Monitor - Autoconfig..."
	xrandr --auto
fi

exit 0

# end / main()

