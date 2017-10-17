#!/usr/bin/ksh

echo "CONVERTION PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Converting required sign fields from ebcdic to ascii.."

  export SCRIPT_DIR="/vradfo/prod/script"
  export SCRIPT_NAME="DFO_convert.standalone.ksh"
  export IN_DATA_FILE="/vradfo/prod/temp/T20041004170502_P54706/dat/PHARMASSESS.SEP2004"
  export CONV_REF="/vradfo/prod/control/reffile/DFO_convert_PHARMASSESS.ref"
  export ERROR_DESC_FILE="$/vradfo/prod/control/reffile/DFO_error_desc_index.ref"
  export IN_REJ_COUNT_REF="/vradfo/prod/temp/T20041004170502_P54706/dat/DFO_reject_count.ref"
  export CONV_CONV="/vradfo/prod/temp/T20041004170502_P54706/dat/PHARMASSESS.SEP2004.convert.convert"
  export OUT_DATA_FILE="/vradfo/prod/temp/T20041004170502_P54706/dat/PHARMASSESS.SEP2004.convert.good"
  export BAD_FILE="/vradfo/prod/temp/T20041004170502_P54706/dat/PHARMASSESS.SEP2004.convert.reject"
  export DATA_LOG_FILE="/vradfo/prod/temp/T20041004170502_P54706/dat/PHARMASSESS.SEP2004.convert.log"
  export OUT_REJ_COUNT_REF="/vradfo/prod/temp/T20041004170502_P54706/dat/DFO_reject_count.convert.ref"

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
  echo "return from Perl script: " $RETURN_CODE
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
