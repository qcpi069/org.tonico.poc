#!/bin/ksh
#set -x 
#-------------------------------------------------------------------------#
#
# Script        : GDX_GD_0050J_Delete_NonCurrent_Claim_Exceptions.ksh   
# Title         : 
#
# Description   : Delete non-current RCIT_CLM_EXCPT rows
#
# Details       : column CUR_EXCPT_CD indicates 0=non-current, 1=current   
#
# Maestro Job   : GD_0050J
#
# Parameters    : non-Required Rows per Delete [defaults to 10,000 if not provided]
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE, 
#                
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 02-11-10   qcpi564     Initial Creation
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

  . `dirname $0`/Common_GDX_Environment.ksh

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
    }                                                                          >> $LOG_FILE

    . $SCRIPT_PATH/Common_GDX_Email_Abend.ksh

    print ".... $SCRIPTNAME  abended ...."                                     >> $LOG_FILE

    cp -f $LOG_FILE $LOG_FILE_ARCH
    exit $RETCODE
}
#-------------------------------------------------------------------------#

# Region specific variables
if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS=""
        LOG_FILE_SIZE_MAX=5000000
        SYSTEM="QA"
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=""
        LOG_FILE_SIZE_MAX=5000000
        SYSTEM="PRODUCTION"
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS="peter.merk@caremark.com" 
    LOG_FILE_SIZE_MAX=100000
    SYSTEM="DEVELOPMENT"
fi

# Common Variables
RETCODE=0
SCHEDULE="RCDY2000"
JOB="GD_0050J"
FILE_BASE="GDX_GD_0050J_Delete_NonCurrent_Claim_Exceptions"
SCRIPTNAME=$FILE_BASE".ksh"

# LOG FILES
LOG_FILE_ARCH="${LOG_ARCH_PATH}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_PATH}/${FILE_BASE}.log"

# Cleanup from previous run is handled at the end of the script.
#   Multiple runs are kept in one log, until it gets too large.

#-------------------------------------------------------------------------#
# Starting the script and log the starting time. 
#-------------------------------------------------------------------------#
   {
      print " "
      print " "
      print " "
      print "Starting the script $SCRIPTNAME ......"                              
      print `date +"%D %r %Z"`
      print "********************************************"
      print " "      
   }                                                                              >> $LOG_FILE

#-------------------------------------------------------------------------#
# Define/Build SQL Statements
#-------------------------------------------------------------------------#
#------------------------------------------------------------------------------+--------------
   print "Parm: Rows/Delete: <$1>"                                                >> $LOG_FILE
   if [[ $# -lt 1 ]]; then
      DEL_ROWS=10000
      print "NOTE: Rows/Delete defaulted to 10,000 ..."                           >> $LOG_FILE
   else
      DEL_ROWS=$1
   fi
   print ""                                                                       >> $LOG_FILE

   DEL_SQL_STMT="delete from (select * from vrap.RCIT_CLM_EXCPT"
   DEL_SQL_STMT="$DEL_SQL_STMT where CUR_EXCPT_CD = '0'"
   DEL_SQL_STMT="$DEL_SQL_STMT fetch first $DEL_ROWS rows only)"
   print "RCI Delete Statement: $DEL_SQL_STMT"                                    >> $LOG_FILE

   SQL_COMMIT="commit"

#-------------------------------------------------------------------------#
# Connect to the database
#-------------------------------------------------------------------------#

   print " "                                                                      >> $LOG_FILE
   print "Connecting to GDX database......"                                       >> $LOG_FILE
   db2 -px "connect to $DATABASE user $LOAD_CONNECT_ID using $LOAD_CONNECT_PWD"   >> $LOG_FILE
   RETCODE=$?
   print "RETCODE=<$RETCODE>"                                                     >> $LOG_FILE

   if [[ $RETCODE -ne 0 ]]; then
      print "ERROR: couldn't connect to database......"                           >> $LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Delete from RCIT_CLM_EXCPT
#   Use loop to delete DEL_ROWS rows at a time
#   Do the commit first, so that the Return Code can be used on WHILE condition
#-------------------------------------------------------------------------#

   print " "                                                                      >> $LOG_FILE
   print "Beginning Delete Loop ..."                                              >> $LOG_FILE
   print " "                                                                      >> $LOG_FILE

   while [[ $RETCODE -eq 0 ]]; do

      db2 -px "$SQL_COMMIT"                                                       >> $LOG_FILE
      RETCODE=$?

      if [[ $RETCODE -ne 0 ]]; then
         print "ERROR: Commit failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
         print "Return code is : <$RETCODE>"                                      >> $LOG_FILE
         exit_error $RETCODE
      fi

      db2 -mpx "$DEL_SQL_STMT"                                                    >> $LOG_FILE
      RETCODE=$?

      if [[ $RETCODE -gt 1 ]]; then
         print "ERROR: Delete failed in " $SCRIPTNAME " ...          "            >> $LOG_FILE
         print "Return code is : <$RETCODE>"                                      >> $LOG_FILE
         exit_error $RETCODE
      fi

   done

   db2 -px "$SQL_COMMIT"                                                          >> $LOG_FILE
   RETCODE=$?

   if [[ $RETCODE -ne 0 ]]; then
      print "ERROR: Commit failed in " $SCRIPTNAME " ...          "               >> $LOG_FILE
      print "Return code is : <$RETCODE>"                                         >> $LOG_FILE
      exit_error $RETCODE
   fi

   print " "                                                                      >> $LOG_FILE
   print "Delete Looping Completed"                                               >> $LOG_FILE
   print `date +"%D %r %Z"`                                                       >> $LOG_FILE
   print " "                                                                      >> $LOG_FILE

   if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
      mv -f $LOG_FILE $LOG_FILE_ARCH
   fi

exit $RETCODE

