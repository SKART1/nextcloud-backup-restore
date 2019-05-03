#!/bin/sh

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

info() {
  printf "%s %s\n" "$( date )" "$*" >&1;
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
      $tempdir/$dbdumpfilename            \
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
  borg prune                          \
      --list                          \
      -v                              \
      --prefix '{hostname}-'          \
      --show-rc                       \
      --keep-daily=5                  \
      --keep-weekly=2                 \
      --keep-monthly=1
}
