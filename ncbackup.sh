#!/bin/bash

# Setting this, so the repo does not need to be given on the commandline:
export BORG_REPO=/home/art/backup1
#export BORG_REPO=/path-to-your-repo

# Setting this, so you won't be asked for your repository passphrase:
export BORG_PASSPHRASE='123'
# or this to ask an external program to supply the passphrase:
#export BORG_PASSCOMMAND='pass show backup'

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

# Function for error messages
#errorecho() { cat <<< "$@" 1>&2; }
errorecho() { echo "$@"; }


#Bail if borg is already running, maybe previous run didn't finish
if pidof -x borg >/dev/null; then
    echo "Backup already running"
    mail -s "Nextcloud Backup. Borg already running." youremail@yourdomain < /home/pi/scripts/backup.txt
    exit
fi

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

#
# nextcloud vars
#
# nextcloudFileDir = the folder of your nextcloud installation
nextcloudFileDir="/var/www/nextcloud"
nextcloudDataDir="/var/nc-data"
# dbdumpdir = the temp folder for db dumps
dbdumpdir="/home/art/dbdump"
# dbdumpfilename = the name of the db dump file
dbdumpfilename=$(hostname)-nextcloud-db.sql-$(date +"%Y-%m-%d_%H:%M:%S")

#
# database vars, substitute your own values here
#
#dbUser="nextcloud"
#dbPassword="nextcloud"
#nextcloudDatabase="nextcloud"

# exclude files and folders. You can tweak these and/or add more. These are just the vars. They vars are then appended to borg create
exclude_updater="'$nextcloudDataDir/updater-*'"
exclude_updater_hidden="'$nextcloudDataDir/updater-*/.*'"
exclude_versions_dir="'/var/nc-data/*/files_versions/*'"

#
# webserver vars
#
webserverUser="www-data"
webserverServiceName="nginx"

info "Starting backup..."

echo "Showing the excluded files and folders..."
echo $exclude_updater
echo $exclude_updater_hidden
echo $exclude_versions_dir

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
cd "${nextcloudFileDir}"
sudo -u "${webserverUser}" php occ maintenance:mode --on
cd ~
echo "Done"
echo

#
# Stop web server
#
echo "Stopping web server..."
service "${webserverServiceName}" stop
echo "Done"
echo


#
# Backup DB. The db is dumped to a temp file folder. It will be picked up by the archive. Then removed later.
#
echo "Backup Nextcloud database..."
#mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${dbdumpdir}/${dbdumpfilename}"
docker exec -t -u postgres postgres pg_dumpall -c > "${dbdumpdir}/${dbdumpfilename}"
echo "postgress dump successful. Dump folder ${dbdumpdir}"
echo "Listing dump file..."
ls -l ${dbdumpdir}
echo
echo "Database backup size: $(stat --printf='%s' ${dbdumpdir}/${dbdumpfilename} | numfmt --to=iec)"
echo
echo "Done"
echo

# Backup the nextlcoud directories and dbdump into an archive named after
# the machine this script is currently running on:
echo "Backup nextcloud files..."

abc="'""/var/nc-data/*/files_versions/*""'"
bcd="'/var/nc-data/art/files_versions/*'"
def="\'/var/nc-data/*/files_versions/*\'"
fgh="'/var/nc-data/*/files_versions/*'"

hhh="'"/var/nc-data/*/files_versions/*"'";
hhhh='/var/nc-data/*/files_versions/*';
zzzz="$nextcloudDataDir*/files_versions/*"
echo "$hhh"
echo "$hhhh"
echo "$zzzz"

borg create                         \
    --verbose                       \
    --filter AME                    \
    --list                          \
    --stats                         \
    --show-rc                       \
    --compression lz4               \
    ::'{hostname}-{now}'            \
    $nextcloudFileDir/config        \
    $nextcloudFileDir/themes        \
    $nextcloudDataDir               \
    $dbdumpdir                      \
    --exclude-caches                \
    --exclude '*.log'               \
    --exclude '*.log.*'             \
    --exclude $exclude_updater      \
    --exclude $exclude_updater_hidden \
    --exclude "$zzzz" \
   #--exclude /var/nc-data/*/files_versions/*'

backup_exit=$?

#
# The db dump file is removed in this step as it is no longer needed. It has been included
# in the archive. It is removed to clean up the folder for future backups.
#
info "Remove the db backup file"
rm  ${dbdumpdir}/*
echo "Done"

info "Pruning repository"
echo "Pruning repository. Daily 5, Weekly 2, Monthly 1". Note, you can change these values to your liking
borg prune                          \
    --list                          \
    -v                              \
    --prefix '{hostname}-'          \
    --show-rc                       \
    --keep-daily=5                  \
    --keep-weekly=2                 \
    --keep-monthly=1                \

prune_exit=$?

#
# Start web server
#
echo
echo "Starting web server..."
service "${webserverServiceName}" start
echo "Done"
echo


#
# Disable maintenance mode
#
echo "Switching off maintenance mode..."
cd "${nextcloudFileDir}"
sudo -u "${webserverUser}" php occ maintenance:mode --off
cd ~
echo "Done"
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

echo "DONE!"
