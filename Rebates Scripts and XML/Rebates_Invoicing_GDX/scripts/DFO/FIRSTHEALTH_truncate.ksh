#!/usr/bin/ksh

echo "PRE-PROCESSING FOR FRSTHLTH BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Truncate input file from 370 to 369 bytes..."

>$MAILFILE
  
#===================================================================

  dd_IVRA1="$IN_DATA_FILE"
  dd_OVRA1="$OUT_DATA_FILE"
  dd_OLOG="$DATA_LOG_FILE"
  echo "I  input data file " $IN_DATA_FILE >>$LOG_FILE
  echo "O  output data file " $OUT_DATA_FILE >>$LOG_FILE
 
  export dd_IVRA1 dd_OVRA1
  
  cobrun '$EXE_DIR/truncate.int' 
  
#===================================================================

  RETURN_CODE=$?
#  echo "return code: " $RETURN_CODE
  SCRIPT_NAME=`basename $0`
 
  $SCRIPT_DIR/DFO_check_error.ksh $SCRIPT_NAME $RETURN_CODE $dd_OLOG

#===================================================================

  RETURN_CODE=$?

  if [[ $RETURN_CODE != 0 ]]; then

     if [[ $RETURN_CODE = 13 ]] then

        $SCRIPT_DIR/clean_up.ksh "N"

     fi

     exit 1
  else
#    Return code = 0, report audit totals, clean up old ".input" file

     echo "\nNo. of records input: `wc -l $dd_IVRA1 | cut -f1 -d '/'`"   \
          "\nNo. of records output : `wc -l $dd_OVRA1 | cut -f1 -d '/'`"   

     rm $IN_DATA_FILE

     if [[ $RETURN_CODE != 0 ]]; then

         echo "unable to delete renamed input file: $IN_DATA_FILE "
	 echo "Script: $SCRIPT_NAME"                                         \
              "Warning issued during $CLIENT_NAME processing: "              \
              "\nFile could not be deleted from /staging directory.  File: " \
              "\n "  $IN_DATA_FILE                                           \
              "\nLook for Log file $LOG_FILE" > $MAILFILE

	 MAIL_SUBJECT="DFO PROCESS warning"
      	 $SCRIPT_DIR/mailto_IS_group.ksh
     fi

  fi
  
  echo "\nFile was truncated.."
  echo "Process Successful."
  echo "PRE-PROCESSING FOR FRSTHLTH ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
