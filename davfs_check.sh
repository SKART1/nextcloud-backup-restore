#!/bin/bash

. ./helpers.sh

target_directories=('/backup/WebDav/Acc1' '/backup/WebDav/Acc2' '/backup/WebDav/Acc3' '/backup/WebDav/Acc4' '/backup/WebDav/Acc5' '/backup/WebDav/Acc6' '/backup/WebDav/Acc7' '/backup/WebDav/Acc8' '/backup/WebDav/Acc9');
file='health.txt'

for idx in "${!target_directories[@]}"; do
  check_dir ${target_directories[idx]}/${file}

  RESULT=$?
  if [ ${RESULT} -ne 0 ]; then
     info "Mount point ${target_directories[idx]} is broken. Remounting"
     sudo umount ${target_directories[idx]}
     sudo mount ${target_directories[idx]}
     info "Done\n"
  fi
done


