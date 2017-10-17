#!/usr/bin/ksh

  SCRIPT_NAME=$1
  RETURN_CODE=$2
  ERROR_LOG_FILE1=$3
  ERROR_LOG_FILE="$TEMP_DIR/processed_error_log"
 
#  echo "calling script: " $1 >> $LOG_FILE
#  echo "return code: " $2 >> $LOG_FILE
#  echo "error log file: " $3 >> $LOG_FILE 
  
  if [[ -s $ERROR_LOG_FILE1 ]] then
  
#     echo "log file exists and not empty"
     sort $ERROR_LOG_FILE1 | uniq > $ERROR_LOG_FILE
  
     cat $ERROR_LOG_FILE
  
     echo "Script: $SCRIPT_NAME"                                 \
          "\nProcessing for $CLIENT_NAME Failed: `cat $ERROR_LOG_FILE`" \
          "\nLook for Log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="DFO PROCESS"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
  
     if [[ -n "`grep '2%' $ERROR_LOG_FILE`" ]] then
  
        export MAIL_BODY_FILE="$TWO_PERCENT_MAIL_BODY"
        echo "WJP mail body file: " $MAIL_BODY_FILE

        $SCRIPT_DIR/mailto_contract_admin_group.ksh

        exit 133

     else
  
        if [[ -z "`grep -i 'paragraph' $ERROR_LOG_FILE`" ]] then

           export MAIL_BODY_FILE="$INVALID_FILE_MAIL_BODY"
           echo "WJP invld mail body file " $MAIL_BODY_FILE

           $SCRIPT_DIR/mailto_contract_admin_group.ksh

           exit 134

        fi
  
     fi
  
  
     exit 200
  
  else 
  
#     echo "passed retrn code " $2
#     echo "retrn code " $RETURN_CODE
  
     if [[ $RETURN_CODE != 0 ]] then
  
         export MAIL_SUBJECT="DFO SCRIPT EXECUTION ERROR"
         echo "DFO script $SCRIPT_NAME"   \
              "execution error occurred" > $MAILFILE
  
         $SCRIPT_DIR/mailto_IS_group.ksh

         exit 300
  
     fi
  
  fi
  
  exit 0
  
  
