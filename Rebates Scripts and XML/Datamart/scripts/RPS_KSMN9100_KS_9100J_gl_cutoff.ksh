#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_KSMN9100_KS_9100J_gl_cutoff.ksh
# Title         : Synchronize datamart with mainframe after monthly process
#
# Description   : This script will synchronize datamart tables with  
#                 payment system mainframe tables after montly GL cuttoff 
#                 is complete.
# 
# Abends        : If select count does not match insert results then set bad 
#                 return code.
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
# 02-06-06   qcpi768     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSMN9100_KS_9100J_gl_cutoff
JOB=ks9100j
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