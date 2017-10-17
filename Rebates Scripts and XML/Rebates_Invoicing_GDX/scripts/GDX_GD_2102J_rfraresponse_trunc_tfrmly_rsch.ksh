#!/bin/ksh 
#-------------------------------------------------------------------------#
# Script        : GDX_GD_2102J_rfraresponse_trunc_frmly_rsch.ksh    
# Title         : truncate the vrap.tfrmly_rsch table
#                 
#
# Description   : This script uses DB2 import of a NULL file to truncate
#		  the vrap.tfrmly_rsch table. This table needs to be emptied
#		  every time we load and process a new rfraresponse file.
#                 
#                 
# Parameters    : N/A 
# 
# Output        : Log file as $LOG_FILE
#
# Input Files   : GDX/prod/input
#
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 05-21-07   is31701     Initial Creation
# 
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_GDX_Environment.ksh
#-------------------------------------------------------------------------#
# Call the Common used script functions to make functions available
#-------------------------------------------------------------------------#
#. $SCRIPT_PATH/Common_GDX_Script_Functions.ksh

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    EMAILPARM4='MAILPAGER'
    EMAILPARM5='  '

    if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
    fi

    {
        print 'Sending email notification with the following parameters'

        print "JOBNAME is $JOBNAME"
        print "SCRIPTNAME is $SCRIPTNAME"
        print "LOG_FILE is $LOG_FILE"
        print "EMAILPARM4 is $EMAILPARM4"
        print "EMAILPARM5 is $EMAILPARM5"

        print '****** end of email parameters ******'
    } >> $LOG_FILE

   . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH
    exit $RETCODE
}

#-------------------------------------------------------------------------#
# Region specific variables
#-------------------------------------------------------------------------#


if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="nick.tucker@caremark.com"
fi


# Variables
RETCODE=0
SCHEDULE="GDMN2100"
JOB="GD_2102J"
SCRIPTNAME="GDX_GD_2102J_rfraresponse_trunc_frmly_rsch.ksh"

# LOG FILES
LOG_FILE_ARCH=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log."`date +"%Y%m%d_%H%M%S"`
LOG_FILE_NM=$(echo $SCRIPTNAME|awk -F. '{print $1}')".log"
LOG_FILE=$LOG_PATH/$LOG_FILE_NM


#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#

print "Starting the script $SCRIPTNAME ......"                                 >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE


#-------------------------------------------------------------------------#
# Step 1. Connect to UDB.
#-------------------------------------------------------------------------#

   print "Connecting to GDX database......"                                    >>$LOG_FILE
   db2 -p "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"           >>$LOG_FILE
   RETCODE=$?
   print 'RETCODE=<'$RETCODE'>'>> $LOG_FILE

   if [[ $RETCODE != 0 ]]; then
      print "ERROR: couldn't connect to database......"                        >>$LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Step 2. Truncate the vrap.tfrmly_rsch table in preparation for new file
#-------------------------------------------------------------------------#
   
        print "truncating VRAP.TFRMLY_RSCH  "`date`                            >> $LOG_FILE
   	db2 -stvxw import from /dev/null of del replace into vrap.tfrmly_rsch  >> $LOG_FILE 
        RETCODE=$?
        print "retcode from VRAP.TFRMLY_RSCH truncate is " $RETCODE "   "`date` >> $LOG_FILE

	if [[ $RETCODE != 0 ]]; then
           print "ERROR: couldn't Truncate VRAP.TFRMLY_RSCH......"             >>$LOG_FILE
        exit_error $RETCODE
	fi

#-------------------------------------------------------------------------#
# Step 3.  Clean up.                  
#-------------------------------------------------------------------------#

	RETCODE=0


print "********************************************"                           >> $LOG_FILE
print "....Completed executing " $SCRIPTNAME " ...."                           >> $LOG_FILE
print `date +"%D %r %Z"`                                                       >> $LOG_FILE
print "********************************************"                           >> $LOG_FILE

# move log file to archive with timestamp
        mv -f $LOG_FILE $LOG_ARCH_PATH/$LOG_FILE_ARCH

exit $RETCODE
