#!/usr/bin/ksh

######################################################
#	SCRIPT NAME : MDA_preprocess                 #
#	                                             #
#	PURPOSE     :                                #
#	                                             #
#	INSTRUCTIONS: This script takes one          #
#	              command-line argument:         #
#	              RUN MODE.  It's either         #
#	              "W" for weekly mode ~ or ~     #
#	              "M" for Monthly.               #
#	                                             #
#	CALLS       :                                #
#                                                                           #
#---------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                 #
#---------------------------------------------------------------------------#
#  1.0        William Price  04/01/2004  Initial Release                    #
#                                                                           #
#############################################################################
#================================================
#ACCEPTS ONE COMMAND LINE PARAMETER.
#================================================

  if [[ $# != 1 ]] then
     echo "Usage MDA_preprocess.ksh <RUN MODE>"
     exit 1
  else
     export RUN_MODE=`echo $1 | tr '[A-Z]' '[a-z]'`

     case ${RUN_MODE} in
     
         'w'         )
             typeset -i DAY_OF_MONTH
             DAY_OF_MONTH=`date +'%d'`
             echo $DAY_OF_MONTH
             if (($DAY_OF_MONTH < 7)); then
                if (($DAY_OF_MONTH > 1)); then
                   echo "preventing weekly load from running days 2-6 of month"
                   exit 9
                fi
             fi
             echo "MDA Weekly claims load processing BEGINS - `date +'%b %d, %Y %H:%M:%S'`......." 
             RUN_MODE="weekly";;

         'm'         )
             echo "MDA Monthly claims load processing BEGINS - `date +'%b %d, %Y %H:%M:%S'`......." 
             RUN_MODE="monthly";;

      esac

  fi

  echo "parameter run mode : " ${RUN_MODE}  >> $LOG_FILE

#================================================
#EXECUTE MDA TEST PROFILE.
#THIS PROFILE DEFINES VARIOUS REQUIRED VARIABLES
#AND EXPORTS THEM FOR CHILD PROCESSES TO USE.
#================================================

  . /vracobol/prod/script/dbenv.ksh >/dev/null 2>&1
  . /vracobol/prod/script/MDA_prod_profile >/dev/null 2>&1 

export

# check to see if status of current run exists, and if it does, 
# check to see if the process still needs to be run (blank status)

  if [[ -s $RUN_STATUS ]] ; then
     
     typeset -x current_run_status
      
     current_run_status=`cat ${RUN_STATUS}`

     case ${current_run_status} in
     
         'blank'         )

               DATE_OF_FILE=`date +'%Y%m%d%H%M%S'`

#              found a blank status, check for FTP file.  If it exists and
#              and is done being FTP'd, then claims intake process can begin.
      
               echo "looking for ftp of file" >> $LOG_FILE 

               $SCRIPT_DIR/MDA_get_datafile.ksh >>$LOG_FILE 2>&1
              
               GET_DATAFILE_STATUS=$?

#              see if we successfully got a file and put it into  
#              /staging area for further processing.

               if [[ $GET_DATAFILE_STATUS = 0 ]]; then

#                 notify the Actuate support pager asking to stop report generation processes

                  echo "email notifying Actuate support to stop reports" >> $LOG_FILE
                  
                  print "Please stop the report generation. MDA needs to load "  \
                  `wc -l < $STAGING_DIR/*claims*`                                \
         	  "\nrecords in the File" > $MAILFILE

     		  MAIL_SUBJECT="MDA $RUN_MODE claims load needs report generation halted"
     		  $SCRIPT_DIR/mailto_ACTUATE_group.ksh > /dev/null 2>&1
                                
#                 notify the MDA support pager that processing has started

                  echo "email notifying MDA support that processing has started" >> $LOG_FILE
                  
                  print "Processing for $RUN_MODE has started.  There are "  \
                  `wc -l < $STAGING_DIR/*claims*`                            \
         	  "\nrecords in the File" > $MAILFILE

     		  MAIL_SUBJECT="MDA $RUN_MODE claims PROCESS started"
     		  $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

#                 update the status for the client for this current process run
     		  print "started" > $RUN_STATUS
     		  
#     		  store the directory for this run for clean up before the next run
#                 moved to end of successful run of claims intake processing
#                 print "${TEMP_DIR}"> $CLIENT_DIR/last_temp_dir
                                   
#                 Continue with main MDA_process
                  $SCRIPT_DIR/MDA_process_claims.ksh $CLIENT_NAME >>$LOG_FILE 2>&1
                                                     
	       elif  (($GET_DATAFILE_STATUS != 1 )); then		  
	          echo "ERRORS in MDA_get_datafile..." >>$LOG_FILE

                  print "Script: MDA_preprocess"                             \
          	  "\nProcessing for $RUN_MODE claims intake had a problem:"  \
          	  "\nFile could not be moved for compression processing"     \
          	  "\nLook for Log file $LOG_FILE" > $MAILFILE

     		  MAIL_SUBJECT="MDA claims intake PROCESS error"
     		      $SCRIPT_DIR/mailto_IS_group.ksh
     		      
	       else 
#	   	  $? = 1, return code = 1

#                 Let's see if there's a control file with a zero count
#                 This is acceptable during the weekly processing cycle only.
#                 For monthly processing... the too late job will signal error
#                 since a file is required at month-end

                  echo "in control checks"

                  NO_OF_FILES=`ls -1 $FTP_STAGING_DIR/*control* | wc -l`

                  if [[ $NO_OF_FILES -gt 1 ]]; then
  
                     print "Script: MDA_preprocess"                                 \
                           "\nProcessing for $RUN_MODE claims intake Failed:"       \
                           "\nFtp staging directory has more than one control file" \
                           "\nLook for Log file $LOG_FILE" > $MAILFILE
                     MAIL_SUBJECT="MDA $RUN_MODE claims intake PROCESS"
                     $SCRIPT_DIR/mailto_IS_group.ksh

                  else
                     if [[ $NO_OF_FILES -eq 1 ]]; then
#                       one control file, no claims associated...check for a zero claims count sent.   

                        if [[ $RUN_MODE = 'weekly' ]]; then

                           MDA_RECORDS_SENT=`cat $FTP_STAGING_DIR/*control* | cut -c 31-39`

                           if [[ $MDA_RECORDS_SENT -eq 0 ]]; then
#                              send SBO audit email that no claims were added for this week.

                               echo "There was no weekly claims file to load this week" \
                                    "\nNo. of records sent: 0 "                         \
                                    "\nNo. of records processed: 0 "                    \
                                    "\nNo. of records accepted : 0 "                    \
                                    "\nNo. of records rejected : 0 " > $MAILFILE_SBO 

#                              send zero count audit email.
                               MAIL_SUBJECT="MDA $RUN_MODE claims intake process auditing info"
                               print "`cat $MAILFILE_SBO`" > $MAILFILE
                               $SCRIPT_DIR/mailto_MDA_SBO_group.ksh 

#                              need to copy SBO audits to where all SBO audit reports are being saved.

#                              cp -p "$TEMP_DATA_DIR/psvnrbt.dat" $HOME_DIR/nonrebateable_claims/psvnrbt.dat.$DATE_OF_FILE
                               print "`cat $MAILFILE_SBO`" > $SARBANES_OXLEY_DIR/Audit_totals.$DATE_OF_FILE

                               if [[ $? != 0 ]] then
                                  echo "problems saving SBO audit totals" >> $LOG_FILE

                                  print "problems moving zero SBO audit info from $MAILFILE_SBO to "      \
                                        "$SARBANES_OXLEY_DIR/Audit_totals.$DATE_OF_FILE" > $MAILFILE
        
                                  MAIL_SUBJECT="MDA claims load process problem saving SBO audit totals"
                                  $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  
                               fi

#                              send zero count email to support.
                               echo "\nProcessing for $RUN_MODE claims intake completed"     \
                                    "\nThere were no records to load this week" > $MAILFILE

                               MAIL_SUBJECT="MDA $RUN_MODE claims intake completed"
                               $SCRIPT_DIR/mailto_IS_group.ksh

	                       rm $FTP_STAGING_DIR/*control*
                               if [[ $? != 0 ]] then
                                  echo "problems removing old zero control file" >> $LOG_FILE

                                  print "problems removing old zero control file" > $MAILFILE
        
                                  MAIL_SUBJECT="MDA claims load process problem deleting old control record"
                                  $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>$1  
                               fi

#                              update the status for the client for this current process run
                               print "completed" > $RUN_STATUS
                            fi        
                         fi
                      fi  
                  fi

		  echo "No data file was found... exit, retry when rescheduled " >>$LOG_FILE 
                  rm -rf $TEMP_DIR

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
                echo "MDA can start.. could not wait for deadbeat claims" >> $LOG_FILE
                rm -rf $TEMP_DIR
                return 0 ;;
                          
      esac
      
  else 
     #  either RUN_STATUS file does not exist or is empty
     #  we'll create a blank run_status file
     echo "HELP ME!" >> $LOG_FILE
     rm -rf $TEMP_DIR

     print "blank" > $RUN_STATUS
   
  fi

  echo "MDA PRE-PROCESS ENDED - `date +'%b %d, %Y %H:%M:%S'`......."
  
  exit 0
