#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KCDY4200_KC_4200J_T_EXTNL_SRC_CODE_snapshot.ksh   
# Title         : Snapshot refresh.
#
# Description   : Refreshes a single snapshot T_EXTNL_SRC_CODE in 
#                 the gold instance on EDW.
# Maestro Job   : KC_4200J
#
# Parameters    : None all hard coded
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 07-06-04    is45401     Pointed to changed PK_SNAPSHOT_REFRESH package.
#                         Removed script from EDWDOM0 box, since it runs
#                         ONLY on REBDOM1 box.
# 03-23-04    is45401     Renamed Oracle package being called, from 
#                         refresh_snapshots_from_dma.  Renamed script
#                         from rbate_T_BATCH_LCL_snapshot.ksh.  Added new
#                         REGION check and standard variables.
#
# 10-01-02    K. Gries    added rbate_email_base.ksh call.
#
# 09-26-2002  K. Gries    Modify to call PL/SQL that will execute the refresh
#                         because of permission issues with ownership.
# 
# 08-08-2002  K. Gries    Initial Creation.
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

RETCODE=0
SCHEDULE="KCDY4200"
JOB="KC_4200J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_T_EXTNL_SRC_CODE_snapshot"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
SQL_FILE=$INPUT_PATH/$FILE_BASE".sql"
PKG_CALL=$OUTPUT_PATH/$FILE_BASE"_pkg_call.txt"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $SQL_FILE
rm -f $PKG_CALL

print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " Now starting script " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Snapshot_Name ir the table to be refreshed
# Refresh_Type is the type of refresh where C=Complete
# Package_Name is the PL/SQL procedure to call the snapshot
# Tracking is the value that will be put in the PRCS_LOG.TRACKING column
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

Snapshot_Name="T_EXTNL_SRC_CODE"
Tracking=$Snapshot_Name
Refresh_Type="C"
Package_Name="dma_rbate2.pk_snapshot_refresh.refresh_dma_rbate2_snapshots"
PKGEXEC=$Package_Name\(\'$Snapshot_Name\'\,\'$Refresh_Type\'\,\'$Tracking\'\);

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $SQL_FILE

cat > $SQL_FILE << EOF
set serveroutput on size 1000000
whenever sqlerror exit 1
SPOOL $PKG_CALL
SET TIMING ON
exec $PKGEXEC;
EXIT
EOF

print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
print " Now calling the Oracle package " $PKGEXEC                            >> $OUTPUT_PATH/$LOG_FILE
print " Exec stmt is " $PKGEXEC                                              >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SQL_FILE

RETCODE=$?

cat $PKG_CALL                                                                >> $OUTPUT_PATH/$LOG_FILE

print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE

if [[ $RETCODE = 0 ]]; then
    print " Successfully completed package call. "                           >> $OUTPUT_PATH/$LOG_FILE
else
    print " Package call abended. "                                          >> $OUTPUT_PATH/$LOG_FILE     
fi

print `date`                                                                 >> $OUTPUT_PATH/$LOG_FILE
print "================================================================="    >> $OUTPUT_PATH/$LOG_FILE
print " "                                                                    >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " "                                                                 >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing "$SCRIPTNAME                                     >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE                                  >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   JOBNAME=$SCHEDULE/$JOB
   SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   LOGFILE=$OUTPUT_PATH/$LOG_FILE
   EMAILPARM4="  "
   EMAILPARM5="  "
   
   print "Sending email notification with the following parameters"         >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME                                             >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME                                       >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE                                             >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4                                       >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5                                       >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******"                            >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

rm -f $SQL_FILE
rm -f $PKG_CALL

print "....Completed executing " $SCRIPTNAME "...."                         >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`

exit $RETCODE

