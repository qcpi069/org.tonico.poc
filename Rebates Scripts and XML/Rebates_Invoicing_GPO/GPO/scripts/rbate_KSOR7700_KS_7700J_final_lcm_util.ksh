#!/bin/ksh
#-------------------------------------------------------------------------#
# Script        : rbate_KSOR7700_KS_7700J_final_lcm_util.ksh  
# Title         : .
#
# Description   : Insert to final_lcm_util table in rbate_reg.
#                 
#                 
#                 
# Maestro Job   : KSOR7700  KS_7700J
#
# Parameters    : N/A 
#
# Output        : Log file as $OUTPUT_PATH/$LOG_FILE
#
# Exit Codes    : 0 = OK; 1 = fatal error
#
#   Date                 Description
# ---------  ----------  -------------------------------------------------#
# 01-21-2005  IS51701    Initial Creation.
#
#-------------------------------------------------------------------------#
#-------------------------------------------------------------------------#
# Caremark Rebates Environment variables
#-------------------------------------------------------------------------#
. `dirname $0`/rebates_env.ksh

if [[ $REGION = "prod" ]];   then
    if [[ $QA_REGION = "true" ]];   then
        # Running in the QA region
        export ALTER_EMAIL_ADDRESS='sheree.swanson@caremark.com'
    else
        # Running in Prod region
        export ALTER_EMAIL_ADDRESS=''
    fi
else
    # Running in Development region
    export ALTER_EMAIL_ADDRESS='sheree.swanson@caremark.com'
fi

RETCODE=0
SCHEDULE="KSOR7700"
JOB="KS_7700J"
FILE_BASE="rbate_"$SCHEDULE"_"$JOB"_final_lcm_util"
SCRIPTNAME=$FILE_BASE".ksh"
LOG_FILE=$FILE_BASE".log"
PKG_LOG=$FILE_BASE"_PKG_LOG.log"
SQL_FILE=$FILE_BASE".sql"

rm -f $OUTPUT_PATH/$LOG_FILE
rm -f $INPUT_PATH/$SQL_FILE
rm -f $OUTPUT_PATH/$PKG_LOG

#----------------------------------
# Create the Package to be executed
#----------------------------------

#PARM=''

Package_Name="rbate_reg.pk_final_lcm_util.prc_final_lcm_util_insert"
PKGEXEC=$Package_Name;

#-------------------------------------------------------------------------#
# Set up the Pipe file, then build and EXEC the new SQL.               
#-------------------------------------------------------------------------#
print `date` 'Beginning Package call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE

#----------------------------------
# Oracle userid/password
#----------------------------------

##db_user_password=`cat $SCRIPT_PATH/rbate_reg_ora_user.fil`
db_user_password=`cat $SCRIPT_PATH/ora_user.fil`

#-------------------------------------------------------------------------#
# Execute the SQL run the Package to insert records
#-------------------------------------------------------------------------#

print ' ' >> $OUTPUT_PATH/$LOG_FILE

cat > $INPUT_PATH/$SQL_FILE << EOF
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

$ORACLE_HOME/bin/sqlplus -s $db_user_password @$INPUT_PATH/$SQL_FILE

RETCODE=$?

cat $OUTPUT_PATH/$PKG_LOG >> $OUTPUT_PATH/$LOG_FILE


if [[ $RETCODE = 0 ]]; then
   print `date` 'Completed Package call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
fi

if [[ $RETCODE != 0 ]]; then
   print ' ' >> $OUTPUT_PATH/$LOG_FILE
   print 'Failure in Package call of ' $PKGEXEC >> $OUTPUT_PATH/$LOG_FILE
   print 'Package call RETURN CODE is : ' $RETCODE >> $OUTPUT_PATH/$LOG_FILE
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

rm -f $OUTPUT_PATH/$PKG_LOG

print "....Completed executing " $SCRIPTNAME " ...."   >> $OUTPUT_PATH/$LOG_FILE
mv -f $OUTPUT_PATH/$LOG_FILE $LOG_ARCH_PATH/$LOG_FILE.`date +"%Y%j%H%M"`


exit $RETCODE

