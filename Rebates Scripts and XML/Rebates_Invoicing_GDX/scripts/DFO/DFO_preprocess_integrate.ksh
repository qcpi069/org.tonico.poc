#!/usr/bin/ksh

######################################################
#	SCRIPT NAME : DFO_preprocess                 #
#	                                             #
#	PURPOSE     :                                #
#	                                             #
#	INSTRUCTIONS: This script takes one          #
#	              command-line argument:         #
#	              is the DFO client name.        #
#	                                             #
#	CALLS       :                                #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
# 6013450       qcpi733       07/13/06   removed checks on the runstatus
#                                        file for easier restartability.
#  1.0        William Price  06/13/2003  Initial Release                    #
#                                                                           #
#############################################################################
 
# 6013450 - Changed this script from running every 15 minutes to be triggered 
#           by a single file, created out of new GDX_DFO_rename_firsthealth_input.ksh.
#           No more use for the runstatus which was put in place because of the 
#           use of cron.

RETCODE=0

  echo "DFO PRE-PROCESS BEGINS - `date +'%b %d, %Y %H:%M:%S'`......."
#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "Usage DFO_preprocess.ksh <CLIENT NAME>"
     exit 1
  fi

  export CLIENT_NAME=`echo $1 | tr '[A-Z]' '[A-Z]'`

  echo "parameter client name : " ${CLIENT_NAME}  >> $LOG_FILE

#================================================
#EXECUTE DFO PROFILE.
#THIS PROFILE DEFINES VARIOUS REQUIRED VARIABLES
#AND EXPORTS THEM FOR CHILD PROCESSES TO USE.
#================================================

base_dir=$(dirname $0)
. $base_dir/DFO_profile_integrate

if [[ $HOME_DIR = "/GDX/prod" ]]; then
        export ALTER_EMAIL_ADDRESS=""
else 
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
fi

# remove the trigger file that kicked off this job.
rm -f $HOME_DIR/input/GDX_start_dfo_processing.txt

#================================================
#CHECKS IF CLIENT DIRECTORY EXISTS.
#IF NOT, CREATES IT.
#================================================

  echo "***********************************************"   >> $LOG_FILE
  echo "Looking for : $CLIENT_NAME input file"    \
       "\nON `date +'%A %B %d %Y AT %T HRS.'`"             >> $LOG_FILE
  echo "***********************************************\n" >> $LOG_FILE

  if [[ ! -d $CLIENT_DIR ]]; then

     echo "Client directory has not been created for $CLIENT_NAME." \
          "Creating directories for it." >> $LOG_FILE

     mkdir -p $CLIENT_DIR

     echo "Client set up was not completed correctly for $CLIENT_NAME." >> $LOG_FILE
     
     exit 1

   else
     
               echo "looking for ftp of file" >> $LOG_FILE 

#=================================================================
#GETS FILE NAME FROM FTP STAGING DIRECTORY AND CREATE DFO INPUT
#FILE.  NAMING FORMAT IS (in lower case):
#      <client name>.<monyyyy>.<mmddyyyy>.dat.<yyyymmddhhmmss>
#=================================================================

               $SCRIPT_DIR/DFO_get_datafile.ksh >>$LOG_FILE 2>&1
              
               GET_DATAFILE_STATUS=$?
               RETCODE=$GET_DATAFILE_STATUS

#              see if we successfully got a file and put it into  
#              /staging area for further processing.

               if [[ $GET_DATAFILE_STATUS = 0 ]]; then
                                 
#                 notify the DFO support pager that processing has started

                  echo "email notifying DFO support that processing has started" >> $LOG_FILE

                  print "Processing for $CLIENT_NAME has started.  There are "  \
                  `wc -l < $STAGING_DIR/*$CLIENT_NAME*`                         \
         	  "\nrecords in the File" > $MAILFILE

     		  MAIL_SUBJECT="DFO PROCESS started"
     		  $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

#                 update the status for the client for this current process run
     		  
#     		  store the directory for this run for clean up before the next run
#                 moved to end of successful run of claims intake processing
#                 print "${TEMP_DIR}"> $CLIENT_DIR/last_temp_dir

#                 check to see if there's client specific pre processing

                  $SCRIPT_DIR/DFO_clt_preprocessing.ksh $CLIENT_NAME >>$LOG_FILE 2>&1
                  RETCODE=$?
                                    
#                 Continue with main DFO_process
##                  $SCRIPT_DIR/DFO_process_new_automate.ksh $CLIENT_NAME >>$LOG_FILE 2>&1

## for integration!
                  $SCRIPT_DIR/DFO_process_new_integrate.ksh $CLIENT_NAME >>$LOG_FILE 2>&1
                  RETCODE=$?

	       elif  [[$GET_DATAFILE_STATUS != 1 ]]; then		  

	          echo "ERRORS in DFO_get_datafile..." >>$LOG_FILE

                  print "Script: $SCRIPT_NAME"                             \
          	  "\nProcessing for $CLIENT_NAME had a problem:"           \
          	  "\nFile could not be moved for compression processing"   \
          	  "\nLook for Log file $LOG_FILE" > $MAILFILE

     		  MAIL_SUBJECT="DFO PROCESS error"
     		      $SCRIPT_DIR/mailto_IS_group.ksh
     		      
	       else 
		  echo "No data file was found... exit, retry when rescheduled " >>$LOG_FILE 

               fi   ;
                
  fi

  echo "DFO PRE-PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."

exit $RETCODE
