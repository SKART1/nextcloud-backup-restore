#!/bin/sh

. ./helpers.sh

#Exit on any error
set -e

trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM


#----------globals------------------
export BORG_REPO=/home/art/backup1
export BORG_PASSPHRASE="`cat ./secret.txt`"


#----------parameters------------------
exclude_updater="$nextcloudDataDir/updater-*"
exclude_updater_hidden="$nextcloudDataDir/updater-*/.*"
exclude_versions_dir="$nextcloudDataDir*/files_versions/*"

webserver_user="www-data"
webserver_service_name="nginx"

#----------program------------------
stage "Checking conditions..."
check_already_running
echo

stage "Preparing..."
enable_maintenance_mode
stop_web_server
echo

stage "Executing..."
dump_database
create_main_dump
prune_exit=$?
echo

stage "Restoring state..."
disable_maintenance_mode
start_web_server
echo

stage "Cleaning..."
delete_database_backup
pruning_repository
prune_exit=$?
echo

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 1 ];
then
    stage "Backup and/or Prune finished with a warning"
fi

if [ ${global_exit} -gt 1 ];
then
    stage "Backup and/or Prune finished with an error"
fi

stage "DONE!"

#
# send email. Uncomment the below line to send an email. This requires you first setup a MTA
# To send mail, setup your cron script
# like this: 55 23 * * * /root/backup.sh > /home/<user>/backup.txt 2>&1
#
# mail -s "Nextcloud Backup" youremail@yourdomain.com < /home/<user>/backup.txt
exit ${global_exit}
