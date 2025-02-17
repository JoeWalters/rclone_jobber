#!/usr/bin/env sh
# rclone_jobber.sh version 1.5.6
# Tutorial, backup-job examples, and source code at https://github.com/JoeWalters/rclone_jobber
# Logging options are headed by "# set log".  Details are in the tutorial's "Logging options" section.

################################### license ##################################
# rclone_jobber.sh is a script that calls rclone sync to perform a backup.
# Written in 2018 by Wolfram Volpi, contact at https://github.com/wolfv6/rclone_jobber/issues
# To the extent possible under law, the author(s) have dedicated all copyright and related and
# neighboring rights to this software to the public domain worldwide.
# This software is distributed without any warranty.
# You should have received a copy of the CC0 Public Domain Dedication along with this software.
# If not, see http://creativecommons.org/publicdomain/zero/1.0/.
# rclone_jobber is not affiliated with rclone.

################################### help #####################################
Help()
{
   # Display Help
   echo "Add description of the script functions here."
   echo
   echo "Syntax: rclone_jobber.sh -[s|d|f|o|u|h]"
   echo "options:"
   echo "s     Directory to back up (without a trailing slash)."
   echo 'd     Directory to back up to (without a trailing slash or "last_snapshot")'
   echo "f     move_old_files_to is one of:"
   echo '        "dated_directory" - move old files to a dated directory (an incremental backup)'
   echo '        "dated_files"     - move old files to old_files directory, and append move date to file names (an incremental backup)'
   echo '        ""                - old files are overwritten or deleted (a plain one-way sync backup)'
   echo 'o     Rclone options like "--filter-from=filter_patterns --checksum --log-level="INFO" --dry-run"'
   echo '        do not put these in options: --backup-dir, --suffix, --log-file'
   echo "u     Cron monitoring service URL to send email if cron failure or other error prevented back up"
   echo "h     This menu."
   echo
   echo "Example: rclone_jobber.sh -s /home/bobby -d crypt-gdrive:path/bobby"
   echo
}

############################# Get Opts/Parameters #############################

# Get the options
while getopts ":hs:d:f:o:u:" option; do
   case $option in
      s) # source
         source="$OPTARG";;
      d) # destination
         dest="$OPTARG";;
      f) # move old files to
         move_old_files_to="$OPTARG";;
      o) # options
         options="$OPTARG";;
      u) # monitoring url
         monitoring_URL="$OPTARG";;
      h) # display Help
         Help
         exit;;
      \?) # Invalid option
         echo "Error: Invalid option"
         Help
         exit;;
      :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
      *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
   esac
done

job_name="$5"          #job_name="$(basename $0)"

################################ set variables ###############################
# $new is the directory name of the current snapshot
# $timestamp is time that old file was moved out of new (not time that file was copied from source)
new="last_snapshot"
timestamp="$(date +%Y%m%d_%H%M)" # Example 20210901_1754 = Sept 01, 2021 at 5:54pm.

# set log_file path
path="$(realpath "$0")"                 #this will place log in the same directory as this script
log_file="${path%.*}.log"               #replace path extension with "log"
#log_file="/var/log/rclone_jobber.log"  #for Logrotate

# set log_option for rclone
log_option="--log-file=$log_file"       #log to log_file
#log_option="--syslog"                  #log to systemd journal

################################## functions #################################
send_to_log()
{
    msg="$1"

    # set log - send msg to log
    echo "$msg" >> "$log_file"                             #log msg to log_file
    #printf "$msg" | systemd-cat -t RCLONE_JOBBER -p info   #log msg to systemd journal
}

# print message to echo, log, and popup
print_message()
{
    urgency="$1"
    msg="$2"
    message="${urgency}: $job_name $msg"

    echo "$message"
    send_to_log "$(date +%F_%T) $message"
    warning_icon="/usr/share/icons/Adwaita/32x32/emblems/emblem-synchronizing.png"   #path in Fedora 28
    # notify-send is a popup notification on most Linux desktops, install libnotify-bin
    command -v notify-send && notify-send --urgency critical --icon "$warning_icon" "$message"
}

################################# range checks ################################
# if source is empty string
if [ -z "$source" ]; then
    print_message "ERROR" "aborted because source is empty string."
    exit 1
fi

# if dest is empty string
if [ -z "$dest" ]; then
    print_message "ERROR" "aborted because dest is empty string."
    exit 1
fi

# if source is empty
if ! test "rclone lsf --max-depth 1 $source"; then  # rclone lsf requires rclone 1.40 or later
    print_message "ERROR" "aborted because source is empty."
    exit 1
fi

## If this script is already running, exit
for pid in $(pidof -x $(basename "$0")); do
    if [ $pid != $$ ]; then
        echo "$(basename $0) : Process is already running with PID $pid"
        exit 1
    fi
done

############################### move_old_files_to #############################
# deleted or changed files are removed or moved, depending on value of move_old_files_to variable
# default move_old_files_to="" will remove deleted or changed files from backup
if [ "$move_old_files_to" = "dated_directory" ]; then
    # move deleted or changed files to archive/$(date +%Y)/$timestamp directory
    backup_dir="--backup-dir=$dest/archive/$(date +%Y)/$timestamp"
elif [ "$move_old_files_to" = "dated_files" ]; then
    # move deleted or changed files to old directory, and append _$timestamp to file name
    backup_dir="--backup-dir=$dest/old_files --suffix=_$timestamp"
elif [ "$move_old_files_to" != "" ]; then
    print_message "WARNING" "Parameter move_old_files_to=$move_old_files_to, but should be dated_directory or dated_files.\
  Moving old data to dated_directory."
    backup_dir="--backup-dir=$dest/$timestamp"
fi

################################### back up ##################################
cmd="rclone sync $source $dest/$new $backup_dir $log_option $options"

# progress message
echo "Back up in progress $timestamp $job_name"
echo "$cmd"

# set logging to verbose
#send_to_log "$timestamp $job_name"
#send_to_log "$cmd"

eval $cmd
exit_code=$?

############################ confirmation and logging ########################
if [ "$exit_code" -eq 0 ]; then            #if no errors
    confirmation="$(date +%F_%T) completed $job_name"
    echo "$confirmation"
    send_to_log "$confirmation"
    send_to_log ""
    if [ -n "$monitoring_URL" ]; then
        wget --quiet "$monitoring_URL" -O /dev/null
    fi
    exit 0
else
    print_message "ERROR" "failed.  rclone exit_code=$exit_code"
    send_to_log ""
    exit 1
fi
