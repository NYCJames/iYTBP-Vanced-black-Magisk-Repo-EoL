#!/system/bin/sh

MODDIR=${0%/*}

# Detach/Attach apps from playstore by hinxnz modified for the Youtube Vanced project
# Later modified by MCMotherEffin' for proper Magisk / detach compatibility
# This is an improved version with permanent looping to catch re-attachments of apps since
# newer playstore-app versions do re-attach them (especially youtube app) by scanning for it
# periodically. detachment is done after checking if the entry of the aimed app even is
# available to avoid unnecessary database write access

# How it works
# ------------
# If the file /cache/enable_detach exists the detachment loop starts after booting via magisk's post-fs-data handling
# and does it's thing periodically at a given interval. this is by default once every 180 seconds (this delay can be
# adjusted during runtime by putting a value into the enable_detach file!) which is every 2 mins. unfortunately
# this can't be said exactly because of the influence of sleep  events of the android system, so expect much longer delays
# or even complete stops during that phases! the running loop can be stopped either by deleting the file 'enable_detach'
# in /cache directory (attention apps then stays in a detached state!) or by putting the file disable_detach into
# /cache dir (recommended!) by doing the latter the disabled services are getting enabled again and detached app(s)
# get attached again after some time or after a reboot which is the common normal state. now there is also a log file
# in /cache directory in which u can follow all the important steps done by the script. some defaults and settings can
# be changed and are explained below

# location of playstore app databases
PLAY_DB_DIR=/data/data/com.android.vending/databases;

# sqlite binary location. specify a directory for example when not using the magisk post-fs-data handling (aka manual mode)
SQLITE_DIR=$MODDIR;

# default package name of app which should get detached (used here for stock youtube app)
DEF_PKG_NAME=com.google.android.youtube;

# detach option file to enable detachment
DETACH_ENABLED=/cache/enable_detach;

# 'soft' detach option file for detaching without touching any services
SOFT_DETACH=/cache/soft_detach;

# attach option file to disable detachment (overrules detach option file!)
DETACH_DISABLED=/cache/disable_detach;

# option file which makes the script 'one shot' instead of looping (=manual mode for external execution)
NOLOOP=/cache/noloop_detach;

# custom detach file which can contain custom package names to detach (optional) NOTE: u have to terminate the list with a empty line
CUSTOM_DETACH=/cache/custom_detach;

# location and name of the log file
LOGFILE=/cache/detach.log;

# maximal entries in the log file after which it gets automatically flushed
MAX_LOG_ENTRIES=250;

# counter for log entries (initial, don't change that value)
LOG_ENTRIES=0;

# default amount of seconds for delay (decrease this for faster checks, increase it for slower checks)
LOOP_DELAY=180;

# NOTE: u can overwrite this during runtime by putting a value into the /cache/enable_detach file
# the default value below is used for the initial start delay of 60 seconds after boot and the second
# default delay (LOOP_DELAY) of 180 = 3 mins is used for the delay of the running loop
DELAY=60;

logcount() {
LOG_ENTRIES=$((LOG_ENTRIES+1));
if [[ "$LOG_ENTRIES" -gt "$MAX_LOG_ENTRIES" ]]; then
    echo "--- LOG FLUSHED" `date` > $LOGFILE;
    LOG_ENTRIES=1;
fi;
}

check() {
CHECK=`./sqlite /data/data/com.android.vending/databases/library.db "SELECT doc_id FROM ownership WHERE doc_id = '$PKGNAME'";`
}

detach_prepare() {
if [ ! -z "$CHECK" ]; then
    if [ ! -e $SOFT_DETACH ]; then
	pm disable 'com.android.vending/com.google.android.finsky.hygiene.DailyHygiene$DailyHygieneService';
    else
	echo -n `date +%H:%M:%S` >> $LOGFILE;
	echo " - Soft detachment is used, no services changed!" >> $LOGFILE;
    fi;
    am force-stop com.android.vending;
fi;
}

detach() {
if [ ! -z "$CHECK" ]; then
    ./sqlite $PLAY_DB_DIR/library.db "DELETE from ownership where doc_id = '$PKGNAME'";
    ./sqlite $PLAY_DB_DIR/localappstate.db "DELETE from appstate where package_name = '$PKGNAME'";
    echo -n `date +%H:%M:%S` >> $LOGFILE;
    echo " - $PKGNAME DETACHED!" >> $LOGFILE;
    logcount;
else
    echo -n `date +%H:%M:%S` >> $LOGFILE;
    echo " - $PKGNAME NOT FOUND!" >> $LOGFILE;
    logcount;
fi;
}

if [ ! -e $DETACH_ENABLED ] && [ ! -e $DETACH_DISABLED ]; then
    echo "" > $LOGFILE;
    echo "No option files found in /cache! nothing to do!" >> $LOGFILE;
    echo "You have to put at least a file called 'enable_detach'" >> $LOGFILE;
    echo "into /cache directory to make things start" >> $LOGFILE;
    echo "Exiting the script now, no further execution until next boot" >> $LOGFILE;
    exit 1;
fi;

# detach is used so set a flag for universal installer to avoid conflicts
echo "Please keep this file! It's a flag for the YTVA universal installer" > /data/ytva-magisk-detach-enabled

(
while [ 1 ]; do
    if [ `getprop sys.boot_completed` = 1 ]; then
	if [ ! -e $NOLOOP ]; then
	    sleep $DELAY;
	fi;
	if [ "$LOG_ENTRIES" = 0 ] && [ ! -e $NOLOOP ]; then
	    echo "--- LOOP STARTED" `date` > $LOGFILE;
	    echo -n `date +%H:%M:%S` >> $LOGFILE;
	    echo " - Next check in $DELAY seconds" >> $LOGFILE;
	fi;
	if [ -e $DETACH_DISABLED ]; then
	    if [ ! -e $SOFT_DETACH ]; then
		pm enable 'com.android.vending/com.google.android.finsky.dailyhygiene.DailyHygiene'$'DailyHygieneService\';
		pm enable 'com.android.vending/com.google.android.finsky.hygiene.DailyHygiene'$'DailyHygieneService\';
		am startservice 'com.android.vending/com.google.android.finsky.dailyhygiene.DailyHygiene'$'DailyHygieneService\';
		am startservice 'com.android.vending/com.google.android.finsky.hygiene.DailyHygiene'$'DailyHygieneService\';
	    fi;
	    rm -f $DETACH_ENABLED;
	    rm -f $DETACH_DISABLED;
	    rm -f $SOFT_DETACH;
	    rm -f /data/ytva-magisk-detach-enabled
	    echo -n `date +%H:%M:%S` >> $LOGFILE;
	    echo "" >> $LOGFILE;
	    echo "All disabled services enabled again, apps should get attached to playstore again soon!" >> $LOGFILE;
	    echo "NOTE: Enabling of detachment removed from subsequent boot" >> $LOGFILE;
	    echo "Exiting the loop now, no further execution until next boot" >> $LOGFILE;
	    echo "--- LOOP STOPPED" `date` >> $LOGFILE;
	    break;
	elif [ -e $DETACH_ENABLED ]; then
	    cd $SQLITE_DIR;
	    check;
	    if [ ! -e $NOLOOP ]; then
		DELAY=`cat $DETACH_ENABLED`;
		if [ -z "$DELAY" ]; then
		    DELAY=$LOOP_DELAY;
		fi;
	    fi;
	    if [ -e $CUSTOM_DETACH ]; then
		detach_prepare;
	        while read -r PKGNAME; do
		    if [ ! -z "$PKGNAME" ]; then
			detach;
		    fi;
		done < "$CUSTOM_DETACH"
	    elif [ ! -z $DEF_PKG_NAME ]; then
		PKGNAME=$DEF_PKG_NAME;
		detach_prepare;
	        detach;
	    elif [ -z $DEF_PKG_NAME ]; then
		echo "No app package name(s) defined! exiting..." >> $LOGFILE;
		break;
	    fi;
	fi;
	if [ ! -e $DETACH_ENABLED ] && [ ! -e $DETACH_DISABLED ]; then
	    echo -n `date +%H:%M:%S` >> $LOGFILE;
	    echo "" >> $LOGFILE;
	    echo "All option files removed from /cache dir!" >> $LOGFILE;
	    echo "NOTE: if apps were already detached they stay in that state! If u want to" >> $LOGFILE;
	    echo "attach it again put a empty file named 'disable_detach' into /cache dir and reboot" >> $LOGFILE;
	    echo "Exiting the loop now, no further execution until next boot" >> $LOGFILE;
	    echo "--- LOOP STOPPED" `date` >> $LOGFILE;
	    break;
	fi;
	if [ ! -e $NOLOOP ]; then
	    echo -n `date +%H:%M:%S` >> $LOGFILE;
	    echo " - Next check in $DELAY seconds" >> $LOGFILE;
	    logcount;
	else
	    echo -n `date +%H:%M:%S` >> $LOGFILE;
	    echo " - Manual execution, next check defined externally" >> $LOGFILE;
	    logcount;
	    break;
	fi;
    else
	sleep 1;
    fi;
done &)
