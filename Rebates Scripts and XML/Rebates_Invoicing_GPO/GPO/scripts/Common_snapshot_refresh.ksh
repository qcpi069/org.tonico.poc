#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : Common_snapshot_refresh.ksh   
# Title         : Snapshot refresh.
#
# Description   : Refreshes a single snapshot that is passed into the script. 
#
# Maestro Job   : varies
#
# Parameters    : Pass in the snapshot name
#
# Output        : Log file as $LOG_FILE
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 06-14-07    is45401    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#

. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        ALTER_EMAIL_ADDRESS='randy.redus@caremark.com'
    else
        # Running in Prod region
        ALTER_EMAIL_ADDRESS=''
    fi
else
    # Running in Development region
    ALTER_EMAIL_ADDRESS='randy.redus@caremark.com'
fi

FILE_BASE="Common_snapshot_refresh"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE".log."$(date +'%Y%j%H%M')
rm -f $LOG_FILE

#-------------------------------------------------------------------------#
# Function to exit the script on error
#-------------------------------------------------------------------------#
function exit_error {
    RETCODE=$1
    export JOBNAME
    export SCRIPTNAME
    export LOG_FILE
    export LOGFILE=$LOG_FILE
    export EMAILPARM4='  '
    export EMAILPARM5='  '

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

   . $SCRIPT_PATH/rbate_email_base.ksh
   
    print ".... $SCRIPTNAME  abended ...." >> $LOG_FILE

    cp -f $LOG_FILE $ARCH_LOG_FILE
    exit $RETCODE
}
#-------------------------------------------------------------------------#

if [[ $# -lt 1 ]]; then
    FILE_BASE="Common_snapshot_refresh"
    SCRIPTNAME=$FILE_BASE".ksh"
    LOG_FILE=$OUTPUT_PATH/$FILE_BASE".log"
    ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE".log."$(date +'%Y%j%H%M')
    rm -f $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    print "Insufficient arguments passed to script."                           >> $LOG_FILE
    print " "                                                                  >> $LOG_FILE
    exit_error 1
else
    SNAPSHOT=$1
fi

RETCODE=0
SCHEDULE=""
JOB=""
FILE_BASE="Common_snapshot_refresh"
SCRIPTNAME=$(basename $0)
LOG_FILE=$OUTPUT_PATH/$FILE_BASE"_$SNAPSHOT.log"
SQL_FILE=$INPUT_PATH/$FILE_BASE"_$SNAPSHOT.sql"
PKG_CALL=$OUTPUT_PATH/$FILE_BASE"_$SNAPSHOT_pkg_call.txt"
ARCH_LOG_FILE=$OUTPUT_PATH/archive/$FILE_BASE"_$SNAPSHOT.log."$(date +'%Y%j%H%M')

rm -f $LOG_FILE
rm -f $SQL_FILE
rm -f $PKG_CALL

print " "                                                                      >> $LOG_FILE
print "================================================================="      >> $LOG_FILE
print " Now starting script " $SCRIPTNAME to refresh snapshot $SNAPSHOT        >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print "================================================================="      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# SNAPSHOT is the materialized view to be refreshed
# Refresh_Type is the type of refresh where C=Complete
# Package_Name is the PL/SQL procedure to call the snapshot refresh from
# Tracking is the value that will be put in the PRCS_LOG.TRACKING column
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

Tracking=$SNAPSHOT
Refresh_Type="C"
Package_Name="dma_rbate2.pk_snapshot_refresh.refresh_dma_rbate2_snapshots"
PKGEXEC=$Package_Name\(UPPER\(\'$SNAPSHOT\'\)\,\'$Refresh_Type\'\,UPPER\(\'$Tracking\'\)\);

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

cat > $SQL_FILE << EOF
set serveroutput on size 1000000
whenever sqlerror exit 1
SPOOL $PKG_CALL
SET TIMING ON
exec $PKGEXEC;
EXIT
EOF

print " "                                                                      >> $LOG_FILE
print "================================================================="      >> $LOG_FILE
print " Now calling the Oracle package " $PKGEXEC                              >> $LOG_FILE
print `date`                                                                   >> $LOG_FILE
print " Exec stmt is " $PKGEXEC                                                >> $LOG_FILE
print "================================================================="      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

print " "                                                                      >> $LOG_FILE
cat $PKG_CALL                                                                  >> $LOG_FILE

print " "                                                                      >> $LOG_FILE
print "================================================================="      >> $LOG_FILE

if [[ $RETCODE = 0 ]]; then
    print " Successfully completed package call. "                             >> $LOG_FILE
else
    print " Package call abended. "                                            >> $LOG_FILE     
    exit_error $RETCODE
fi

print `date`                                                                   >> $LOG_FILE
print "================================================================="      >> $LOG_FILE
print " "                                                                      >> $LOG_FILE

rm -f $SQL_FILE
rm -f $PKG_CALL

print "....Completed executing $SCRIPTNAME for $SNAPSHOT"                      >> $LOG_FILE
mv -f $LOG_FILE $ARCH_LOG_FILE

exit $RETCODE

