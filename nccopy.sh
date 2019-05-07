#!/bin/bash

. ./helpers.sh

#Exit on any error
set -e

trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM


#----------globals------------------
export BORG_REPO=/home/art2/backup1
target_directory=/home/art2/WebDav/Acc2
possible_target_directories=('/home/art' '/LinStor');
declare -A spaces_array

#----------functions------------------
build_free_space_array() {
  for idx in "${!possible_target_directories[@]}"; do
    spaces_array[$idx]=$(free_space_in_directory_in_bytes ${possible_target_directories[$idx]})
  done
}

free_space_in_directory_in_bytes() {
  local res=$(df --output=avail -B 1 "$1" | tail -n 1)
  echo $((res*95/100))
}

select_file() {
  res=-1
  for idx in "${!spaces_array[@]}"; do
    if [[ ${spaces_array[$idx]} -ge $1 ]]; then
      spaces_array[$idx]=$((${spaces_array[$idx]}-$1))
      res=${possible_target_directories[$idx]}
      break
    fi
  done
  echo ${res}
}

#----------program------------------
stage "Checking conditions..."
#check_root
echo

stage "Preparing..."
echo

stage "Executing..."
build_free_space_array
printf '%s\n' "${spaces_array[@]}"
select_file 9808668032


#for file in "$BORG_REPO"/data/0/*; do
#  if [ -L "$file" ]; then
#    continue;
#  else
#    fileName=$(basename $file)
#    mkdir -p ${target_directory}/data/0 && mv $file ${target_directory}/data/0/
#    ln -s ${target_directory}/data/0/$fileName $file
#    echo "$file done";
#  fi
#done

#for file in "$BORG_REPO"/* "$BORG_REPO"/.* ; do
#  if [[ -L "$file" ]]; then echo "$file is a symlink"; else echo "$file is not a symlink"; fi
#done
#for i in ${BORG_REPO}/data/0/ ; do
#    mv ./$i ${target_directory}/data/0/
#    ln -s ${target_directory}/$i ./$i
#done
echo

stage "Restoring state..."
echo

stage "Cleaning..."
echo

# use highest exit code as global exit code
# global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))

#if [ ${global_exit} -eq 1 ];
#then
#    stage "Backup and/or Prune finished with a warning"
#fi
#
#if [ ${global_exit} -gt 1 ];
#then
#    stage "Backup and/or Prune finished with an error"
#fi

stage "DONE!"

#
# send email. Uncomment the below line to send an email. This requires you first setup a MTA
# To send mail, setup your cron script
# like this: 55 23 * * * /root/backup.sh > /home/<user>/backup.txt 2>&1
#
# mail -s "Nextcloud Backup" youremail@yourdomain.com < /home/<user>/backup.txt
#exit ${global_exit}
