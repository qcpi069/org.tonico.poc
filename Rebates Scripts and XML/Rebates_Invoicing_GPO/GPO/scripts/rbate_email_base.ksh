#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_email_base.ksh   
# Title         : email script.
#
# Description   : Email script
#
# Parameters    : See list of parameters below that are exported by the 
#                 calling script.
#
# Output        : Log file as $OUTPUT_PATH/rbate_email_base.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 08-08-2002  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#
# rebates_env.ksh not executed here. Was executed within the calling
# KORN script. Command left inhere as a comment to remind developers
# of the environment script in effect.
#-------------------------------------------------------------------------#

##. `dirname $0`/rebates_env.ksh

#
#-------------------------------------------------------------------------#
# Parameters that may have been exported are
#   JOBNAME => name of the maestro job being executed
#   SCRIPTNAME => path and name of the calling script
#   LOGFILE => path and name of the Log File of the calling job
#   EMAILPARM4 => Mail to Pager PARM, If set to MAILPAGER
#   EMAILPARM5 => not being used at this time       
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Email the message               
#-------------------------------------------------------------------------#
rm -rf $OUTPUT_PATH/rbate_email_base.txt
rm -rf $OUTPUT_PATH/rbate_email_base.log

print "An ABEND has occurred within the Rebates Integration application system." >> $OUTPUT_PATH/rbate_email_base.txt
print "Please take note of the following information." >> $OUTPUT_PATH/rbate_email_base.txt
print " " >> $OUTPUT_PATH/rbate_email_base.txt
print " " >> $OUTPUT_PATH/rbate_email_base.txt

if [[ -n $JOBNAME ]]; then
   print "Schedule / Jobname is " $JOBNAME >> $OUTPUT_PATH/rbate_email_base.txt
else
   print "Schedule / Jobname is not supplied by the calling script." >> $OUTPUT_PATH/rbate_email_base.txt
fi

print " " >> $OUTPUT_PATH/rbate_email_base.txt

if [[ -n $SCRIPTNAME ]]; then
   print "Script Name is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_email_base.txt
else
   print "Script Name is not supplied by the calling script." >> $OUTPUT_PATH/rbate_email_base.txt
fi

print " " >> $OUTPUT_PATH/rbate_email_base.txt
   
if [[ -n $LOGFILE ]]; then
   print "The full LOG file can be found in " $LOGFILE >> $OUTPUT_PATH/rbate_email_base.txt
   print " " >> $OUTPUT_PATH/rbate_email_base.txt
   print "The last 250 lines of the LOG file are as follows: " $LOGFILE >> $OUTPUT_PATH/rbate_email_base.txt
   print " " >> $OUTPUT_PATH/rbate_email_base.txt
   tail -250 $LOGFILE >> $OUTPUT_PATH/rbate_email_base.txt
   USE_EMAIL_LOG=0
else
   print "The LOGFILE name is not supplied by the calling script." >> $OUTPUT_PATH/rbate_email_base.txt
   print "The last 250 lines of the LOG file can not be displayed." >> $OUTPUT_PATH/rbate_email_base.txt
   USE_EMAIL_LOG=1
   LOGFILE=$OUTPUT_PATH/rbate_email_base.log
fi

chmod 777 $OUTPUT_PATH/rbate_email_base.txt

if [[ $REGION = "prod" ]];   then
     export EMAIL_SUBJECT="PROD_Rebates_Integration_ABEND_Email_Notification"
   elif [[ $REGION = "dev3" ]];   then
     export EMAIL_SUBJECT="DEV3_Rebates_Integration_ABEND_Email_Notification"
   else  
     export EMAIL_SUBJECT="REGION_UNKNOWN_Rebates_Integration_ABEND_Email_Notification"
fi

if [[ $EMAILPARM4 = "MAILPAGER" ]]; then
   mailx -c 8884302503@archwireless.net -s $EMAIL_SUBJECT MMRebInvoiceITD@caremark.com < $OUTPUT_PATH/rbate_email_base.txt
else
   mailx -s $EMAIL_SUBJECT MMRebInvoiceITD@caremark.com < $OUTPUT_PATH/rbate_email_base.txt
fi

export MailRETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
   
if [[ $MailRETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_email_base.log
   print "===================== J O B  A B E N D E D ======================" >> $LOGFILE
   print "  Error Executing rbate_email_base.ksh          " >> $LOGFILE
   print "  Look in " $LOGFILE       >> $LOGFILE
   print "=================================================================" >> $LOGFILE
   if [[ $USE_EMAIL_LOG != 0 ]]; then
      cp -f $OUTPUT_PATH/rbate_email_base.log $LOG_ARCH_PATH/rbate_email_base.log.`date +"%Y%j%H%M"`
   fi 
   exit $MailRETCODE
fi
   
print '....Completed executing rbate_email_base.ksh ....'   >> $LOGFILE
if [[ $USE_EMAIL_LOG != 0 ]]; then
   mv -f $OUTPUT_PATH/rbate_email_base.log $LOG_ARCH_PATH/rbate_email_base.log.`date +"%Y%j%H%M"`
fi 
   
return $MailRETCODE

