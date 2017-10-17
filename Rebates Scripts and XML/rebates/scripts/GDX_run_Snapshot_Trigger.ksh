#!/bin/ksh
#set -x
#-------------------------------------------------------------------------#
#
# Script        : GDX_run_Snapshot_Trigger.ksh
# Title         :
#
# Description   : Queries the TSNAP table to determine if there is a PENDING
#                 snapshot run where the REQ_RUN_TS is in the past.  If it
#                 does not find anything, it simply ends and will be
#                 resubmitted by Maestro within 15 minutes.
#                 If it does find something, then it will create a trigger
#                 file that will in turn trigger the snapshot batch process.
#   NOTE          The trigger file built in this script is also built in
#                 another job. This other job runs every 15 mins and can
#                 create the same trigger file, but creation is based on
#                 there being a specific row in the database table TSNAP.
#                 The other script is GDX_run_nightly_summary_trigger.ksh
#
# Maestro Job   : RDHR1000 RD_1100J
#
# Parameters    : None
#
# Output        : Log file as $LOG_DIR/$LOG_FILE,
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 04-08-13   qcpi733     Initial Creation for ITPR0001971
# 08-05-13   qcpi2d6     Changed REGION to get the different streams
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
  . `dirname $0`/Common_RCI_Environment.ksh

  . /home/user/udbcae/sqllib/db2profile

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#

function exit_error {
   RETCODE=$1
   ERROR=$2
   EMAIL_SUBJECT=$SCRIPTNAME" Abended In "$REGION" "`date`

   if [[ -z "$RETCODE" || "$RETCODE" = 0 ]]; then
        RETCODE=1
   fi

   {
        print " "
        print $ERROR
        print " "
        print " !!! Aborting !!!"
        print " "
        print "return_code = " $RETCODE
        print " "
        print " ------ Ending script " $SCRIPT `date`
   }    >> $LOG_FILE

   mailx -s "$EMAIL_SUBJECT" $TO_MAIL                        < $LOG_FILE
   cp -f $LOG_FILE $LOG_FILE_ARCH
   exit $RETCODE

}

# Region specific variables
if [[ $REGION = "PROD" ]];   then
    export ALTER_EMAIL_TO_ADD=""
    EMAIL_TO_ADD="gdxitd@caremark.com"
fi
if [ $REGION = "SIT1" -o $REGION = "SIT2" ];   then
    export ALTER_EMAIL_TO_ADD="gdxsittest@caremark.com"
    EMAIL_TO_ADD="gdxsittest@caremark.com"
fi
if [ $REGION = "DEV1" -o $REGION = "DEV2" ];   then
    export ALTER_EMAIL_TO_ADD="randy.redus@caremark.com"
    EMAIL_TO_ADD="randy.redus@caremark.com"
fi

# Variables and temp files
RETCODE=0
FILE_BASE=$(basename $0 | sed -e 's/.ksh$//')
SCRIPTNAME=$FILE_BASE".ksh"

SQL_FILE=$OUTPUT_DIR/$FILE_BASE"_TSNAP.sql"
DATA_FILE=$OUTPUT_DIR/$FILE_BASE"_TSNAP_out.dat"
TODAYS_DATE_FILE=$OUTPUT_DIR/$FILE_BASE"_TSNAP_date.dat"
TRIGGER_FILE=$INPUT_DIR/"Trigger_Snapshots.trg"

# LOG FILES
LOG_FILE_ARCH="${ARCH_LOG_DIR}/${FILE_BASE}.log"`date +"%Y%m%d_%H%M%S"`
LOG_FILE="${LOG_DIR}/${FILE_BASE}.log"

rm -f $SQL_FILE
rm -f $DATA_FILE
rm -f $TODAYS_DATE_FILE
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Starting the script and log the starting time.
#-------------------------------------------------------------------------#
   {
      print " "
      print "Starting the script $SCRIPTNAME ......"
      print `date +"%D %r %Z"`
      print "********************************************"
   }                                                                           > $LOG_FILE

#-------------------------------------------------------------------------#
# Connect to UDB.
#-------------------------------------------------------------------------#

print " "                                                                      >> $LOG_FILE
sql="db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD"
db2 -p connect to $DATABASE user $CONNECT_ID using $CONNECT_PWD                >> $LOG_FILE

RETCODE=$?

if [[ $RETCODE != 0 ]]; then
   print "Error: couldn't connect to database " $SCRIPTNAME " ...          "   >> $LOG_FILE
   print "Return code is : <" $RETCODE ">"                                     >> $LOG_FILE
   exit_error $RETCODE
fi

#-------------------------------------------------------------------------#
# Build the UDB timestamp field with the current date
#-------------------------------------------------------------------------#

date "+%Y %m %d %H %M %S" > $TODAYS_DATE_FILE

read year month day hr min sec < $TODAYS_DATE_FILE

UDB_TS="TIMESTAMP('$year-$month-$day-$hr.$min.$sec.000000')"

print "UDB timstamp value built - >$UDB_TS<"                                   >> $LOG_FILE

#-------------------------------------------------------------------------#
# Build the SQL to do the count
# If a count > 0 then create the trigger
#-------------------------------------------------------------------------#

SQL_FILE="SELECT COUNT(*) FROM VRAP.TSNAP WHERE SNAP_RUN_STAT_CD = 1 AND REQ_RUN_TS <= $UDB_TS"

print " "                                                                      >> $LOG_FILE
print "SQL to run: $SQL_FILE"                                                  >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

db2 -x $SQL_FILE > $DATA_FILE
RETCODE=$?

if [[ $RETCODE != 0 ]]; then
    print " "                                                                  >> $LOG_FILE
    print "ERROR: Select of row count from TSNAP"                              >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print $SQL_FILE                                                            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Return code is : <" $RETCODE ">"                                    >> $LOG_FILE
    exit_error $RETCODE
fi

read pending_cnt < $DATA_FILE

print " "                                                                      >> $LOG_FILE
print "Count returned: $pending_cnt"                                           >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

# build the trigger file that will let the Maestro job for the GDX Snapshot process run
#  If the SELECT COUNT was zero, then do not build the trigger file, just complete
if [[ $pending_cnt -gt 0 ]]; then
    print "This file is being built to trigger the GDX Snapshot batch process" >> $TRIGGER_FILE
    print " "                                                                  >> $TRIGGER_FILE
    print "This file was built in $SCRIPTNAME and will be removed by the "     >> $TRIGGER_FILE
    print "first job in the GDX Snapshot batch process"                        >> $TRIGGER_FILE
    print " "                                                                  >> $LOG_FILE
    print "Trigger file built "                                                >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
else
    print " "                                                                  >> $LOG_FILE
    print "Trigger file NOT built "                                            >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
fi

#-------------------------------------------------------------------------#
# Finish the script and log the time.
#-------------------------------------------------------------------------#
{
    print "********************************************"
    print "Finishing the script $SCRIPTNAME ......"
    print `date +"%D %r %Z"`
    print "Final return code is : <" $RETCODE ">"
    print " "
}                                                                              >> $LOG_FILE

#-------------------------------------------------------------------------#
# move log file to archive with timestamp
#-------------------------------------------------------------------------#

rm -f $SQL_FILE
rm -f $DATA_FILE
rm -f $TODAYS_DATE_FILE

mv -f $LOG_FILE $LOG_FILE_ARCH

exit $RETCODE

