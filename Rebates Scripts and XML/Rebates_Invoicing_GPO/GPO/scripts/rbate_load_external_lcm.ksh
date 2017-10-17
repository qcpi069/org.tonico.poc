#!/bin/ksh                                                             
#==============================================================================
#                              CHANGE LOG
#==============================================================================
#  CHANGE   PROGRAMMER   PROJ/PROB
#   DATE        ID        NUMBER     CHANGE DESCRIPTION
#==============================================================================
#  10/24/02  is45401                 added logic to delete the trigger file;
#                                    added logic to send abend email.
#  06/17/02  is31701                 initial script  
#==============================================================================
# File Name    = rbate_load_external_lcm.ksh
# Description  = Execute SQLload to populate lcm's into T_EXTNL_LCM            
# Maestro Job  = KC_4100J
# Scheduled Run= Every Other Friday 3pm
#==============================================================================
#----------------------------------
# PCS Environment variables
#----------------------------------
. `dirname $0`/rebates_env.ksh

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

cd $OUTPUT_PATH
rm lcmxtrc.log

$ORACLE_HOME/bin/sqlldr $db_user_password $INPUT_PATH/lcmxtrc.ctl

RC=$?

if [[ $RC != 0 ]] then
   echo " "
   echo "===================== J O B  A B E N D E D ======================" 
   echo "  Error Executing rbate_load_external_lcm.ksh                        "
   echo "  Look in "$OUTPUT_PATH/lcmxtrc.log
# Send the Email notification
   export JOBNAME="KCBW4100 / KC_4100J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_load_external_lcm.ksh"
   export LOGFILE=$OUTPUT_PATH"/lcmxtrct.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "

   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/lcmxtrct.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/lcmxtrct.log
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/lcmxtrct.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/lcmxtrct.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/lcmxtrct.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/lcmxtrct.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/lcmxtrct.log
   . $SCRIPT_PATH/rbate_email_base.ksh
   exit $RC
else
#  Delete the trigger file for the External LCM's.  The next run is dependant on the trigger file, 
#    as well as a time dependancy.
   rm $INPUT_PATH/lcmxtrct.trigger
#  Copy the output log to the archive directory, with a timestamp.
   cd $OUTPUT_PATH
   cp $OUTPUT_PATH/lcmxtrc.log  $LOG_ARCH_PATH/lcmxtrc.log.`date +"%Y%j%H%M"`
fi
   
echo .... Completed executing rbate_load_external_lcm.ksh  .....



