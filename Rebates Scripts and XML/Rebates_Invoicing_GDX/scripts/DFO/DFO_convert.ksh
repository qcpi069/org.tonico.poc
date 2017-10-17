#!/usr/bin/ksh

echo "CONVERTION PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Converting required sign fields from ebcdic to ascii.."

>$MAILFILE

#===================================================================

  $SCRIPT_DIR/DFO_convert.pl             \
             $IN_DATA_FILE               \
             $CONV_REF                   \
             $ERROR_DESC_FILE            \
             $IN_REJ_COUNT_REF           \
             $CONV_CONV                  \
             $OUT_DATA_FILE              \
             $BAD_FILE                   \
             $DATA_LOG_FILE              \
             $OUT_REJ_COUNT_REF

#===================================================================

  RETURN_CODE=$?
  SCRIPT_NAME=`basename $0`
 
  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $DATA_LOG_FILE

#===================================================================

  RETURN_CODE=$?

  if [[ $RETURN_CODE != 0 ]] then

     if [[ $RETURN_CODE = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1

  fi

  echo "\nNo. of records processed: `wc -l $IN_DATA_FILE | cut -f1 -d '/'`"
  echo "No. of records converted: `wc -l $CONV_CONV | cut -f1 -d '/'`"
  echo "No. of records valid    : `wc -l $OUT_DATA_FILE | cut -f1 -d '/'`"
  echo "No. of records rejected : `wc -l $BAD_FILE  | cut -f1 -d '/'`"

  echo "\nRequired sign fields were converted from ebcdic to ascii.."
  echo "Process Successful."
  echo "CONVERTION PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
