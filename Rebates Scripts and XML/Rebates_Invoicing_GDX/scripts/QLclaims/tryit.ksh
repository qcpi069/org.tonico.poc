#!/usr/bin/ksh

  export HOME_DIR="/vracobol/prod"
  export REF_DIR="$HOME_DIR/control/reffile"
  export TEMP_DIR="/vracobol/prod/temp/testingSQL"
  export LOG_FILE="$TEMP_DIR/log_file.log"
#  export MAILFILE="$TEMP_DIR/mailfile"
#  export DBA_DATA_LOAD_DIR="/datar1"
#  export DATA_LOAD_DIR="/vradfo/prodload"
#  export DATA_LOAD_FILE="mda.vrap.tclaims.dat.T20040601000003"
#  export SCRIPT_DIR="$HOME_DIR/script"
#
#  above lines are hardcoded values for testing.
#
#################################################################################

  THIS_DIR="$PWD"
  cd $TEMP_DIR
 
  CHESTER_PASSWORD_FILE="$REF_DIR/chester_password.ref"
  typeset -i LOOP_CTR=1
  DB_2_LOG="$TEMP_DIR/db_2.log"
  DB_2_RTN_CODE="$TEMP_DIR/db_2_return_cd"
  MAX_LOAD_DATE="$TEMP_DIR/max_load_date"
  TEMP_LOAD_DT="$TEMP_DIR/temp_load_date"
  TEMP_RTN_CODE="$TEMP_DIR/return_cd_value"
  CHESTER_USER="vraadmin"
  CHESTER_PASSWORD=$(< $CHESTER_PASSWORD_FILE)
    
#  sleep 60
#  db2 "connect to udbmdap user " $CHESTER_USER " using " $CHESTER_PASSWORD" >/dev/null 2>/dev/null
  db2 "connect to udbmdap user " $CHESTER_USER " using " $CHESTER_PASSWORD >>$LOG_FILE 2>>$LOG_FILE

  SQL_TEXT="select rx_nb from vrap.tclaims"
  echo "SQL TEXT " $SQL_TEXT
  db2 "$SQL_TEXT"> $DB_2_LOG 2>>$LOG_FILE
  print $(< $DB_2_LOG)>>$LOG_FILE
  
  FILE_LINES=$(wc -l < $DB_2_LOG)     

  if (( $FILE_LINES!=7 )); then 

     db2 connect reset>/dev/null 2>/dev/null

     echo "Load Processing for $RUN_MODE tclaims_sum rebuild had problems:" 

     let Load_Return_Code=152

     echo "at end Load_Return_Code: " $Load_Return_Code
     echo "\n***********************************************" 
     echo "TCLAIMS_SUM rebuild for $RUN_MODE CLAIMS load ended with unknown status."           \
          "\nON `date +'%A %B %d %Y AT %T HRS.'`"             
     echo "***********************************************\n" 

     return $Load_Return_Code
  fi  


  db2 connect reset>/dev/null 2>/dev/null

  echo "at end Load_Return_Code: " $Load_Return_Code
  echo "\n***********************************************"   >> $LOG_FILE
  echo "DBA REBUILD OF TCLAIMS_SUM for $RUN_MODE CLAIMS load ended."           \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE
  
  return $Load_Return_Code
