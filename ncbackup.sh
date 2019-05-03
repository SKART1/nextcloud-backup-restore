#!/bin/sh

. ./helpers.sh

#Exit on any error
set -e

trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM


#----------globals------------------
export BORG_REPO=/home/art/backup1
export BORG_PASSPHRASE="`cat ./secret.txt`"


#----------parameters------------------
tempdir="/home/art/dbdump"
dbdumpfilename=$(hostname)-nextcloud-db.sql-$(date +"%Y-%m-%d_%H:%M:%S")

exclude_updater="$nextcloudDataDir/updater-*"
exclude_updater_hidden="$nextcloudDataDir/updater-*/.*"
exclude_versions_dir="$nextcloudDataDir*/files_versions/*"

webserverUser="www-data"
webserverServiceName="nginx"

#----------program------------------
info "Checking conditions..."
check_already_running
check_root
echo

info "Preparing..."
enable_maintenance_mode
stop_web_server
echo

info "Executing..."
dump_database
backup_exit=$(create_main_dump)
echo

info "Restoring state..."
disable_maintenance_mode
start_web_server
echo

info "Cleaning..."
delete_database_backup
prune_exit=$(pruning_repository)
echo

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

if [ ${global_exit} -eq 1 ];
then
    info "Backup and/or Prune finished with a warning"
fi

if [ ${global_exit} -gt 1 ];
then
    info "Backup and/or Prune finished with an error"
fi

#
# send email. Uncomment the below line to send an email. This requires you first setup a MTA
# To send mail, setup your cron script
# like this: 55 23 * * * /root/backup.sh > /home/<user>/backup.txt 2>&1
#
# mail -s "Nextcloud Backup" youremail@yourdomain.com < /home/<user>/backup.txt
exit ${global_exit}

info "DONE!"
