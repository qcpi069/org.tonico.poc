#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_MDA_Email_Abend.ksh   
# Title         : email Abend script.
#
# Description   : Email script
#
# Parameters    : See list of parameters below that are exported by the 
#                 calling script.
#
# Output        : Log file as $EMAIL_BASE_LOG
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-23-2005  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#
# rebates_env.ksh not executed here. Was executed within the calling
# KORN script. Command left inhere as a comment to remind developers
# of the environment script in effect.
#-------------------------------------------------------------------------#

EMAIL_SCRIPTNAME="Common_MDA_Email_Abend.ksh"
EMAIL_FILE_BASE=rbate_email_base
EMAIL_BASE_TEXT=$OUTPUT_PATH/$EMAIL_FILE_BASE".txt"
EMAIL_BASE_LOG=$OUTPUT_PATH/$EMAIL_FILE_BASE".log"

EMAIL_ADDRESS="MMRebInvoiceITD@caremark.com,William Price/PSD/MEDPARTNERS@Exchange"

 
#-------------------------------------------------------------------------#
# Parameters that may have been exported are
#   JOBNAME => name of the maestro job being executed
#   SCRIPTNAME => path and name of the calling script
#   LOG_FILE => path and name of the Log File of the calling job
#   EMAILPARM4 => Mail to Pager PARM, If set to MAILPAGER
#   EMAILPARM5 => not being used at this time       
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Email the message               
#-------------------------------------------------------------------------#
rm -rf $EMAIL_BASE_TEXT

print "An ABEND has occurred within the Caremark MDA application system." >> $EMAIL_BASE_TEXT
print "Please take note of the following information." >> $EMAIL_BASE_TEXT
print " " >> $EMAIL_BASE_TEXT
print " " >> $EMAIL_BASE_TEXT

if [[ -n $JOBNAME ]]; then
   print "Schedule / Jobname is " $JOBNAME >> $EMAIL_BASE_TEXT
else
   print "Schedule / Jobname is not supplied by the calling script." >> $EMAIL_BASE_TEXT
fi

print " " >> $EMAIL_BASE_TEXT

if [[ -n $SCRIPTNAME ]]; then
   print "Script Name is " $SCRIPTNAME >> $EMAIL_BASE_TEXT
else
   print "Script Name is not supplied by the calling script." >> $EMAIL_BASE_TEXT
fi

print " " >> $EMAIL_BASE_TEXT
   
print "The full LOG file can be found in " $LOG_FILE >> $EMAIL_BASE_TEXT
print " " >> $EMAIL_BASE_TEXT
print "The last 250 lines of the LOG file are as follows: " $LOG_FILE >> $EMAIL_BASE_TEXT
print " " >> $EMAIL_BASE_TEXT
tail -250 $LOG_FILE >> $EMAIL_BASE_TEXT

chmod 777 $EMAIL_BASE_TEXT

if [[ $REGION = "prod" ]];   then
  if [[ $QA_REGION = "true" ]]; then
     export EMAIL_SUBJECT="Caremark_MDA_QA_ABEND_Email_Notification"
  else  
     export EMAIL_SUBJECT="Caremark_MDA_PROD_ABEND_Email_Notification"
  fi
else
  export EMAIL_SUBJECT="Caremark_MDA_DEV_ABEND_Email_Notification"
fi


if [[ $EMAILPARM4 = "MAILPAGER" ]]; then
   if [[ ! -z $ALTER_EMAIL_ADDRESS ]]; then
      mailx -c 8884302503@archwireless.net -s $EMAIL_SUBJECT $ALTER_EMAIL_ADDRESS < $EMAIL_BASE_TEXT
   else
     mailx -c 8884302503@archwireless.net -s $EMAIL_SUBJECT $EMAIL_ADDRESS < $EMAIL_BASE_TEXT
   fi
else
   if [[ ! -z $ALTER_EMAIL_ADDRESS ]]; then
      mailx -s $EMAIL_SUBJECT  $ALTER_EMAIL_ADDRESS < $EMAIL_BASE_TEXT
   else
     mailx -s $EMAIL_SUBJECT $EMAIL_ADDRESS < $EMAIL_BASE_TEXT
   fi
fi

export MailRETCODE=$?

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#
   
if [[ $MailRETCODE != 0 ]]; then
   print " " >> $EMAIL_BASE_LOG
   print "===================== J O B  A B E N D E D ======================" >> $LOG_FILE
   print "  Error Executing $EMAIL_SCRIPTNAME         " >> $LOG_FILE
   print "  Look in " $LOG_FILE       >> $LOG_FILE
   print "=================================================================" >> $LOG_FILE
   return $MailRETCODE
fi
   
print "....Completed executing $EMAIL_SCRIPTNAME ...."   >> $LOG_FILE
   
return $MailRETCODE

