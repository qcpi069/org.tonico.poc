#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_create_LCM_report.ksh   
# Title         : Snapshot refresh.
#
# Description   : Extracts APC records into the 323 byte format 
#                 for future split into 10,000,000 record files,
#                 zip and transmit to MVS
# Maestro Job   : Called from rbate_APC_file_extract.ksh in 
#                 RIOR4500 / RI_4500J
#
# Parameters    : CYCLE_GID
#
# Output        : Log file as $OUTPUT_PATH/rbate_create_LCM_report.log
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 10-16-2002  K. Gries    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# AdvancePCS Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

rm -f $OUTPUT_PATH/rbate_create_LCM_report.log

export EDW_USER="/"

#-------------------------------------------------------------------------#
# Set parameters to use in PL/SQL call.
#
# Table_Name ir the table to be refreshed
# Refresh_Type is the type of refresh where C=Complete
# Package_Name is the PL/SQL procedure to call the snapshot
# PKGEXEC is the full SQL command to be executed
#-------------------------------------------------------------------------#

if [ $# -lt 1 ] 
then
    print " " >> $OUTPUT_PATH/rbate_create_LCM_report.log
    print "Insufficient arguments passed to script." >> $OUTPUT_PATH/rbate_create_LCM_report.log
    print " " >> $OUTPUT_PATH/rbate_create_LCM_report.log
    exit 1
fi

#-------------------------------------------------------------------------#
# Redirect all output to log file and Log start message to 
# application log
#-------------------------------------------------------------------------#
## Display special env vars used for this script
#-------------------------------------------------------------------------#
CYCLE_GID=$1
print " " >> $OUTPUT_PATH/rbate_create_LCM_report.log
print "CYCLE_GID is " $1 >> $OUTPUT_PATH/rbate_create_LCM_report.log
print ' ' >> $OUTPUT_PATH/rbate_create_LCM_report.log

Package_Name=PK_LCM_AMT_RBATED_PRCSSD_CLMS.prc_LCM_Amt_Rbated_Prcssd_Clms
PKGEXEC=$Package_Name\(\'$CYCLE_GID\'\);

print ' ' >> $OUTPUT_PATH/rbate_create_LCM_report.log
print "package to be executed is: " $PKGEXEC >> $OUTPUT_PATH/rbate_create_LCM_report.log
print ' ' >> $OUTPUT_PATH/rbate_create_LCM_report.log
print "executing processed_claim_status_driver SQL" >> $OUTPUT_PATH/rbate_create_LCM_report.log
print `date` >> $OUTPUT_PATH/rbate_create_LCM_report.log

#----------------------------------
# Oracle userid/password
#----------------------------------

db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Remove the previous SQL, then build and EXEC the new SQL.               
#                                                                         
#-------------------------------------------------------------------------#

rm -f $SCRIPT_PATH/rbate_create_LCM_report.sql

cat > $SCRIPT_PATH/rbate_create_LCM_report.sql << EOF
set timing on
whenever sqlerror exit 1
SPOOL $OUTPUT_PATH/rbate_create_LCM_report.log
alter session enable parallel dml; 
exec $PKGEXEC;
EXIT
EOF

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$SCRIPT_PATH/rbate_create_LCM_report.sql

export CALLRTN=$?


#-------------------------------------------------------------------------#
# Check for good return and Log.                  
#-------------------------------------------------------------------------#

if [[ $CALLRTN != 0 ]]; then
   print " " >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "===================== J O B  A B E N D E D ======================" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "  Error Executing rbate_create_LCM_report.ksh          " >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "  Look in "$OUTPUT_PATH/rbate_create_LCM_report.log       >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "=================================================================" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   
# Send the Email notification 
   export JOBNAME="Called from rbate_APC_file_extract.ksh in RIOR4500 / RI_4500J"
   export SCRIPTNAME=$OUTPUT_PATH"/rbate_create_LCM_report.ksh"
   export LOGFILE=$OUTPUT_PATH"/rbate_create_LCM_report.log"
   export EMAILPARM4="  "
   export EMAILPARM5="  "
   
   print "Sending email notification with the following parameters" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "JOBNAME is " $JOBNAME >> $OUTPUT_PATH/rbate_create_LCM_report.log 
   print "SCRIPTNAME is " $SCRIPTNAME >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "LOGFILE is " $LOGFILE >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "EMAILPARM4 is " $EMAILPARM4 >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "EMAILPARM5 is " $EMAILPARM5 >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "****** end of email parameters ******" >> $OUTPUT_PATH/rbate_create_LCM_report.log

   print "This script was called from rbate_APC_file_extract.ksh" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "The return code from this job will be returned back to rbate_APC_file_extract.ksh" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "It will NOT be terminated." >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "The log for rbate_APC_file_extract.ksh will state that the abend occurred herin" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "and that the LCM Report process must be rerun. The rbate_APC_file_extract.ksh will" >> $OUTPUT_PATH/rbate_create_LCM_report.log
   print "continue and extract the APC file." >> $OUTPUT_PATH/rbate_create_LCM_report.log
   
   . $SCRIPT_PATH/rbate_email_base.ksh
   cp -f $OUTPUT_PATH/rbate_create_LCM_report.log $LOG_ARCH_PATH/rbate_create_LCM_report.log.`date +"%Y%j%H%M"`
   return $CALLRTN
fi

print "....Completed executing rbate_create_LCM_report.ksh ...."   >> $OUTPUT_PATH/rbate_create_LCM_report.log
mv -f $OUTPUT_PATH/rbate_create_LCM_report.log $LOG_ARCH_PATH/rbate_create_LCM_report.log.`date +"%Y%j%H%M"`


return $CALLRTN

