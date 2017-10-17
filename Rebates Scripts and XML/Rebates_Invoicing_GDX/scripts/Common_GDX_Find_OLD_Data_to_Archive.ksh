#!/bin/ksh
#set -x 
#-------------------------------------------------------------------------#
#
# Script        : Common_GDX_Find_OLD_Data_to_Archive.ksh   
# Title         : 
#
# Description   : Find old partitioned data that needs archiving.
#
# Details       : Old partition data is moved to tables named OLD...
#                 Search for these recently created tables named like OLD.
#                 Result put into table vrap.CONTROL_ARCHIVE.
#                 Another [DBA] process will archive the data.
#
# Maestro Job   : Can be re-used in different jobs
#
# Parameters    : required: table name
#             non-required: day range to look for old data [default: 7]
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE, 
#                
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-14-10   qcpi564     Initial Creation
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
SCHEDULE="GDMN1000"
JOBNAME="Common"
FILE_BASE="Common_GDX_Find_OLD_Data_to_Archive"
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
   print "Parm: TABLE_NAME: <$1>"                                                 >> $LOG_FILE
   if [[ $# -ge 1 ]]; then
      TABLE_NAME=$1
   else
      print "ERROR: Table Name was NOT provided <--------------------ERROR"       >> $LOG_FILE
      print " "                                                                   >> $LOG_FILE 
      exit_error 1
   fi

   print "Parm: RANGE_DAYS: <$2>"                                                 >> $LOG_FILE
   if [[ $# -lt 2 ]]; then
      RANGE_DAYS=7
      print "NOTE: RANGE_DAYS defaulted to 7..."                                  >> $LOG_FILE
   else
      RANGE_DAYS=$2
   fi
   print " "                                                                      >> $LOG_FILE

   SQL_STMT="insert into vrap.CONTROL_ARCHIVE"
   SQL_STMT="$SQL_STMT select x.NAME, 'R' STATUS"
   SQL_STMT="$SQL_STMT from sysibm.SYSTABLES x"
   SQL_STMT="$SQL_STMT where x.CREATOR = 'VRAP'"
   SQL_STMT="$SQL_STMT and x.NAME like 'OLD%'"
   SQL_STMT="$SQL_STMT and x.NAME like '%$TABLE_NAME%'"
   SQL_STMT="$SQL_STMT and date(x.CTIME) >= current date - $RANGE_DAYS days"
   SQL_STMT="$SQL_STMT with ur"

   print "Find SQL Stmt: $SQL_STMT"                                               >> $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to the database
#-------------------------------------------------------------------------#

   print " "                                                                      >> $LOG_FILE
   print "Connecting to GDX database......"                                       >> $LOG_FILE
   db2 -px "connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"             >> $LOG_FILE
   RETCODE=$?
   print "cONNECT RETCODE=<$RETCODE>"                                             >> $LOG_FILE

   if [[ $RETCODE -ne 0 ]]; then
      print "ERROR: couldn't connect to database......"                           >> $LOG_FILE
      exit_error $RETCODE
   fi

#-------------------------------------------------------------------------#
# Find the recently created "OLD" tables
#-------------------------------------------------------------------------#

   print " "                                                                      >> $LOG_FILE
   print "Looking for OLD data......"                                             >> $LOG_FILE
   db2 -px "$SQL_STMT"                                                            >> $LOG_FILE
   RETCODE=$?
   print "  QUERY RETCODE=<$RETCODE>"                                             >> $LOG_FILE

   case $RETCODE in
      0) ;; #--Successful: Do nothing
      1)    #--No Rows Found: Valid, reset Return Code
         RETCODE=0;
         print " "                                                                >> $LOG_FILE;
         print "Query Return Code=1 [no rows found] valid.  Reset Return Code..." >> $LOG_FILE;
         print "  RESET RETCODE=<$RETCODE>"                                       >> $LOG_FILE;
         ;;
      *)    #--Error: Return Code > 1, exit error    
         print " "                                                                >> $LOG_FILE;
         print "ERROR: Query failed in " $SCRIPTNAME " ...          "             >> $LOG_FILE;
         print "Return code is : <$RETCODE>"                                      >> $LOG_FILE;
         exit_error $RETCODE;
         ;;
   esac

#-------------------------------------------------------------------------#
# Log File maintenance: Append to same, until max size reached
#-------------------------------------------------------------------------#

   if [[ $FILE_SIZE -gt $LOG_FILE_SIZE_MAX ]]; then
      mv -f $LOG_FILE $LOG_FILE_ARCH
   fi

exit $RETCODE

