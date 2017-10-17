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
#  1.0        William Price  06/13/2003  Initial Release                    #
#                                                                           #
#############################################################################

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
#EXECUTE DFO TEST PROFILE.
#THIS PROFILE DEFINES VARIOUS REQUIRED VARIABLES
#AND EXPORTS THEM FOR CHILD PROCESSES TO USE.
#================================================

  . /vradfo/prod/script/DFO_prod_profile_new >/dev/null 2>&1 

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

# check to see if status of current run exists, and if it does, 
# check to see if the process still needs to be run (blank status)

  elif [[ -s $RUN_STATUS ]] ; then
     
     typeset -x current_run_status
      
     current_run_status=`cat ${RUN_STATUS}`

     case ${current_run_status} in
     
         'blank'         )

#              found a blank status, check for FTP file.  If it exists and
#              and is done being FTP'd, then DFO process can begin.
      
               echo "looking for ftp of file" >> $LOG_FILE 

#=================================================================
#GETS FILE NAME FROM FTP STAGING DIRECTORY AND CREATE DFO INPUT
#FILE.  NAMING FORMAT IS (in lower case):
#      <client name>.<monyyyy>.<mmddyyyy>.dat.<yyyymmddhhmmss>
#=================================================================

               $SCRIPT_DIR/DFO_get_datafile.ksh >>$LOG_FILE 2>&1
              
               GET_DATAFILE_STATUS=$?

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
     		  print "started" > $RUN_STATUS
     		  
#     		  store the directory for this run for clean up before the next run
#                 moved to end of successful run of claims intake processing
#                 print "${TEMP_DIR}"> $CLIENT_DIR/last_temp_dir

#                 check to see if there's client specific pre processing

                  $SCRIPT_DIR/DFO_clt_preprocessing.ksh $CLIENT_NAME >>$LOG_FILE 2>&1
                                    
#                 Continue with main DFO_process
                  $SCRIPT_DIR/DFO_process_new_automate.ksh $CLIENT_NAME >>$LOG_FILE 2>&1
                                                     
	       elif  [[$GET_DATAFILE_STATUS != 1 ]]; then		  
	          echo "ERRORS in DFO_get_datafile..." >>$LOG_FILE

                  print "Script: $SCRIPT_NAME"                             \
          	  "\nProcessing for $CLIENT_NAME had a problem:"           \
          	  "\nFile could not be moved for compression processing"   \
          	  "\nLook for Log file $LOG_FILE" > $MAILFILE

     		  MAIL_SUBJECT="DFO PROCESS error"
     		      $SCRIPT_DIR/mailto_IS_group.ksh
     		      
	       else 
#	   	  $? = 1, return code = 1
		  echo "No data file was found... exit, retry when rescheduled " >>$LOG_FILE 

               fi   ;;
                
         'started'       )          
                echo "hold your horses... we\'ve started to process" >> $LOG_FILE
                rm -rf $TEMP_DIR
                return 0 ;;
                
         'completed'     )

                rm -rf $TEMP_DIR

                echo "done for this month" >> $LOG_FILE
                return 0 ;;
                
         'past deadline' )
                echo "MDA can start.. could not wait for deadbeat client" >> $LOG_FILE
                rm -rf $TEMP_DIR
                return 0 ;;
                          
      esac
      
  else 
     #  either RUN_STATUS file does not exist or is empty
     #  we'll create a blank run_status file
     echo "HELP ME!" >> $LOG_FILE
     print "blank" > $RUN_STATUS
   
  fi

  echo "DFO PRE-PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
