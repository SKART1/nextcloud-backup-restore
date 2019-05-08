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

select_file_decrease_space() {
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

file_size_in_bytes() {
  echo $(stat --printf="%s" $1)
}

#----------program------------------
stage "Checking conditions..."
#check_root
echo

stage "Preparing..."
echo

stage "Executing..."
build_free_space_array

for file in "$BORG_REPO"/data/0/*; do
  if [ -L "$file" ]; then
    continue;
  else
    fileName=$(basename ${file})
    file_size=$(file_size_in_bytes ${file})
    target_dir=$(select_file_decrease_space ${file_size})
    if [[ $target_dir -eq -1 ]]; then
      error_echo "No directory found for ${file} with size $(${file_size}/1024) kB"
  	  exit 1
    fi
    mkdir -p ${target_dir}/data/0 && mv ${file} ${target_dir}/data/0/
    ln -s ${target_dir}/data/0/${fileName} ${file}
    echo "$file done";
  fi
done

stage "DONE!"
