#!/bin/sh

#---------parameters
nextcloudFileDir="/var/www/nextcloud"
nextcloudDataDir="/var/nc-data"
db_dump_dir="/home/art/temp"
db_dump_filename="nextcloud-db.sql"

nextcloudDatabase="nextcloud"


#----------helpers------------------
stage() {
  printf "%s %s\n" "$( date )" "$*" >&1;
}

info() {
  printf "\t$@\n";
}

append_tab() {
   sed 's/^/\t/'
}

error_echo() {
  printf "$@\n">&2;
}

check_already_running() {
  if pidof -x borg >/dev/null; then
    error_echo "Backup already running"
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
  rm -Rf $1/*
}

copy_from_one_directory_to_another() {
  cp -R $1/. $2/
}

enable_maintenance_mode() {
  info "Enabling maintenance mode"
  sudo -u "${webserver_user}" php ${nextcloudFileDir}/occ maintenance:mode --on | append_tab
  info "Done\n"
}

stop_web_server() {
  info "Stopping web-server"
  service "${webserver_service_name}" stop | append_tab
  info "Done\n"
}

dump_database() {
  info "Backup Nextcloud database"
  pg_dump ${postgres_address_str}/${nextcloudDatabase} > "${db_dump_dir}/${db_dump_filename}" | append_tab
  info "Done\n"
}

dump_docker_database() {
  info "Backup Nextcloud database"
  docker exec -t -u postgres postgres pg_dumpall -c > "${db_dump_dir}/${db_dump_filename}" | append_tab
  info "Done\n"
}

restore_database() {
  info "Restoring Nextcloud database"
  cat ${extract_temp_dir}/${db_dump_dir}/${db_dump_filename} | pg_restore --dbname=${postgres_address_str}/${nextcloudDatabase}
  info "Done\n"
}

restore_docker_database() {
  echo
  echo "Dropping old and recreating Nextcloud DB..."
  docker exec -it postgres psql -U postgres -c "DROP DATABASE ${nextcloudDatabase}"
  docker exec -it postgres psql -U postgres -c "CREATE DATABASE ${nextcloudDatabase}"
  echo "Done"
  echo

  echo "Restoring backup DB..."
  cat ${extract_temp_dir}/${db_dump_dir}/${db_dump_filename} | docker exec -i postgres psql -U postgres -d ${nextcloudDatabase}
  echo "Done"
  echo
}

create_main_dump() {
  info "Creating backup"
  borg create                               \
      --verbose                             \
      --filter AME                          \
      --list                                \
      --stats                               \
      --show-rc                             \
      --compression auto,zstd,6             \
      ::{hostname}-{now}                    \
      ${nextcloudFileDir}/config            \
      ${nextcloudFileDir}/themes            \
      ${nextcloudDataDir}                   \
      ${db_dump_dir}/${db_dump_filename}    \
      --exclude-caches                      \
      --exclude '*.log'                     \
      --exclude '*.log.*'                   \
      --exclude "${exclude_updater}"        \
      --exclude "${exclude_updater_hidden}" \
      --exclude "${exclude_versions_dir}"   \
      --exclude "${exclude_trash_dir}" 2>&1 | append_tab
  local res=$?
  info "Done\n"
  return ${res}
}

disable_maintenance_mode() {
  info "Disabling maintenance mode"
  sudo -u "${webserver_user}" php ${nextcloudFileDir}/occ maintenance:mode --off | append_tab
  info "Done\n"
}

start_web_server() {
  info "Starting web server"
  service "${webserver_service_name}" start | append_tab
  info "Done\n"
}

delete_database_backup() {
  info "Remove the db backup file"
  rm ${db_dump_dir}/${db_dump_filename} | append_tab
  info "Done\n"
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
      --keep-monthly=1 2>&1 | append_tab
  local res=$?
  info "Done\n"
  return ${res}
}
