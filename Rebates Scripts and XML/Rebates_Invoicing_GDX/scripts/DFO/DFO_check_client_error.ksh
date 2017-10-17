#echo "start checking bad client "
  SCRIPT_NAME="$1"
  RETURN_CODE="$2"
  BAD_CLIENT_FILE1="$3"
  BAD_CLIENT_FILE="$TEMP_DIR/bad_client_log"

  if [[ -s $BAD_CLIENT_FILE ]] then
     sort $BAD_CLIENT_FILE1 | uniq > $BAD_CLIENT_FILE
  
     cat $BAD_CLIENT_FILE

     echo "middle of checking bad client "  
     echo "Script: $SCRIPT_NAME"                                 \
          "\nProcessing for $CLIENT_NAME experienced errors: "   \
          "\n`cat $BAD_CLIENT_FILE`"                             \
          "\nLook for bad client data in log file $LOG_FILE" > $MAILFILE
  
     MAIL_SUBJECT="DFO PROCESS-Bad Client Id"
  
     $SCRIPT_DIR/mailto_IS_group.ksh
    
  fi
# echo "end checking bad client "  
  exit 0
  
  
