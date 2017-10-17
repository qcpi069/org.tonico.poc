#!/usr/bin/ksh

  SCRIPT_NAME=$1
  RETURN_CODE=$2
  ERROR_LOG_FILE1=$3
  ERROR_LOG_FILE="$TEMP_DIR/processed_error_log"
  
  if [[ -s $ERROR_LOG_FILE ]] then
  
     sort $ERROR_LOG_FILE1 | uniq > $ERROR_LOG_FILE
  
     cat $ERROR_LOG_FILE
  
     echo "Script: $SCRIPT_NAME"                                 \
          "\nProcessing for $RUN_MODE claims processing Failed: `cat $ERROR_LOG_FILE`" \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="MDA claims intake PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
    
     exit 200
  
  else 
  
#     echo "passed retrn code " $2
#     echo "retrn code " $RETURN_CODE
  
     if [[ $RETURN_CODE != 0 ]] then
  
         MAIL_SUBJECT="MDA SCRIPT EXECUTION ERROR"
         echo "MDA script $SCRIPT_NAME"              \
              "return code passed: " $RETURN_CODE    \
              "execution error occurred" > $MAILFILE
  
         $SCRIPT_DIR/mailto_IS_group.ksh

         exit 300
  
     fi
  
  fi
  
  exit 0