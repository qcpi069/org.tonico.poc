#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_7800J_dm_system_status.ksh
# Title         : Datamart System Status 
# Description   : This script will report on the status of the datamart  
#                 and its synchronization with replicated source tables.
# 
# Abends        : If an inconsistent state is detected the script will abend.
#                 
#
# Parameters    : None 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 12-01-05   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSDY7000_KS_7800J_dm_system_status
JOB=ks7800j

LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE

#################################################################
# check status of source database before proceeding
#################################################################
sqml $XML_PATH/dm_system_check.xml                                  >> $LOG_FILE
export RETCODE=$?
print "sqml retcode from dm_system_check was " $RETCODE
print "sqml retcode from dm_system_check was " $RETCODE             >> $LOG_FILE

print " Ending script " $SCRIPT `date`                            
print " Ending script " $SCRIPT `date`                              >> $LOG_FILE

#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                          >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $RETCODE
fi

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
