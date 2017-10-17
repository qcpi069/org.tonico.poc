#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : RPS_GDX_APC_Status_update.ksh
# Title         : RPSDM update of the GDX APC status table
# Description   : This script will be called by other scripts on RPSDM 
#                 in order to update the GDX APC status table.
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
# 05-14-10   qcpi733     Uncommented the Common_RPS_Environment call
# 07-28-09   qcpi733     Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Payments Datamart Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RPS_Environment.ksh

cd $SCRIPT_PATH

APCSCRIPT="RPS_GDX_APC_Status_update"
JOB=

#LOG_FILE="$LOG_PATH/$APCSCRIPT.log$TIME_STAMP"

print " Starting script " $APCSCRIPT `date`                                       

# Check argument count
#------------------------------------------
if [[ $# < 2 ]] || [[ $# > 3 ]]; then 
    print "Error: Usage $0 <prcs id> <updtflg>"                                
    exit 1
fi

PRCS_ID=$1
UPDT_FLG="$2"

#################################################################
# check status of source database before proceeding
#################################################################

sqml --processId $PRCS_ID --updtFlg $UPDT_FLG $XML_PATH/gdx_APC_status_update.xml  

APCRETCODE=$?

print "sqml APCRETCODE from APC status update was " $APCRETCODE                      

#################################################################
# send email for script errors
#################################################################
if [[ $APCRETCODE != 0 ]]; then 
   print "aborting $APCSCRIPT due to errors "                                      
   EMAIL_SUBJECT=$APCSCRIPT
   mailx -s $EMAIL_SUBJECT $SUPPORT_EMAIL_ADDRESS < $LOG_FILE
   exit $APCRETCODE
fi

print " Ending script " $APCSCRIPT `date`                                         



