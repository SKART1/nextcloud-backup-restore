#!/bin/sh
#Exit on any error
set -e

#----------globals------------------
export BORG_REPO=/home/art/backup1
export BORG_PASSPHRASE="`cat secret.txt`"


#----------parameters------------------
# nextcloud vars
nextcloudFileDir="/var/www/nextcloud"
nextcloudDataDir="/var/nc-data"

#temp variables
tempdir="/home/art/dbdump"
dbdumpfilename=$(hostname)-nextcloud-db.sql-$(date +"%Y-%m-%d_%H:%M:%S")

# exclude files and folders. They vars are then appended to borg create
exclude_updater="$nextcloudDataDir/updater-*"
exclude_updater_hidden="$nextcloudDataDir/updater-*/.*"
exclude_versions_dir="$nextcloudDataDir*/files_versions/*"

# webserver vars
webserverUser="www-data"
webserverServiceName="nginx"


#----------helpers------------------
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

info() {
  printf "\n%s %s\n" "$( date )" "$*" >&1;
}

error_echo() {
  echo "$@\n">&2;
}

check_already_running() {
  if pidof -x borg >/dev/null; then
    echo "Backup already running"
    #mail -s "Nextcloud Backup. Borg already running." youremail@yourdomain < /home/pi/scripts/backup.txt
    exit 1
  fi
}

check_root() {
  if [ "$(id -u)" != "0" ]
  then
  	error_echo "ERROR: This script has to be run as root!"
  	exit 1
  fi
}

enable_maintenance_mode() {
  info "Enabling maintenance mode"
  cd "${nextcloudFileDir}" && sudo -u "${webserverUser}" php occ maintenance:mode --on
  info "Done"
}

stop_web_server() {
  info "Stopping web-server"
  service "${webserverServiceName}" stop
  info "Done"
}

dump_database() {
  info "Backup Nextcloud database"
  docker exec -t -u postgres postgres pg_dumpall -c > "${tempdir}/${dbdumpfilename}"
  info "Done"
}

create_main_dump() {
  borg create                             \
      --verbose                           \
      --filter AME                        \
      --list                              \
      --stats                             \
      --show-rc                           \
      --compression lz4                   \
      ::'{hostname}-{now}'                \
      $nextcloudFileDir/config            \
      $nextcloudFileDir/themes            \
      $nextcloudDataDir                   \
      $tempdir                            \
      --exclude-caches                    \
      --exclude '*.log'                   \
      --exclude '*.log.*'                 \
      --exclude "$exclude_updater"        \
      --exclude "$exclude_updater_hidden" \
      --exclude "$exclude_versions_dir"
}

disable_maintenance_mode() {
  info "Disabling maintenance mode"
  cd "${nextcloudFileDir}" && sudo -u "${webserverUser}" php occ maintenance:mode --off
  info "Done"
}

start_web_server() {
  info "Starting web server"
  service "${webserverServiceName}" start
  info "Done"
}

delete_database_backup() {
  info "Remove the db backup file"
  rm ${tempdir}/${dbdumpfilename}
  info "Done"
}

pruning_repository() {
  info "Pruning repository"
  borg prune                          \
      --list                          \
      -v                              \
      --prefix '{hostname}-'          \
      --show-rc                       \
      --keep-daily=5                  \
      --keep-weekly=2                 \
      --keep-monthly=1                \
  info "Done"
}

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
