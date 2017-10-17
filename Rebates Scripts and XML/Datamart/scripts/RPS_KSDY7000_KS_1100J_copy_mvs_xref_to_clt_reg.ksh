#!/bin/ksh
set -x
#-------------------------------------------------------------------------#
# Script        : RPS_KSDY7000_KS_1100_copy_mvs_xref_to_clt_reg.ksh
# Title         : Copy Scottsdale MVS Xref data to Silver Client Reg
#
# Description   : This script will copy over data from the Scottsdale
#                 MVS Client XRef system view DBAP1.VW_RBAT_REGS in order
#                 to aid the Oncalls research into Client XRef. 
#                 Yes we know this job is running on R07PRD05 but putting 
#                 data on REBDOM1, but REBDOM1 currently does not have  
#                 any of the database XML logic, and it's planned on being
#                 retired this year.
#
# Abends        : If database error occurs, a page will be sent to oncall.
#
# Parameters    : None 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK;  >0 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 03-02-07   qcpi733     Initial Creation.
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

SCRIPT=RPS_KSDY7000_KS_1100J_copy_mvs_xref_to_clt_reg
JOB=KS_1100J
XML_FILE=$XML_PATH/"clntreg_load_mvs_xref.xml"
LOG_FILE=$LOG_PATH/$JOB.$TIME_STAMP.log
RETCODE=0

print " Starting script " $SCRIPT `date`                              
print " Starting script " $SCRIPT `date`                                       > $LOG_FILE


#################################################################
# refresh Client Reg RBATE_REG.S_MVS_CLT_XREF_RSRCH
#################################################################

sqml $XML_FILE                                                                 >> $LOG_FILE
export RETCODE=$?
EMAIL_SUBJECT=$SCRIPT" "$XML_FILE
print "sqml retcode from $XML_FILE was " $RETCODE
print "sqml retcode from $XML_FILE was " $RETCODE                              >> $LOG_FILE

#################################################################
# send email for script errors
#################################################################

if [[ $RETCODE != 0 ]]; then 
   print "aborting $SCRIPT due to errors " 
   print "aborting $SCRIPT due to errors "                                     >> $LOG_FILE 
SUPPORT_EMAIL_ADDRESS="randy.redus@caremark.com"
   EMAIL_SUBJECT=$SCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   print "return_code =" $RETCODE
   exit $RETCODE
fi

mv $LOG_FILE       $LOG_ARCH_PATH/ 

print "return_code =" $RETCODE
exit $RETCODE
