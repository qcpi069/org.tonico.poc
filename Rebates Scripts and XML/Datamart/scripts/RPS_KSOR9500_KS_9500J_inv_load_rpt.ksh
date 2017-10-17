#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSOR9500_KS_9500J_inv_load_rpt.ksh
# Title         : Generate invoice load balancing report
# Description   : This script will launch a Microstrategy report after  
#                 the payment system invoice load is complete.  It can 
#                 also be run on demand for manual billing adjustments.
# 
# Abends        : 
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
# 02-13-06   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSOR9500_KS_9500J_inv_load_rpt
JOB=ks9500j
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log

RETCODE=0

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                              > $LOG_FILE




#    more stuff goes here

 
#################################################################
# send email for script errors
#################################################################
if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                               >> $LOG_FILE 
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
   exit $RETCODE
fi

print " Script " $SCRIPT " completed successfully on " `date`                              
print " Script " $SCRIPT " completed successfully on " `date`            >> $LOG_FILE 

#################################################################
# cleanup from successful run
#################################################################
mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
