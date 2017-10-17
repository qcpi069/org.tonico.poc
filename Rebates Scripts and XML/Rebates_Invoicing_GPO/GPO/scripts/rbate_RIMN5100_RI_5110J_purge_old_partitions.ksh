#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_RIMN5100_RI_5110J_purge_old_partitions.ksh   
#
# Description   : Drop all old DMA_RBATE2 partitions, per T_TBL_MGMT table. 
#
# Maestro Job   : RIMN5100 RI_5110J
#
# Parameters    : None
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 12/01/04   is45401     Change the Schedule and Job name from RIOR5000
#                        and job RI_5010J.  Changed IF REGION to current
#                        version, and added cat of PKG_LOG when error
#                        occurs to see the ORA error code.
#                        Removed following unused variables:  DAT_FILE, 
#                        DATE_CNTRL_FILE, FTP_CMDS, SQL_FILE_DATE_CNTRL,
#                        SQL_PIPE_FILE
# 01-08-2004  IS52701    Initial Creation.
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
    SCHEMA_OWNER="dma_rbate2"
  else
    # Running in Prod region
    ALTER_EMAIL_ADDRESS=''
    SCHEMA_OWNER="dma_rbate2"
  fi
else
  # Running in Development region
  ALTER_EMAIL_ADDRESS='randy.redus@caremark.com'
  SCHEMA_OWNER="dma_rbate2_work"
fi

export SCHEDULE="RIMN5100"
export JOB="RI_5110J"
export FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_purge_old_partitions"
export SCRIPTNAME=$FILE_BASE".ksh"
export LOG_FILE=$FILE_BASE".log"
export SQL_FILE=$FILE_BASE".sql"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE


#-------------------------------------------------------------------------#
# No paramete checking needed
#-------------------------------------------------------------------------#

#-------------------------------------------------------------------------#
# Create the Package to be executed
#-------------------------------------------------------------------------#

export Package_Name=$SCHEMA_OWNER".pk_cycle_util.prc_purge_old_partitions"
PKGEXEC=$Package_Name;

print `date` 'Beginning Package call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
print " " >> $OUTPUT_PATH/$LOG_FILE

#-------------------------------------------------------------------------#
# Oracle userid/password
#-------------------------------------------------------------------------#

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Execute the Package
#-------------------------------------------------------------------------#

print ' ' >> $OUTPUT_PATH/$LOG_FILE

cat > $SCRIPT_PATH/$SQL_FILE << EOF
set linesize 5000
set flush off
set TERMOUT OFF
set PAGESIZE 0
set NEWPAGE 0
set SPACE 0
set ECHO OFF
set FEEDBACK OFF
set HEADING OFF
set WRAP on
set verify off
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/$PKG_LOG

EXEC $PKGEXEC; 

quit;
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SCRIPT_PATH/$SQL_FILE

export RETCODE=$?

if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed Package call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
fi

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Package call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
   export RETCODE=$RETCODE
   print 'Package call RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Oracle ORA error is : '  >> $OUTPUT_PATH/$LOG_FILE
   cat $PKG_LOG >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   cat $SQL_FILE >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
fi

#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $RETCODE != 0 ]]; then
   print " " >> $OUTPUT_PATH/$LOG_FILE
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/$LOG_FILE
   print "  Error Executing " $SCRIPTNAME                                    >> $OUTPUT_PATH/$LOG_FILE
   print "  Look in "$OUTPUT_PATH/$LOG_FILE       >> $OUTPUT_PATH/$LOG_FILE
   print "=================================================================" >> $OUTPUT_PATH/$LOG_FILE
   
# Send the Email notification 
   export JOBNAME=$SCHEDULE/$JOB
   export SCRIPTNAME=$SCRIPT_PATH/$SCRIPTNAME
   export LOGFILE=$OUTPUT_PATH/$LOG_FILE
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/$LOG_FILE
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/$LOG_FILE 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/$LOG_FILE
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/$LOG_FILE
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/$LOG_FILE
   print "****** end of email parameters ******" >> $OUTPUT_PATH/$LOG_FILE
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`
   exit $RETCODE
fi

#rm -f $INPUT_PATH/$SQL_FILE

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

