#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : GDX_GDDY0010_allocation_status_email.ksh   
# Title         : Email status of Allocation processing.
#
# Description   : This script will check the report the status of Allocations
#                 for Rebate and Market shar reports.
#                 
#
# Maestro Job   : GDDY0010 / 
#
# Parameters    : MODEL - Model
#         REPORT_TYPE_IN - Type of Allocation
#                 ACTION - text string used in the email subject and body
#                 LOG_FILE - The path and logfile name of the calling script. 
#
# Output        : Log file as $LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date     Analyst    Project   Description
# ---------  ---------  --------  ----------------------------------------#
# 04-13-05   qcpu70z    6010240   Initial Creation - cloned from
#                                 GDX_GDDY0010_harvest_results_email.ksh 
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
 
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
          export ALTER_EMAIL_ADDRESS="Nick.Tucker@caremark.com"
          SYSTEM="QA"
    else
       # Running in Prod region
          export ALTER_EMAIL_ADDRESS="Nick.Tucker@caremark.com"
          SYSTEM="PRODUCTION"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="Nick.Tucker@caremark.com"
    SYSTEM="DEVELOPMENT"
fi

RETCODE=0

#--Verify number of parameters sent to script
#
if [ $# -lt 4 ]; then
   RETCODE=1
fi

#Capture input here for use in FILE_BASE variable.
#  turn the Model Type input into uppercase

MODEL=$(echo $1|dd conv=ucase 2>/dev/null)
REPORT_TYPE_IN=$2
ACTION=$3
LOG_FILE=$4

# The log file name is passed in from the calling script. DO NOT archive or delete the 
# log file from this script

SCHEDULE="GDDY0010"
JOB=""
FILE_BASE="GDX_"$SCHEDULE"_allocation_status_email_"$MODEL
SCRIPTNAME=$FILE_BASE".ksh"

# Output files
EMAIL_ARCHIVE=$OUTPUT_ARCH_PATH/$FILE_BASE"_archived.txt"`date +"%Y%j%H%M"`

# Input files
EMAIL_SUBJECT=""
EMAIL_BODY=$OUTPUT_PATH/$FILE_BASE"_body.txt"
# Put date in format of 12 hr:minutes:seconds am/pm on Abbrv Month Day, 4 digit year. The double quotes
#    allows for extra fields without having to redo the date command.
EMAIL_DATE=`date +"%l:%M:%S %p %Z on %b %e, %Y"`

# Cleanup from previous run
rm -f $EMAIL_BODY

#-------------------------------------------------------------------------#
# 
#-------------------------------------------------------------------------#
    print `date`                                                                    >> $LOG_FILE
    print "Starting the script to email Allocation status."                         >> $LOG_FILE
    print " "                                                                       >> $LOG_FILE
    print " "                                                                       >> $LOG_FILE
#-------------------------------------------------------------------------#
# 
#-------------------------------------------------------------------------#
 
if [[ $RETCODE = 0 ]]; then 

  cat $INPUT_PATH/$FILE_BASE"_TO_list.txt"|read EMAIL_TO_LIST
  cat $INPUT_PATH/$FILE_BASE"_CC_list.txt"|read EMAIL_CC_LIST
  cat $INPUT_PATH/$FILE_BASE"_FROM_list.txt"|read EMAIL_FROM_LIST  

# Read in what the email file is going to be called.  The email is saved to a file based on 
# the TO addressess.  Use this to move the file to an archive at the end.
  
  cat $INPUT_PATH/$FILE_BASE"_TO_list.txt"|read EMAIL_ARCHIVE_NAME
    

  print "Building the email subject line."                                  >> $LOG_FILE
  EMAIL_SUBJECT="Allocation for "$MODEL" "$REPORT_TYPE_IN" has "$ACTION`date +" on %b %e, %Y at %l:%M:%S %p %Z"`
  
  print "Building the email body."                                      >> $LOG_FILE
  print "\nThe Allocation for the $MODEL model was requested, and has $ACTION \n"   >> $EMAIL_BODY
     if [[ $REGION = "test" ]]; then
        print "\nThis run occured in the DEVELOPMENT region."                   >> $EMAIL_BODY
     else
        print "\nThis run occured in the PRODUCTION region."                        >> $EMAIL_BODY
     fi
   
   print "Sending the email."                                       >> $LOG_FILE
  #Email parms set at top of script, and in above case.  Subject (-s) must be in quotes if spaces are in the subject.
   CURR_DIR=$(pwd)

    cd $INPUT_PATH
    mailx -F -r $EMAIL_FROM_LIST -c $EMAIL_CC_LIST -s "$EMAIL_SUBJECT" $EMAIL_TO_LIST < $EMAIL_BODY 

   # The mailx -F parm puts the email into a filename based on the first TO person.  Move this file to the
   #    output dir.
   mv -f $EMAIL_ARCHIVE_NAME $EMAIL_ARCHIVE  >> $LOG_DIR 

   cd "$CURR_DIR"
fi    


print " "                                                                           >> $LOG_FILE
print " "                                                                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                    >> $LOG_FILE
print " Return Code is " $RETCODE                                       >> $LOG_FILE
print " "                                                                           >> $LOG_FILE

return $RETCODE

