#!/usr/bin/ksh

echo "ELIMINATION PROCESS 1 BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Eliminating duplicate claims/voids records.."   >> $LOG_FILE

>$MAILFILE

#===================================================================

echo "process month parm file: " $PROCESS_MONTH_PARM_FILE   >> $LOG_FILE

  ICLMS="$IN_DATA_FILE"
  IREJC="$IN_REJ_COUNT_REF"
  IPRCMTH="$PROCESS_MONTH_PARM_FILE"
  IEREF="$ERROR_DESC_FILE"
  ICCON="$CONTRACT_FILE"
  OCLMS="$OUT_DATA_FILE"
  OREJ="$BAD_FILE"
  OLOG="$DATA_LOG_FILE"
  OREJC="$OUT_REJ_COUNT_REF"

  export ICLMS IREJC IPRCMTH IEREF ICCON OCLMS OREJ OLOG OREJC

  $EXE_DIR/elimdup2 >> $LOG_FILE
##  /vradfo/prod/aix/aixexec/elimdup2 >> $LOG_FILE
  
#===================================================================

  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`
 
  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $OLOG

#===================================================================

  RETURN_CODE=$?

  if [[ $RETURN_CODE != 0 ]] then

     if [[ $RETURN_CODE = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1

  fi

  echo "\nNo. of records processed: `wc -l $ICLMS | cut -f1 -d '/'`"   \
       "\nNo. of records accepted : `wc -l $OCLMS | cut -f1 -d '/'`"   \
       "\nNo. of records rejected : `wc -l $OREJ | cut -f1 -d '/'`"    \
  
  echo "Process Successful."
  echo "ELIMINATION PROCESS 1 ENDED - `date +'%b %d, %Y %H:%M:%S'`......."

  exit 0
