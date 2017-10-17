#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSMN7500_KS_7500J_rxlives_load.ksh   
# Title         : .
#
# Description   : Load rbate_reg.work_rxlives_rxc with processing months 
#                 Lives file for RECAP.
#                 
#                 
# Maestro Job   : KSMN7500 KS_7500J
#
# Parameters    : N/A - 
#                
# Input         : alvlives.ctl
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-30-2004  S.Swanson    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh


if [[ $REGION = "prod" ]];   then
     export REBATES_DIR=rebates_integration
     export ALTER_EMAIL_ADDRESS=''
     export MVS_DSN="PCS.P"
   if [[$QA_REGION = "true"]]; then
     export MVS_DSN="test.x"
     export ALTER_EMAIL_ADDRESS='' 
   fi
else
     export ALTER_EMAIL_ADDRESS=''  
     export REBATES_DIR=rebates_integration
     export MVS_DSN="test.d"
fi

RETCODE=0

SCHEDULE="KSMM7500"
JOB="KS_7510J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_rxlives_rxc_load"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"


rm -f $OUTPUT_PATH/$LOG_FILE


#----------------------------------
# Oracle userid/password
# specific for rbate_reg database
# and for rbate invoicing
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script if applicable
#-------------------------------------------------------------------------#

print " " >> $OUTPUT_PATH/$LOG_FILE
print "TODAYS DATE " `date` >> $OUTPUT_PATH/$LOG_FILE
print "Monthly Load RxLives to work_rxlives_rxc starting" >> $OUTPUT_PATH/$LOG_FILE
print ' ' >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Load alvlives.dat to work_rxlives_rxc
# using SQL Loader.               
#                                                                         
#-------------------------------------------------------------------------#
print `date` 'Beginning SQLLOADER Load rbate_reg.work_rxlives_rxc ' >> $OUTPUT_PATH/$LOG_FILE


$ORACLE_HOME/bin/sqlldr $db_user_password $INPUT_PATH/rxlives.ctl
                    
#-----------------------------------------------------------------------------
#check return code  if valid log completion else email error message
#
#-----------------------------------------------------------------------------
export RETCODE=$?

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed SQLLOADER work_rxlives_rxc ' >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'New rxlives  for RXC data loaded ' >> $OUTPUT_PATH/$LOG_FILE
   
else
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print `date` 'Failure in work_rxlives_rxc load. ' >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'SQLLOADER - Load of work_rxlives_rxc failed : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE


#-------------------------------------------------------------------------#
# Send email describing error                  
#-------------------------------------------------------------------------#

   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit 1
fi

#-----------------------------------------------------------------------------
# remove rxlives trigger file for rxlives work table load process
#-----------------------------------------------------------------------------
rm -f $INPUT_PATH/'rxlives.trigger'

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

