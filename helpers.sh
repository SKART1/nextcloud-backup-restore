#!/bin/sh

#---------parameters
nextcloudFileDir="/var/www/nextcloud"
nextcloudDataDir="/var/nc-data"
db_dump_dir="/home/art/temp"
db_dump_filename="nextcloud-db.sql"

#----------helpers------------------
stage() {
  printf "%s %s\n" "$( date )" "$*" >&1;
}

info() {
  echo "\t$@";
}

error_echo() {
  echo "$@\n">&2;
}

check_already_running() {
  if pidof -x borg >/dev/null; then
    echo "Backup already running"
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

clear_directory() {
  rm -R $1
}

copy_from_one_directory_to_another() {
  cp -R $1/. $2/
}

enable_maintenance_mode() {
  info "Enabling maintenance mode"
  cd "${nextcloudFileDir}" && sudo -u "${webserver_user}" php occ maintenance:mode --on 1>/dev/null
  info "Done"
}

stop_web_server() {
  info "Stopping web-server"
  service "${webserver_service_name}" stop
  info "Done"
}

dump_database() {
  info "Backup Nextcloud database"
  docker exec -t -u postgres postgres pg_dumpall -c > "${tempdir}/${db_dump_filename}"
  info "Done"
}

create_main_dump() {
  info "Creating backup"
  borg create                             \
      --verbose                           \
      --filter AME                        \
      --list                              \
      --stats                             \
      --show-rc                           \
      --compression lz4                   \
      ::'{hostname}-{now}'                \
      ${nextcloudFileDir}/config          \
      ${nextcloudFileDir}/themes          \
      ${nextcloudDataDir}                 \
      ${db_dump_dir}/${db_dump_filename}  \
      --exclude-caches                    \
      --exclude '*.log'                   \
      --exclude '*.log.*'                 \
      --exclude "$exclude_updater"        \
      --exclude "$exclude_updater_hidden" \
      --exclude "$exclude_versions_dir"
  info "Done"
  return res
}

disable_maintenance_mode() {
  info "Disabling maintenance mode"
  cd "${nextcloudFileDir}" && sudo -u "${webserver_user}" php occ maintenance:mode --off
  info "Done"
}

start_web_server() {
  info "Starting web server"
  service "${webserver_service_name}" start
  info "Done"
}

delete_database_backup() {
  info "Remove the db backup file"
  rm ${db_dump_dir}/${db_dump_filename}
  info "Done"
}

pruning_repository() {
  info "Pruning repository"
  res = borg prune                          \
            --list                          \
            -v                              \
            --prefix '{hostname}-'          \
            --show-rc                       \
            --keep-daily=5                  \
            --keep-weekly=2                 \
            --keep-monthly=1
  info "Done"
  return res
}
