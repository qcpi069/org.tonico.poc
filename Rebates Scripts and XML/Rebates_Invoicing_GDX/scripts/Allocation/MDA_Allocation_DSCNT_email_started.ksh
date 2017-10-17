#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_DSCNT_email_started.ksh   
# Title         : email script.
#
# Description   : Email script
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 12-15-05   is00084    6005148   Modified to include Medicare-D changes.
# 04-18-05   qcpi733    5998083   Changed code to include input MODEL_TYP_CD 
#                                 and to use this in the email.  Added 
#                                 Common environmental script.
# 01-28-2005 K. Gries             Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Email the message               
#-------------------------------------------------------------------------#
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

EMAIL_SUBJECT="$SYSTEM $MODEL Allocation for DSCNT has STARTED"`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
cat $INPUT_PATH/$MODEL"_allocation_email_TO_list.txt"|read DSCNT_EMAIL_TO_LIST
cat $INPUT_PATH/$MODEL"_allocation_email_CC_list.txt"|read DSCNT_EMAIL_CC_LIST
cat $INPUT_PATH/$MODEL"_allocation_email_FROM_list.txt"|read DSCNT_EMAIL_FROM_LIST

EMAIL_TEXT=$LOG_PATH/"MDA_Allocation_DSCNT_start_email_"$MODEL".txt"
rm -rf $EMAIL_TEXT

print "\tThe Allocation process for Discount has started." >> $EMAIL_TEXT
print "\tThe model being processed is $MODEL." >> $EMAIL_TEXT
print "\n\tThe Period being processed is $PERIOD_ID." >> $EMAIL_TEXT
print "\n\tThis run was in $SYSTEM" >> $EMAIL_TEXT
print "\n\nIf you respond to this email, it will be sent to the GDXITD team." >> $EMAIL_TEXT

chmod 666 $EMAIL_TEXT

print " mail command is : " >> $LOG_FILE
print " mailx -r $DSCNT_EMAIL_FROM_LIST -c $DSCNT_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $DSCNT_EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
mailx -r $DSCNT_EMAIL_FROM_LIST -c $DSCNT_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $DSCNT_EMAIL_TO_LIST < $EMAIL_TEXT

MailRETCODE=$?
#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
   
if [[ $MailRETCODE != 0 ]]; then
   print " " >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing MDA_Allocation_DSCNT_email_started.ksh          " >> $LOG_FILE
   print "  Look in " $LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   return $MailRETCODE
fi
   
print '....Completed executing MDA_Allocation_DSCNT_email_started.ksh ....'   >> $LOG_FILE
   
return $MailRETCODE

