#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : MDA_Allocation_MKTSHR_email_started.ksh   
# Title         : email script.
#
# Description   : Email script
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-28-2005  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Email the message               
#-------------------------------------------------------------------------#
. `dirname $0`/MDA_Allocation_env.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
        SYSTEM="QA"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        SYSTEM="Production"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="randy.redus@caremark.com"
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
    else
        MODEL="Discount"
    fi
fi

PERIOD_ID=$3

EMAIL_SUBJECT="$SYSTEM $MODEL Allocation for MarketShare has STARTED"`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
cat $INPUT_PATH/$MODEL"_allocation_email_TO_list.txt"|read MKTSHR_EMAIL_TO_LIST
cat $INPUT_PATH/$MODEL"_allocation_email_CC_list.txt"|read MKTSHR_EMAIL_CC_LIST
cat $INPUT_PATH/$MODEL"_allocation_email_FROM_list.txt"|read MKTSHR_EMAIL_FROM_LIST

EMAIL_TEXT=$LOG_PATH/MDA_Allocation_MKTSHR_start_email.txt
rm -rf $EMAIL_TEXT

print "\tThe Allocation process for Market Share has started." >> $EMAIL_TEXT
print "\tThe model being processed is $MODEL." >> $EMAIL_TEXT
print "\n\tThe Period being processed is $PERIOD_ID." >> $EMAIL_TEXT
print "\n\tThis run was in $SYSTEM." >> $EMAIL_TEXT
print "\n\nIf you respond to this email, it will be sent to the GDXITD team." >> $EMAIL_TEXT

chmod 666 $EMAIL_TEXT

# Double quotes around the $EMAIL_SUBJECT allow for spaces in the subject line
print " mail command is : " >> $LOG_FILE
print " mailx -c $MKTSHR_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $MKTSHR_EMAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
mailx -r $MKTSHR_EMAIL_FROM_LIST -c $MKTSHR_EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $MKTSHR_EMAIL_TO_LIST < $EMAIL_TEXT
######print " mailx -c '$COPY_LIST' -s "$EMAIL_SUBJECT" $MAIL_TO_LIST < $EMAIL_TEXT " >> $LOG_FILE
######mailx -c ''$COPY_LIST'' -s "$EMAIL_SUBJECT" $MAIL_TO_LIST < $EMAIL_TEXT

MailRETCODE=$?
#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
   
if [[ $MailRETCODE != 0 ]]; then
   print " " >> $LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing MDA_Allocation_MKTSHR_email_started.ksh          " >> $LOG_FILE
   print "  Look in " $LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   return $MailRETCODE
fi
   
print '....Completed executing MDA_Allocation_MKTSHR_email_started.ksh ....'   >> $LOG_FILE
   
return $MailRETCODE

