#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_DSCNT_email_completed.ksh   
# Title         : email script.
#
# Description   : Email script
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 12-15-05   is00084    6005148   Modified to include Medicare-D changes
# 04-18-05   qcpi733    5998083   Changed code to include input MODEL_TYP_CD 
#                                 and to use this in the email.  Added 
#                                 Common environmental script.
# 01-28-2005 K. Gries             Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Email the message               
#-------------------------------------------------------------------------#
. ../Common_GDX_Environment.ksh
. `dirname $0`/MDA_Allocation_env.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
  #      export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
        export ALTER_EMAIL_ADDRESS=""
        SYSTEM="QA"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        SYSTEM="Production"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="nandini.namburi@caremark.com"
    SYSTEM="Development"
fi

LOG_FILE=$1

MODEL_TYP_CD=$2
if [[ -z MODEL_TYP_CD ]]; then 
    print "No MODEL_TYP_CD was passed in, aborting."                           >> $LOG_FILE
    return 1
else
    if [[ $MODEL_TYP_CD = 'G' ]]; then
        MODEL="GPO"
    elif [[ $MODEL_TYP_CD = 'X' ]]; then
        MODEL="Medicare"
    else
        MODEL="Discount"
    fi
fi

PERIOD_ID=$3

EMAIL_SUBJECT="$SYSTEM $MODEL Allocation for DSCNT has COMPLETED"`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
cat $INPUT_PATH/$MODEL"_allocation_email_TO_list.txt"|read DSCNT_EMAIL_TO_LIST
cat $INPUT_PATH/$MODEL"_allocation_email_CC_list.txt"|read DSCNT_EMAIL_CC_LIST
cat $INPUT_PATH/$MODEL"_allocation_email_FROM_list.txt"|read DSCNT_EMAIL_FROM_LIST

TALLOCATN_OWNER=vrap

COMPLETED_FILE=$LOG_PATH/"MDA_Allocation_DSCT_Completed_data_"$MODEL".dat"
ERROR_FILE=$LOG_PATH/"MDA_Allocation_DSCT_Error_data_"$MODEL".dat"
RUNNING_FILE=$LOG_PATH/"MDA_Allocation_DSCT_Running_data_"$MODEL".dat"

EMAIL_TEXT=$LOG_PATH/"MDA_Allocation_DSCNT_start_email_"$MODEL".txt"
rm -rf $EMAIL_TEXT

print "\n\tThe Allocation process for Discount for Period $PERIOD_ID has completed." >> $EMAIL_TEXT
print "\n\tCompleted Discount Allocations within the last five (5) days are: " >> $EMAIL_TEXT

MAIL_SQL_STRING="Select PERIOD_ID, DISCNT_RUN_MODE_CD, ALOC_TYP_CD, CNTRCT_ID, RPT_ID, REQ_DT, REQ_TM, STRT_DT, STRT_TM, END_DT, END_TM, REQ_STAT_CD, RUN_DESC_TX from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD = 'C' and ALOC_TYP_CD = 'DISC' and (DayofYear(CURRENT DATE) - DayofYear(END_DT)) < 6 AND MODEL_TYP_CD = '$MODEL_TYP_CD' order by end_dt desc, end_tm desc"

print $MAIL_SQL_STRING >> $LOG_FILE 

db2 $MAIL_SQL_STRING > $COMPLETED_FILE

SQLCODE=$?

if [[ $SQLCODE > 1 ]]; then
    print "Completed count SQL failed" >> $LOG_FILE
    print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
else
    if [[ $SQLCODE = 0 ]]; then
        cat < $COMPLETED_FILE >> $EMAIL_TEXT  
    else
        print "\n\t\tThere were no other $MODEL Completed Discount Allocations within the last 5 days." >> $EMAIL_TEXT
    fi
fi 

MAIL_SQL_STRING="Select PERIOD_ID, DISCNT_RUN_MODE_CD, ALOC_TYP_CD, CNTRCT_ID, RPT_ID, REQ_DT, REQ_TM, STRT_DT, STRT_TM, END_DT, END_TM, REQ_STAT_CD, RUN_DESC_TX from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD in 'E' and ALOC_TYP_CD = 'DISC' and (DayofYear(CURRENT DATE) - DayofYear(END_DT)) < 6 AND MODEL_TYP_CD = '$MODEL_TYP_CD' order by end_dt, end_tm asc"

print $MAIL_SQL_STRING >> $LOG_FILE 

db2 $MAIL_SQL_STRING > $ERROR_FILE

SQLCODE=$?

if [[ $SQLCODE > 1 ]]; then
    print "Errored count SQL failed" >> $LOG_FILE
    print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
else
    if [[ $SQLCODE = 0 ]]; then
        print "\n\tErrored $MODEL Rebate Report Allocations within the last five (5) days are: " >> $EMAIL_TEXT
        cat < $ERROR_FILE >> $EMAIL_TEXT  
    else
        print "\n\t\tThere were no $MODEL Allocation errors within the last 5 days." >> $EMAIL_TEXT
    fi
fi 

MAIL_SQL_STRING="Select PERIOD_ID, DISCNT_RUN_MODE_CD, ALOC_TYP_CD, CNTRCT_ID, RPT_ID, REQ_DT, REQ_TM, STRT_DT, STRT_TM, END_DT, END_TM, REQ_STAT_CD, RUN_DESC_TX from $TALLOCATN_OWNER.tallocatn_schedule where REQ_STAT_CD in 'R' and ALOC_TYP_CD = 'DISC' and (DayofYear(CURRENT DATE) - DayofYear(END_DT)) < 6 AND MODEL_TYP_CD = '$MODEL_TYP_CD' order by end_dt, end_tm asc"

print $MAIL_SQL_STRING >> $LOG_FILE 

db2 $MAIL_SQL_STRING > $RUNNING_FILE

SQLCODE=$?

if [[ $SQLCODE > 1 ]]; then
    print "Running count SQL failed" >> $LOG_FILE
    print "DB2 return code is : <" $SQLCODE ">" >> $LOG_FILE
else
    if [[ $SQLCODE = 0 ]]; then
    print "\n\tAllocation Schedule records for $MODEL Rebate reports still in an 'R' status could be in error." >> $EMAIL_TEXT
    print "\n\tPlease verify these records are actually running at this time." >> $EMAIL_TEXT
    print "\n\tRunning Discount Allocations within the last five (5) days are: \n\n" >> $EMAIL_TEXT
        cat < $RUNNING_FILE >> $EMAIL_TEXT  
    else
        print "\n\t\tThere were no other $MODEL Allocations still in Running Status over the last 5 days." >> $EMAIL_TEXT
    fi
fi 

chmod 666 $EMAIL_TEXT

print "\n\nThis run was in $SYSTEM." >> $EMAIL_TEXT
print "\n\nIf you respond to this email, it will be sent to the GDXITD team." >> $EMAIL_TEXT

print " mail command is : " >> $LOG_FILE
print " mailx -c $DSCNT_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $DSCNT_EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
mailx -r $DSCNT_EMAIL_FROM_LIST -c $DSCNT_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $DSCNT_EMAIL_TO_LIST < $EMAIL_TEXT

MailRETCODE=$?
#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
   
if [[ $MailRETCODE != 0 ]]; then
   print " " >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing MDA_Allocation_DSCNT_email_completed.ksh          " >> $LOG_FILE
   print "  Look in " $LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   return $MailRETCODE
fi
   
print '....Completed executing MDA_Allocation_DSCNT_email_completed.ksh ....'   >> $LOG_FILE
   
return $MailRETCODE

