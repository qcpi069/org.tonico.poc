#!/usr/bin/ksh

##############################################################################
#SCRIPT NAME : MDA_weekly_deadline_chk.ksh                                   #
#                                                                            #
#PURPOSE     : To see if the weekly processing has run or is running         #
#              for the claims intake processing and send out a 0 claims      #
#              received email if it has not, reset the status to completed   #
#              This is a catch-all if analytics does not send us a file      #
#              for the week.  We'll assume nothing for this week then.       #
#                                                                            #
#									     #
#INSTRUCTIONS: This script takes no arguments at this time                   #
#              This script also uses some exports from the MDA profile       #
#              so if that is changed, the script should be changed as well.  # 
#              The script will email the addresses specified by the 	     #
#              internal variable SUPPORT_MAIL_LIST_FILE with any errors.     #
#	       If weekly claims intake is 'past deadline' the RUN_STATUS will#
#              be changed to 'past deadline'.                                #
#              This job will be scheduled on Wednesdays at 11:00am (crontab) #
#             								     #                                                                            #
#                                                                            #
#----------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                  #
#----------------------------------------------------------------------------#
#  1.0        William Price  06/06/2004  Initial Release                     #
#                                                                            #
##############################################################################

#EXPORTS AND VARS#
#export THIS_TIMESTAMP="T`date +"%Y%m%d%H%M%S"`"
#THIS_PROCESS_NO="_P$$"
#export HOME_DIR="/vracobol/prod"
#export SCRIPT_DIR="$HOME_DIR/script"
#export REF_DIR="$HOME_DIR/control/reffile"
#export SUPPORT_MAIL_LIST_FILE="$REF_DIR/MDA_support_maillist.ref"
#export RUN_MODE="weekly"
#export MAIL_SUBJECT=""
#CLAIMS_DIR="${HOME_DIR}/${RUN_MODE}"
#export TEMP_DIR="$HOME_DIR/temp/$THIS_TIMESTAMP$THIS_PROCESS_NO"
#export LOG_DIR="$HOME_DIR/log"
#export LOG_FILE="$LOG_DIR/MDA_$RUN_MODE.deadline_check.$THIS_TIMESTAMP$THIS_PROCESS_NO.log"
#export MAILFILE="$TEMP_DIR/mailfile"
#export MAILFILE_SBO="$TEMP_DIR/mailfile_sarbanes_oxley"
##touch $MAILFILE

SCRIPT_NAME="MDA_weekly_deadline_chk.ksh"
export RUN_MODE="weekly"
  . /vracobol/prod/script/MDA_prod_profile >/dev/null 2>&1 
export LOG_FILE="$LOG_DIR/MDA_$RUN_MODE.deadline_check.$THIS_TIMESTAMP$THIS_PROCESS_NO.log"

# normal weekly claims are stopped on days 2-6 so that monthly processing can run
# This requires the same logic plus 1 day
DAY_OF_MONTH=`date +'%d'`
#  echo $DAY_OF_MONTH
if (($DAY_OF_MONTH < 8)); then
   if (($DAY_OF_MONTH > 1)); then
       echo "preventing weekly deadline check from running days 2-7 of month"
       exit 9
   fi
fi
  
#make sure that CLAIMS_DIR/runstatus exists
if [[ ! -e ${CLAIMS_DIR}/runstatus ]]
 then
  echo "${CLAIMS_DIR}/runstatus not found"  >> $LOG_FILE
  echo "Script: $SCRIPT_NAME"                             \
       "\nProcessing for $RUN_MODE claims intake problem" \
        "\nError: ${CLAIMS_DIR}/runstatus not found" > $MAILFILE
  export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi

#get RUN_STATUS by grabbing first line and checking for no entry
read RUN_STATUS < ${CLAIMS_DIR}/runstatus
if [[ $RUN_STATUS = '' ]]
 then
  echo "${CLAIMS_DIR}/runstatus is empty"  >> $LOG_FILE
  echo "Script: $SCRIPT_NAME"                    \
       "\nProcessing for $RUN_MODE claims intake problem" \
        "\nError: ${CLAIMS_DIR}/runstatus is empty" > $MAILFILE
  export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi    
  
#check status: if 'blank', change to 'comnpleted' and notify
echo "$CLAIMS_DIR/runstatus value is $RUN_STATUS" >> $LOG_FILE

case ${RUN_STATUS} in
     
    'blank'         )

#       found a blank status, nothing was run for this weekly process yet.
        DATE_OF_FILE=`date +'%Y%m%d%H%M%S'`

        echo "process not run this $RUN_MODE processing period"  >> $LOG_FILE
        echo "email notifying MDA that processing has not run" >> $LOG_FILE
                  
        echo "Processing for $RUN_MODE claims intake was empty/did not run for this week" > $MAILFILE

        MAIL_SUBJECT="MDA $RUN_MODE claims PROCESS not run (no files)"
        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>>$LOG_FILE

#       send SBO audit email that no claims were added for this week.

        echo "There was no weekly claims file to load this week" \
             "\nNo. of records sent: 0 "                         \
             "\nNo. of records processed: 0 "                    \
             "\nNo. of records accepted : 0 "                    \
             "\nNo. of records rejected : 0 " > $MAILFILE_SBO 

#       send zero count audit email.
        MAIL_SUBJECT="MDA $RUN_MODE claims intake process auditing info"
        print "`cat $MAILFILE_SBO`" > $MAILFILE
        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>>$LOG_FILE

##wjptest        $SCRIPT_DIR/mailto_MDA_SBO_group.ksh 

#       need to copy SBO audits to where all SBO audit reports are being saved.

        print "`cat $MAILFILE_SBO`" > $SARBANES_OXLEY_DIR/Audit_totals.$DATE_OF_FILE

        if [[ $? != 0 ]] then
            echo "problems saving SBO audit totals" >> $LOG_FILE

            print "problems moving zero SBO audit info from $MAILFILE_SBO to "      \
                  "$SARBANES_OXLEY_DIR/Audit_totals.$DATE_OF_FILE" > $MAILFILE
        
            MAIL_SUBJECT="MDA claims load process problem saving SBO audit totals"
            $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>>$LOG_FILE
        fi

#       send zero count email to support.
        echo "\nProcessing for $RUN_MODE claims intake completed"     \
             "\nThere were no records to load this week" > $MAILFILE

        MAIL_SUBJECT="MDA $RUN_MODE claims intake completed"
        $SCRIPT_DIR/mailto_IS_group.ksh

#       update the status for the RUN_MODE for this current process run
        print "completed" > ${CLAIMS_DIR}/runstatus

        rm -rf $TEMP_DIR
        return 0 ;;
               
    'started'       )          
         echo "hold your horses... we\'ve started to process the ${RUN_MODE} claims intake process" >> $LOG_FILE
         rm -rf $TEMP_DIR
         return 0 ;;

    'completed'     )

         rm -rf $TEMP_DIR

         echo "done for this $RUN_MODE claims intake processing period" >> $LOG_FILE
         return 0 ;;
                
## should never get this status since this a weekly processing period is NOT required to run
#    'past deadline' )

#        echo "process not run this $RUN_MODE processing period" >> $LOG_FILE 
#        echo "email notifying MDA that processing has not run" >> $LOG_FILE
                  
#        print "Processing for $RUN_MODE claims intake was empty/did not run for this week" > $MAILFILE

#        MAIL_SUBJECT="MDA $RUN_MODE claims PROCESS not run (no files)"
#        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

##       update the status for the client for this current process run
#        print "completed" > ${CLAIMS_DIR}/runstatus

#        rm -rf $TEMP_DIR
#        return 0 ;;
esac
