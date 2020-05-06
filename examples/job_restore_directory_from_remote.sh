#!/usr/bin/env sh

################################### license ##################################
# job_restore_directory_from_remote.sh restores directory in path from onedrive to it's original location, with "_last_snapshot" appended to directory name
# Written in 2018 by Wolfram Volpi, contact at https://github.com/wolfv6/rclone_jobber/issues.
# To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide.
# This software is distributed without any warranty.
# You should have received a copy of the CC0 Public Domain Dedication along with this software. If not, see http://creativecommons.org/publicdomain/zero/1.0/.
# rclone_jobber is not affiliated with rclone.
##############################################################################

#assign relative path of directory to restore
path="relative_path_of_directory_to_restore"

#this script uses these user-defined environment variables: remote
source="${remote}:last_snapshot/$path"
destination="$HOME/${path}_last_snapshot"

cmd="rclone copy $source $destination --dry-run"

echo "$cmd"
echo ">>>>>>>>>>>>>>> Run the above rclone command? (y) <<<<<<<<<<<<<<<<< "
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    eval $cmd  #restore last_snapshot
fi
