#!/usr/bin/ksh
#############################################################################
#	SCRIPT NAME : DFO_ftp_to_dalcdcp                                    #
#	                                                                    #
#	PURPOSE     : This korn shell will send a flag to Analytics so they #
#                     can begin an extract process for the newly added DFO  #
#                     clients claims.                                       #
#	                                                                    #
#	INSTRUCTIONS: This script takes one command-line argument:          #
#	              the DFO client name.                                  #
#	                                                                    #
#	CALLS       :                                                       #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  05/28/2004  Initial Release                    #
#                                                                           #
#############################################################################

  echo "DFO ftp to DALCDCP started on `date +'%b %d, %Y %H:%M:%S'`....." >> $LOG_FILE
#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

if [[ $# != 1 ]] then
   echo "Usage DFO_ftp_to_dalcdcp.ksh <CLIENT NAME>"
   exit 1
fi

###used for testing
###TEMP_DIR="/vradfo/prod/temp/T20041203105002_P43774/dat"
###REF_DIR="/vradfo/prod/control/reffile"

export FTP_CLIENT_NAME=`echo $1 | tr '[A-Z]' '[A-Z]'`

echo "File is getting transferred to dalcdcp (Zeus)...."

ANALYTICS_FTP_TARGET="/datar1/data_sas"
DALCDCP_PASSWORD_FILE="$REF_DIR/dalcdcp_password.ref"

THIS_DIR="$PWD"
cd $TEMP_DIR
touch $TEMP_DIR/DFO_trigger_$FTP_CLIENT_NAME
echo "ftp file " $TEMP_DIR/DFO_trigger_$FTP_CLIENT_NAME
print "$FTP_CLIENT_NAME">$TEMP_DIR/DFO_trigger_$FTP_CLIENT_NAME
SCRIPT_NAME=$0

FTP_LOG=$TEMP_DIR/ftp_dalcdcp.log 
FTP_ERROR_LOG=$TEMP_DIR/ftp_dalcdcp_error.log

DALCDCP_USER="dwpcda"
DALCDCP_PASSWORD=`cat $DALCDCP_PASSWORD_FILE`

ftp -n dalcdcpg <<-DELIM >$FTP_LOG 2>$FTP_ERROR_LOG
   user $DALCDCP_USER $DALCDCP_PASSWORD
   cd $ANALYTICS_FTP_TARGET
   ascii
   put $TEMP_DIR/DFO_trigger_$FTP_CLIENT_NAME $ANALYTICS_FTP_TARGET/DFO_trigger_$FTP_CLIENT_NAME
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

      echo "problems with FTP of analytics trigger file" >> $LOG_FILE
      cat $FTP_ERROR_LOG
  
      print "Script: $SCRIPT_NAME"                          \
           "\nProcessing for $CLIENT_NAME Failed:"                \
           "\nftp of analystics trigger file to dalcdcp had errors"       \
           "\n(no warning message) "                        \
           "\nLook for Log file $LOG_FILE" > $MAILFILE

      MAIL_SUBJECT="DFO ftp PROCESS"
      $SCRIPT_DIR/mailto_IS_group.ksh

      exit 22
   
   else
      FILE_LINES=$(wc -l < $FTP_ERROR_LOG)

      if (( $FILE_LINES==1 )); then 
#        should be just the one warning message here, which is expected & ok

         echo "Trigger File was succussfully transferred to dalcdcp, YEAH!.." >> $LOG_FILE
	 cat $FTP_ERROR_LOG
         return 222
      else 	 
#        There's more than just 1 line in the error_log... we expect just 1 warn msg

         echo "problems with FTP of trigger file" >> $LOG_FILE
         cat $FTP_ERROR_LOG
   
         print "Script: $SCRIPT_NAME"                          \
              "\nProcessing for $CLIENT_NAME Failed:"          \
              "\nftp of analystics trigger file to dalcdcp had errors"       \
              "\nLook for Log file $LOG_FILE" > $MAILFILE
 
         MAIL_SUBJECT="DFO ftp (dalcdcp) PROCESS"
         $SCRIPT_DIR/mailto_IS_group.ksh

         exit 22

       fi
    fi
else
   echo "File was succussfully transferred to dalcdcp...."
   return 222
fi

cd $THIS_DIR   