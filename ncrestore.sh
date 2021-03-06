#!/bin/sh

. ./helpers.sh

#----------globals------------------
export BORG_REPO="/home/art2/backup1"
export BORG_PASSPHRASE="`cat ./secret.txt`"
postgres_address_str="`cat ./postgress_secret.txt`"

#----------parameters------------------
extract_temp_dir="/home/art2/temp"

webserver_user="www-data"
webserver_service_name="nginx"

borg_archive=$1

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
exit 1
fi

if [ -z "${borg_archive}" ]
  then
    echo "No borg archive supplied"
exit 1
fi

#----------program------------------
stage "Checking conditions..."
check_root
echo

stage "Preparing..."
enable_maintenance_mode
stop_web_server
echo

stage "Executing..."
info "Extracting archive"
clear_directory ${extract_temp_dir}
cd ${extract_temp_dir} && borg extract -v --list ::"${borg_archive}"
info "Done"

info "Replacing current nextcloud with one from backup"
clear_directory ${nextcloudDataDir}
copy_from_one_directory_to_another ${extract_temp_dir}/${nextcloudDataDir} ${nextcloudDataDir}
copy_from_one_directory_to_another ${extract_temp_dir}/${nextcloudFileDir} ${nextcloudFileDir}
info

#
# Restore database
#
restore_database

#
# Set directory permissions
#
echo "Setting directory permissions..."
chown -R "${webserver_user}":"${webserver_user}" "${nextcloudFileDir}"
chown -R "${webserver_user}":"${webserver_user}" "${nextcloudDataDir}"
echo "Done"
echo

start_web_server

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/12/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "Updating the system data-fingerprint..."
cd "${nextcloudFileDir}" && sudo -u "${webserver_user}" php occ maintenance:data-fingerprint
echo "Done"

stage "Restoring state..."
disable_maintenance_mode

stage "DONE!"
