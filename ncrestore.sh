#!/bin/sh

. ./helpers.sh

#----------globals------------------
export BORG_REPO=/home/art2/backup1
export BORG_PASSPHRASE="`cat ./secret.txt`"


#----------parameters------------------
extractTempDir="/home/art2/temp"

webserverUser="www-data"
webserverServiceName="nginx"



#-------------------actions----
check_root

#
# Bash script for restoring backups of Nextcloud.
# Usage: ./ncrestore.sh -a '<borg archive to restore>' -d '<database dump file>'
#
while getopts a:d: option
do
 case "${option}"
 in
 a) borg_archive=${OPTARG};;
 d) fileNameBackupDb=${OPTARG};;
 esac
done

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

if [ -z "${fileNameBackupDb}" ]
  then
    echo "No database file supplied"
exit 1
fi

# dbdumpdir = the temp folder for db dumps. *** This must match the path used in ncbackup.sh ***
dbUser="nextcloud"
dbPassword="nextcloud"
nextcloudDatabase="nextcloud"


# show variables
echo "borg archive is	 " $borg_archive
echo "db file is	 " $fileNameBackupDb

info "Preparing..."
enable_maintenance_mode
stop_web_server
echo


#
# Restore the files from borg archive
# 
info "Doing..."
echo "Extracting archive"
rm -r "${extractTempDir}"
mkdir -p "${extractTempDir}"
cd ${extractTempDir} && borg extract -v --list ::"${borg_archive}"

echo "Replacing current nextcloud with one from backup"
rm -R "${nextcloudDataDir}"
mkdir -p "${nextcloudDataDir}"
cp -R ${extractTempDir}/${nextcloudDataDir}/ ${nextcloudDataDir}/
cp -R ${extractTempDir}/${nextcloudFileDir}/ ${nextcloudFileDir}/
echo

#
# Restore database
#
#echo
#echo "Dropping old Nextcloud DB..."
#mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "DROP DATABASE ${nextcloudDatabase}"
#echo "Done"
#echo
#
#echo "Creating new DB for Nextcloud..."
#mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase}"
#echo "Done"
#echo
#
#echo "Restoring backup DB..."
#mysql -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" < "${tempdir}/${fileNameBackupDb}"
#echo "Done"
#echo

#
# Start web server
#
start_web_server

#
# Set directory permissions
#
echo "Setting directory permissions..."
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudFileDir}"
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudDataDir}"
echo "Done"
echo

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/12/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "Updating the system data-fingerprint..."
cd "${nextcloudFileDir}"
sudo -u "${webserverUser}" php occ maintenance:data-fingerprint
cd ~
echo "Done"
echo

disable_maintenance_mode

echo
echo "DONE!"
echo "Backup ${restore} successfully restored."
