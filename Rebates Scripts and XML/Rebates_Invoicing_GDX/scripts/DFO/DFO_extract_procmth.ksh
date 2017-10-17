#!/usr/bin/ksh

echo "Process begins - `date +'%b %d, %Y %H:%M:%S'`......."
echo "Extracting process month and year from file name.."

>$MAILFILE

#===================================================================

  $SCRIPT_DIR/DFO_get_process_month.pl       \
                $OLD_DATAFILE              \
                $PROCESS_MONTH_PARM_FILE   \
          >>$LOG_FILE 2>&1
  
#===================================================================

  if [[ $? != 0 ]] then

     echo "Error occurred in 'DFO_get_process_month.pl' script.."
     echo "Error: in 'DFO_get_process_month.pl' script" >> $MAILFILE
  
     MAIL_SUBJECT="Script execution error "
     $SCRIPT_DIR/mailto_IS_group.ksh
     
     exit 200

  fi
  
  echo "Process month and year were extracted.."
  echo "Process Successful."
  echo "Process ended - `date +'%b %d, %Y %H:%M:%S'`......."
