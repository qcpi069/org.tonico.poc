#!/usr/bin/ksh

#================================================================
# ACCEPTS ONE REQUIRED and TWO OPTIONAL COMMAND LINE PARAMETERS:
#
# file name to be FTP'd
#
# 1st optional parm is temp directory where file resides (for 
# keeping track of ftp status).i
#
# 2nd optional parm is CLIENT_NAME, which is the target directory 
# for the ftp'ed file on the ecommerce server under isdatasales
#================================================================

  if [[ $# < 1 ]] then
     echo "Usage DFO_ftp_to_prodftp.ksh <FILE NAME>"
     exit 1
  fi

THIS_DIR="$PWD"

# if there's three parms, use 2 as temp dir, and 3 as client_name
  if [[ $# = 3 ]] then
     TEMP_DATA_DIR=$2

     export CLIENT_NAME=$3
     cd $TEMP_DATA_DIR
  fi

# if there's two parms, use 2 as the temp_dir
  if [[ $# = 2 ]] then
     TEMP_DATA_DIR=$2
     cd $TEMP_DATA_DIR
  fi

  echo "File is getting transferred to PRODFTP (ecommerce server)...." >>$LOG_FILE

######export REF_DIR="/vradfo/prod/control/reffile"
export FTP_PASSWORD_FILE="$REF_DIR/prodftp_password.ref"

export FTP_FILE=$1
echo "file being ftpd " $FTP_FILE >>$LOG_FILE
export FTP_FILE_RENAME=${FTP_FILE}.tmp
cp -p $FTP_FILE $FTP_FILE_RENAME
echo "temp file: " $FTP_FILE_RENAME >>$LOG_FILE
SCRIPT_NAME=$0

FTP_LOG=$TEMP_DATA_DIR/ftp.log 
FTP_ERROR_LOG=$TEMP_DATA_DIR/ftp_error.log

export FTP_USER="isdatasales"
export FTP_PASSWORD=`cat $FTP_PASSWORD_FILE`

ftp -n prodftp <<-DELIM >$FTP_LOG 2>$FTP_ERROR_LOG
   user $FTP_USER $FTP_PASSWORD
   pwd
   cd $CLIENT_NAME 
   pwd
   ascii
   put $FTP_FILE_RENAME
   rename $FTP_FILE_RENAME $FTP_FILE
   quit
DELIM

cat $FTP_LOG >>$LOG_FILE
cat $FTP_ERROR_LOG >> $LOG_FILE

rm $FTP_FILE_RENAME

if [[ -s $FTP_ERROR_LOG ]]; then

#  if the error log file exists, check it's contents
#  you'll get a warning msg when ftp'ing a zero length file
#  if that's our only error, then we're still ok, else, problems!
  
   grep "netout: write returned 0?" $FTP_ERROR_LOG > /dev/null
   SEARCH_RESULT=$?  # grep returns 0 if found, 1 if not found
   
   if (( $SEARCH_RESULT>0 )) then
#     we didn't find the warning msg, other issues

      echo "problems with FTP of to prodftp (no warn)" >> $LOG_FILE
      cat $FTP_ERROR_LOG
  
      print "Script: $SCRIPT_NAME"                          \
           "\nProcessing for $CLIENT_NAME Failed:"          \
           "\nftp of file $FTP_FILE to prodftp had errors"  \
           "\n(no warning message) "                        \
           "\nLook for Log file $LOG_FILE" > $MAILFILE

      MAIL_SUBJECT="DFO ftp to prodftp PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh
      cd $THIS_DIR   
      return 22 
   
   else
      FILE_LINES=$(wc -l < $FTP_ERROR_LOG)

      if (( $FILE_LINES==1 )); then 
#        should be just the one warning message here, which is expected & ok

         echo "File was succussfully transferred to prodftp, YEAH!.." >> $LOG_FILE
	 cat $FTP_ERROR_LOG
         cd $THIS_DIR   
         return 0 
      else 	 
#        There's more than just 1 line in the error_log... we expect just 1 warn msg

         echo "problems with FTP of file to prodftp" >> $LOG_FILE
         cat $FTP_ERROR_LOG
   
         print "Script: $SCRIPT_NAME"                          \
              "\nProcessing for $CLIENT_NAME Failed:"          \
              "\nftp of file $FTP_FILE to prodftp had errors"  \
              "\nLook for Log file $LOG_FILE" > $MAILFILE
 
         MAIL_SUBJECT="DFO ftp to prodftp PROCESS"
         $SCRIPT_DIR/mailto_IS_group.ksh
         cd $THIS_DIR   
         return 24 

       fi
    fi
else
   echo "File $FTP_FILE was succussfully transferred to prodftp...."
   cd $THIS_DIR   
   return 0 
fi



