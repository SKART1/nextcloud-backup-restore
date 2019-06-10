#!/bin/bash

. ./helpers.sh

target_directories=('/backup/WebDav/Acc1' '/backup/WebDav/Acc2' '/backup/WebDav/Acc3' '/backup/WebDav/Acc4' '/backup/WebDav/Acc5' '/backup/WebDav/Acc6' '/backup/WebDav/Acc7' '/backup/WebDav/Acc8' '/backup/WebDav/Acc9');
file='health.txt'

for idx in "${!target_directories[@]}"; do
  check_dir ${target_directories[idx]}/${file}

  RESULT=$?
  if [ $RESULT -eq 0 ]; then
    echo success
  else
    umount ${target_directories[idx]}
    mount ${target_directories[idx]}
  fi
done


