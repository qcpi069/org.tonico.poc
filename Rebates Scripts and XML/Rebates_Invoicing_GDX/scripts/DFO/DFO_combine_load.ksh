#!/usr/bin/ksh

echo "Combining split load files......"

>$MAILFILE

#===================================================================

  $SCRIPT_DIR/DFO_combine_load.pl        \
             $ERROR_DESC_FILE            \
             $IN_REJ_COUNT_REF           \
             $IN_REJECT_FILE             \
             $BAD_FILE                   \
             $IN_WARN_FILE               \
             $WARN_FILE                  \
             $DATA_LOG_FILE              \
             $OUT_REJ_COUNT_REF

#===================================================================

  SCRIPT_NAME=`basename $0`
  RETURN_CODE=$?
 
  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $DATA_LOG_FILE

#===================================================================
  RETURN_CODE=$?

  if [[ $RETURN_CODE != 0 ]] then

     if [[ $RETURN_CODE = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1

  fi
