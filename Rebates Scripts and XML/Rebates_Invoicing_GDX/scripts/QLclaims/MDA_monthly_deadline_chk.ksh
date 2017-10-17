#!/usr/bin/ksh

##############################################################################
#SCRIPT NAME : MDA_monthly_deadline_chk.ksh                                  #
#                                                                            #
#PURPOSE     : To see if the monthly processing has run or is running        #
#              for the claims intake processing and notify IS if it is not.  #
#             								     #
#									     #
#INSTRUCTIONS: This script takes no arguments at this time                   #
#              This script also uses some exports from the MDA profile       #
#              so if that is changed, the script should be changed as well.  # 
#              The script will email the addresses specified by the 	     #
#              internal variable SUPPORT_MAIL_LIST_FILE with any errors.     #
#	       If monthly claims intake is past deadline, the RUN_STATUS will#
#              be changed to 'past deadline'.                                #
#              This script is scheduled to run on the 7th of each month      #
#              through the crontab.					     #
#                                                                            #
#                                                                            #
#----------------------------------------------------------------------------#
#RELEASES    |  AUTHOR      |  DATE    |           Comments                  #
#----------------------------------------------------------------------------#
#  1.0        William Price  06/06/2004  Initial Release                     #
#                                                                            #
##############################################################################

#EXPORTS AND VARS#
export THIS_TIMESTAMP="T`date +"%Y%m%d%H%M%S"`"
THIS_PROCESS_NO="_P$$"
export HOME_DIR="/vracobol/prod"
export SCRIPT_DIR="$HOME_DIR/script"
export REF_DIR="$HOME_DIR/control/reffile"
export SUPPORT_MAIL_LIST_FILE="$REF_DIR/MDA_support_maillist.ref"
export RUN_MODE="monthly"
touch $MAILFILE
export MAIL_SUBJECT=""
CLAIMS_DIR="${HOME_DIR}/${RUN_MODE}"
export LOG_DIR="$HOME_DIR/log"
export LOG_FILE="$LOG_DIR/MDA_$RUN_MODE.deadline_check.$THIS_TIMESTAMP$THIS_PROCESS_NO.log"
export TEMP_DIR="$HOME_DIR/temp/$THIS_TIMESTAMP$THIS_PROCESS_NO"
export MAILFILE="$TEMP_DIR/mailfile"
SCRIPT_NAME="MDA_monthly_deadline_chk.ksh"

#make sure that CLAIMS_DIR/runstatus exists
if [[ ! -e ${CLAIMS_DIR}/runstatus ]]
 then
  echo "${CLAIMS_DIR}/runstatus not found" >> $LOG_FILE 
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
  echo "${CLAIMS_DIR}/runstatus is empty" >> $LOG_FILE 
  echo "Script: $SCRIPT_NAME"                    \
       "\nProcessing for $RUN_MODE claims intake problem" \
        "\nError: ${CLAIMS_DIR}/runstatus is empty" > $MAILFILE
  export MAIL_SUBJECT="MDA: $SCRIPT_NAME ERROR"
  $SCRIPT_DIR/mailto_IS_group.ksh
  exit
fi    
  
#check status: if 'blank', change to 'past deadline' and notify
echo "$CLAIMS_DIR/runstatus value is $RUN_STATUS" >> $LOG_FILE 

case ${RUN_STATUS} in
     
    'blank'         )

#       found a blank status, nothing was run for this monthly process yet.
#       this is not good, tell all!

        echo "process not run this $RUN_MODE processing period" >> $LOG_FILE 

        echo "email notifying MDA that processing has not run" >> $LOG_FILE
                  
        print "Processing for $RUN_MODE claims intake is late and has not yet been run" > $MAILFILE

        MAIL_SUBJECT="MDA $RUN_MODE claims PROCESS not run"
        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

#       update the status for the client for this current process run
        print "past deadline" > ${CLAIMS_DIR}/runstatus

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
                
## should never get this status since this script is supposed to set it.
    'past deadline' )

        echo "process not run this $RUN_MODE processing period" >> $LOG_FILE 

        echo "email notifying MDA that processing has not run" >> $LOG_FILE
                  
        print "Processing for $RUN_MODE claims intake is late and has not yet been run" > $MAILFILE

        MAIL_SUBJECT="MDA $RUN_MODE claims PROCESS not run"
        $SCRIPT_DIR/mailto_IS_group.ksh > /dev/null 2>&1

#       update the status for the client for this current process run
        print "past deadline" > ${CLAIMS_DIR}/runstatus

        rm -rf $TEMP_DIR
        return 0 ;;
esac
