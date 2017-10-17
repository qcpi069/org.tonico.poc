#!/usr/bin/ksh

echo "File is getting transferred to martprod1...."

CHESTER_PASSWORD_FILE="$REF_DIR/chester_password.ref"

THIS_DIR="$PWD"
cd $TEMP_DIR
echo "data load file " $DATA_LOAD_FILE
echo $DATA_LOAD_DIR/$DATA_LOAD_FILE
SCRIPT_NAME=$0

FTP_LOG=$TEMP_DIR/ftp.log 
FTP_ERROR_LOG=$TEMP_DIR/ftp_error.log

CHESTER_USER="vraadmin"
CHESTER_PASSWORD=`cat $CHESTER_PASSWORD_FILE`

ftp -n martprod1 <<-DELIM >$FTP_LOG 2>$FTP_ERROR_LOG
   user $CHESTER_USER $CHESTER_PASSWORD
   ascii
   put $DATA_LOAD_DIR/$DATA_LOAD_FILE /$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE
   put $DATA_LOAD_DIR/$DATA_LOAD_FILE.ok /$DBA_DATA_LOAD_DIR/$DATA_LOAD_FILE.ok
   quit
DELIM

if [[ -s $FTP_ERROR_LOG ]]; then

#  if the error log file exists, check it's contents
#  you'll get a warning msg when ftp'ing a zero length file
#  if that's our only error, then we're still ok, else, problems!
  
   grep "netout: write returned 0?" $FTP_ERROR_LOG > /dev/null
   SEARCH_RESULT=$?  # grep returns 0 if found, 1 if not found
   
   if (( $SEARCH_RESULT>0 )) then
#     we didn't find the warning msg, other issues

      echo "problems with FTP of load record (no warn)" >> $LOG_FILE
      cat $FTP_ERROR_LOG
  
      print "Script: $SCRIPT_NAME"                             \
           "\nProcessing for $RUN_MODE claims intake Failed:"  \
           "\nftp of load file to martprod1 had errors"        \
           "\n(no warning message) "                           \
           "\nLook for Log file $LOG_FILE" > $MAILFILE

      MAIL_SUBJECT="MDA ftp to martprod1 PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh

      exit 22
   
   else
      FILE_LINES=$(wc -l < $FTP_ERROR_LOG)

      if (( $FILE_LINES==1 )); then 
#        should be just the one warning message here, which is expected & ok

         echo "File was successfully transferred to martprod1, YEAH!.." >> $LOG_FILE
	 cat $FTP_ERROR_LOG
         return 222
      else 	 
#        There's more than just 1 line in the error_log... we expect just 1 warn msg

         echo "problems with FTP of load record" >> $LOG_FILE
         cat $FTP_ERROR_LOG
   
         print "Script: $SCRIPT_NAME"                             \
              "\nProcessing for $RUN_MODE claims intake Failed:"  \
              "\nftp of load file to martprod1 had errors"        \
              "\nLook for Log file $LOG_FILE" > $MAILFILE
 
         MAIL_SUBJECT="MDA ftp to martprod1 PROCESS"
         $SCRIPT_DIR/mailto_IS_group.ksh

         exit 22

       fi
    fi
else
   echo "File was succussfully transferred to martprod1...."
   return 222
fi

cd $THIS_DIR   
