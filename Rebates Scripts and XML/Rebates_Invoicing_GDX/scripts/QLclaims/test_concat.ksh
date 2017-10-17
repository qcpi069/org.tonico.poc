#!/usr/bin/ksh
  LOG_DIR="/vracobol/prod/log"
  cat $LOG_DIR/sarbanes_copy $LOG_DIR/SBO_audit > $LOG_DIR/sarbanes_copy_ksh
  cp -p $LOG_DIR/sarbanes_copy_ksh $LOG_DIR/sarbanes_copy
