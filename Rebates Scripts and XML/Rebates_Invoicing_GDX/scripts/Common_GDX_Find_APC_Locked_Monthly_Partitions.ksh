#!/bin/ksh
#set -x 
#-------------------------------------------------------------------------#
#
# Script        : Common_GDX_Find_APC_Locked_Monthly_Partitions.ksh   
# Title         : 
#
# Description   : Find old partitions of table, with monthly partitions
#                   that are for a period that is APC Locked.
#
# Details       : Expects table to be partitioned by months
#                 Finds partitions where the monthly period is APC Locked
#                 Loads results into table vrap.CONTROL_TABLE
#                 Another process uses entries to drop the partiton(s).
#
# Maestro Job   : ReUsed in many jobs
#
# Parameters    : required: table name
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
FILE_BASE="Common_GDX_Find_APC_Locked_Monthly_Partitions"
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
   print " "                                                                      >> $LOG_FILE

   SQL_STMT="insert into vrap.CONTROL_TABLE"
   SQL_STMT="$SQL_STMT select DISTINCT a.TABLENAME, a.MODEL_TYP_CD,"
   SQL_STMT="$SQL_STMT cast(a.YR||a.MN as char(4)) PERIOD, 'R' STATUS"
   SQL_STMT="$SQL_STMT from (select x.TABNAME TABLENAME"
   SQL_STMT="$SQL_STMT, case when left(right(DATAPARTITIONNAME,5),1)='_' then 'A'"
   SQL_STMT="$SQL_STMT else left(right(DATAPARTITIONNAME,5),1) end MODEL_TYP_CD"
   SQL_STMT="$SQL_STMT, right(x.DATAPARTITIONNAME,2) MN"
   SQL_STMT="$SQL_STMT, left(right(x.DATAPARTITIONNAME,4),2) YR"
   SQL_STMT="$SQL_STMT from sysibm.SYSDATAPARTITIONS x"
   SQL_STMT="$SQL_STMT where x.TABSCHEMA='VRAP'"
   SQL_STMT="$SQL_STMT and x.TABNAME = '$TABLE_NAME'"
   SQL_STMT="$SQL_STMT and right(x.DATAPARTITIONNAME,2)<>'99'"
   SQL_STMT="$SQL_STMT) a"
   SQL_STMT="$SQL_STMT, vrap.VRCIT_MODEL_PRD_STUS b"
   SQL_STMT="$SQL_STMT where a.MODEL_TYP_CD in (b.MODEL_TYP_CD,'A')"
   SQL_STMT="$SQL_STMT and cast('M'||a.MN||a.YR as char(6)) = b.PRD_ID"
   SQL_STMT="$SQL_STMT and b.APC_STAT_CD = 'L' and b.CLM_LOCK_CD = 'L'"
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
# Find the old monthly partitions that are APC Locked
#-------------------------------------------------------------------------#

   print " "                                                                      >> $LOG_FILE
   print "Looking for old partitions......"                                       >> $LOG_FILE
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

