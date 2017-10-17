#!/usr/bin/ksh

echo "VALIDATION-II PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Validating batch control records and fields.."

>$MAILFILE

#===================================================================

  ICLMS="$IN_DATA_FILE"
  IPARM="$PARM_FILE"
  IEREF="$ERROR_DESC_FILE"
  OREJECT="$BAD_FILE"
  OLOG="$DATA_LOG_FILE"

  export ICLMS IPARM IEREF OREJECT OLOG

  $EXE_DIR/vldtctr2 >> $LOG_FILE
##  /vradfo/prod/aix/aixexec/vldtctr2 >> $LOG_FILE

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

  echo "batch control records were validated.."
  echo "Process Successful."
  echo "VALIDATION-II PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
