#!/bin/bash

. ./helpers.sh
/home/borg/rclone-folder/rclone sync --copy-links /backup/borg/data/ onedrive1:mother
RESULT1=$?
if [ ${RESULT1} -ne 0 ]; then
  error_echo "Error copying to onedrive1"
fi

/home/borg/rclone-folder/rclone sync --copy-links /backup/borg/data/ onedrive2:father
RESULT2=$?
if [ ${RESULT2} -ne 0 ]; then
  error_echo "Error copying to onedrive2"
fi

/home/borg/rclone-folder/rclone sync --copy-links /backup/borg/data/ onedrive3:sister
RESULT3=$?
if [ ${RESULT3} -ne 0 ]; then
  error_echo "Error copying to onedrive3"
fi

/home/borg/rclone-folder/rclone sync --copy-links /backup/borg/data/ onedrive4:brother
RESULT4=$?
if [ ${RESULT4} -ne 0 ]; then
  error_echo "Error copying to onedrive4"
fi

exit $RESULT1 || $RESULT2 || $RESULT3 || $RESULT4
