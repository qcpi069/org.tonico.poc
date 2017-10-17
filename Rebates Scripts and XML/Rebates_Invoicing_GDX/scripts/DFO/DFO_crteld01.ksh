#!/usr/bin/ksh

echo "Creating Load file suffix $1......"
echo "$$" >> $PROCESSOR_NO_FILE

SPLIT_SUFFIX="$1"

>$MAILFILE
  
#===================================================================
## point to database

#############################
# set variables for db login
#############################

. $SCRIPT_DIR/dbenv.ksh

print  "DB name is  " $DBNAME				>> $LOG_FILE
print  "DB User is  " $DBUSER				>> $LOG_FILE
print  "DB PW is  " $DBPSWD				>> $LOG_FILE


  ICLMS="$IN_DATA_FILE.$SPLIT_SUFFIX"
  IREJC="$IN_REJ_COUNT_REF"
  IPRCMTH="$PROCESS_MONTH_PARM_FILE"
  IEREF="$ERROR_DESC_FILE"
  ICCON="$CONTRACT_FILE"
  OCLMS="$OUT_DATA_FILE.$SPLIT_SUFFIX"
  OLOAD="$LOAD_FILE.$SPLIT_SUFFIX"
  OREJ="$BAD_FILE.$SPLIT_SUFFIX"
  OWARN="$WARN_FILE.$SPLIT_SUFFIX"
  OLOG="$DATA_LOG_FILE.$SPLIT_SUFFIX"
  OREJC="$OUT_REJ_COUNT_REF.$SPLIT_SUFFIX"

  export ICLMS IREJC IPRCMTH IEREF ICCON OCLMS OLOAD OREJ OWARN OLOG OREJC
  
  $EXE_DIR/crteld01 >> $LOG_FILE
##  /vradfo/prod/aix/aixexec/crteld01 >> $LOG_FILE

  jobs -p >>  $PROCESSOR_NO_FILE
  
#===================================================================

  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`
 
  touch $TEMP_DATA_DIR/done.$SPLIT_SUFFIX

  if [[ $RETURN_CODE != 0 ]] then

     echo "Error in execution of crteload split $SPLIT_SUFFIX"
             > $TEMP_DATA_DIR/done.$SPLIT_SUFFIX
     exit 1

  fi

  if [[ -s $OLOG ]] then

     exit 1

  fi

  echo "`date +'%b %d, %Y %H:%M:%S'`:Load file suffix $SPLIT_SUFFIX was"  \
       "successfully created......."
  
  exit 0
