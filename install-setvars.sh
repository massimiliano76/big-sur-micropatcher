#!/bin/bash

### begin function definitions ###

# Check that we can access the directory that ocntains this script, as well
# as the root directory of the installer USB. Access to both of these
# directories is vital, and Catalina's TCC controls for Terminal are
# capable of blocking both. Therefore we must check access to both
# directories before proceeding.
checkDirAccess() {
    # List the two directories, but direct both stdout and stderr to
    # /dev/null. We are only interested in the return code.
    ls "$VOLUME" . &> /dev/null
}

### end function definitions ###

# Make sure there isn't already an "EFI" volume mounted.
if [ -d "/Volumes/EFI" ]
then
    echo 'An "EFI" volume is already mounted. Please unmount it then try again.'
    echo "If you don't know what this means, then restart your Mac and try again."
    echo
    echo "install-setvars cannot continue."
    exit 1
fi

# For this script, root permissions are vital.
[ $UID = 0 ] || exec sudo "$0" "$@"

if [ "x$1" = "x-v" -o "x$1" = "x--verbose" ]
then
    VERBOSEBOOT="YES"
    echo 'Verbose boot option enabled.'
    shift
fi

# Allow the user to drag-and-drop the USB stick in Terminal, to specify the
# path to the USB stick in question. (Otherwise it will try hardcoded paths
# for a presumed Big Sur Golden Master/public release, beta 2-or-later,
# and beta 1, in that order.)
if [ -z "$1" ]
then
    for x in "Install macOS Big Sur" "Install macOS Big Sur Beta" "Install macOS Beta"
    do
        if [ -d "/Volumes/$x/$x.app" ]
        then
            VOLUME="/Volumes/$x"
            APPPATH="$VOLUME/$x.app"
            break
        fi
    done

    if [ ! -d "$APPPATH" ]
    then
        echo "Failed to locate Big Sur recovery USB stick."
        echo Remember to create it using createinstallmedia, and do not rename it.
        echo "If all else fails, try specifying the path to the USB stick"
        echo "as a command line parameter to this script."
        echo
        echo "install-setvars cannot continue and will now exit."
        exit 1
    fi
else
    VOLUME="$1"
    # The use of `echo` here is to force globbing.
    APPPATH=`echo -n "$VOLUME"/Install\ macOS*.app`
    if [ ! -d "$APPPATH" ]
    then
        echo "Failed to locate Big Sur recovery USB stick for patching."
        echo "Make sure you specified the correct volume. You may also try"
        echo "not specifying a volume and allowing the patcher to find"
        echo "the volume itself."
        echo
        echo "install-setvars cannot continue and will now exit."
        exit 1
    fi
fi

# Check if the payloads directory is inside the current directory. If not,
# it's probably inside the same directory as this script, so find that
# directory.
if [ ! -d payloads ]
then
    BASEDIR="`echo $0|sed -E 's@/[^/]*$@@'`"
    [ -z "$BASEDIR" ] || cd "$BASEDIR"
fi

# Check again in case we changed directory after the first check
if [ ! -d payloads ]
then
    echo '"payloads" folder was not found.'
    echo
    echo "install-setvars cannot continue and will now exit."
    exit 1
fi

# Check to make sure we can access both our own directory and the root
# directory of the USB stick. Terminal's TCC permissions in Catalina can
# prevent access to either of those two directories. However, only do this
# check on Catalina or higher. (I can add an "else" block later to handle
# Mojave and earlier, but Catalina is responsible for every single bug
# report I've received due to this script lacking necessary read permissions.)
if [ `uname -r | sed -e 's@\..*@@'` -ge 19 ]
then
    echo 'Checking read access to necessary directories...'
    if ! checkDirAccess
    then
        echo 'Access check failed.'
        tccutil reset All com.apple.Terminal
        echo 'Retrying access check...'
        if ! checkDirAccess
        then
            echo
            echo 'Access check failed again. Giving up.'
            echo 'Next time, please give Terminal permission to access removable drives,'
            echo 'as well as the location where this patcher is stored (for example, Downloads).'
            exit 1
        else
            echo 'Access check succeeded on second attempt.'
            echo
        fi
    else
        echo 'Access check succeeded.'
        echo
    fi
fi

MOUNTEDPARTITION=`mount | fgrep "$VOLUME" | awk '{print $1}'`
if [ -z "$MOUNTEDPARTITION" ]
then
    echo Failed to find the partition that
    echo
    echo is mounted from. install-setvars cannot proceed.
    exit 1
fi

DEVICE=`echo -n $MOUNTEDPARTITION | sed -e 's/s[0-9]*$//'`
PARTITION=`echo -n $MOUNTEDPARTITION | sed -e 's/^.*disk[0-9]*s//'`
echo $DEVICE $PARTITION

if [ "x$PARTITION" = "x1" ]
then
    echo "The volume $VOLUME"
    echo "appears to be on partition 1 of the USB stick, therefore the stick is"
    echo "incorrectly partitioned (possibly MBR instead of GPT?)."
    echo "Please refer to the micropatcher README or other documentation for more"
    echo "information."
    echo
    echo "install-setvars cannot continue."
    exit 1
fi

diskutil mount ${DEVICE}s1
if [ ! -d "/Volumes/EFI" ]
then
    echo "Partition 1 of the USB stick does not appear to be an EFI partition, or"
    echo "mounting of the partition somehow failed."
    echo "Please refer to the micropatcher README or other documentation for more"
    echo "information."
    echo
    echo "install-setvars cannot continue."
fi

if [ "x$VERBOSEBOOT" = "xYES" ]
then
    cp -r setvars/EFI-verboseboot /Volumes/EFI/EFI
else
    cp -r setvars/EFI /Volumes/EFI/EFI
fi

umount /Volumes/EFI || diskutil unmount /Volumes/EFI

echo
echo 'Syncing.'
sync

echo
echo 'install-setvars finished.'
